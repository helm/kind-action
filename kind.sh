#!/usr/bin/env bash

# Copyright The Helm Authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o errexit
set -o nounset
set -o pipefail

DEFAULT_KIND_VERSION=v0.29.0
DEFAULT_CLUSTER_NAME=chart-testing
DEFAULT_KUBECTL_VERSION=v1.31.11
DEFAULT_CLOUD_PROVIDER_KIND_VERSION=0.6.0

show_help() {
cat << EOF
Usage: $(basename "$0") <options>

        --help                              Display help
    -v, --version                           The kind version to use (default: $DEFAULT_KIND_VERSION)
    -c, --config                            The path to the kind config file
    -K, --kubeconfig                        The path to the kubeconfig config file
    -i, --node-image                        The Docker image for the cluster nodes
    -n, --cluster-name                      The name of the cluster to create (default: chart-testing)
    -w, --wait                              The duration to wait for the control plane to become ready (default: 60s)
    -l, --verbosity                         info log verbosity, higher value produces more output
    -k, --kubectl-version                   The kubectl version to use (default: $DEFAULT_KUBECTL_VERSION)
    -o, --install-only                      Skips cluster creation, only install kind (default: false)
        --with-registry                     Enables registry config dir for the cluster (default: false)
        --cloud-provider                    Enables cloud provider for the cluster (default: false)
        --app-namespace                     Namespace for bl-k8s-app (default: bl-k8s)
        --kyverno-namespace                 Kyverno namespace (default: kyverno)
        --kyverno-policy-path               Path to Kyverno policies (default: k8s-clusters/services/common/module/policies)
        --secret-name                       Name for bl-k8s-secrets (default: bl-k8s-secrets)
        --oidc-user                         OIDC user for pulling images from Artifactory
        --oidc-token                        OIDC token for pulling images from Artifactory
        --config-descriptor-key             Config descriptor key for bl-k8s-secrets
EOF
}

main() {
    local version="${DEFAULT_KIND_VERSION}"
    local config=
    local kubeconfig=
    local node_image=
    local cluster_name="${DEFAULT_CLUSTER_NAME}"
    local wait=60s
    local verbosity=
    local kubectl_version="${DEFAULT_KUBECTL_VERSION}"
    local install_only=false
    local with_registry=false
    local config_with_registry_path="/etc/kind-registry/config.yaml"
    local cloud_provider=
    local CLUSTER_NAME="chart-testing"
    local KYVERNO_NAMESPACE="kyverno"
    local KYVERNO_POLICY_PATH="k8s-clusters/services/common/module/policies"
    local APP_NAMESPACE="bl-k8s"
    local SECRET_NAME="bl-k8s-secrets"

    parse_command_line "$@"

    if [[ ! -d "${RUNNER_TOOL_CACHE}" ]]; then
        echo "Cache directory '${RUNNER_TOOL_CACHE}' does not exist" >&2
        exit 1
    fi

    local arch
    case $(uname -m) in
        i386)               arch="386" ;;
        i686)               arch="386" ;;
        x86_64)             arch="amd64" ;;
        arm|aarch64|arm64)  arch="arm64" ;;
        *) exit 1 ;;
    esac
    local cache_dir="${RUNNER_TOOL_CACHE}/kind/${version}/${arch}"

    local kind_dir="${cache_dir}/kind/bin/"
    if [[ ! -x "${kind_dir}/kind" ]]; then
        install_kind
    fi

    echo 'Adding kind directory to PATH...'
    echo "${kind_dir}" >> "${GITHUB_PATH}"

    local kubectl_dir="${cache_dir}/kubectl/bin/"
    if [[ ! -x "${kubectl_dir}/kubectl" ]]; then
        install_kubectl
    fi

    echo 'Adding kubectl directory to PATH...'
    echo "${kubectl_dir}" >> "${GITHUB_PATH}"
     
    "${kind_dir}/kind" version
    "${kubectl_dir}/kubectl" version --client=true

    if [[ "${install_only}" == true ]]; then
      create_kind_cluster
    else
        create_kind_cluster
        copy_docker_creds
        setup_kyverno
        apply_kyverno_policies
        create_bl_k8s_secret
    fi
}

parse_command_line() {
    while :; do
        case "${1:-}" in
            -h|--help)
                show_help
                exit
                ;;
            -v|--version)
                if [[ -n "${2:-}" ]]; then
                    version="$2"
                    shift
                else
                    echo "ERROR: '-v|--version' cannot be empty." >&2
                    show_help
                    exit 1
                fi
                ;;
            -c|--config)
                if [[ -n "${2:-}" ]]; then
                    config="$2"
                    shift
                else
                    echo "ERROR: '--config' cannot be empty." >&2
                    show_help
                    exit 1
                fi
                ;;
            -K|--kubeconfig)
                if [[ -n "${2:-}" ]]; then
                    kubeconfig="$2"
                    shift
                else
                    echo "ERROR: '--kubeconfig' cannot be empty." >&2
                    show_help
                    exit 1
                fi
                ;;
            -i|--node-image)
                if [[ -n "${2:-}" ]]; then
                    node_image="$2"
                    shift
                else
                    echo "ERROR: '-i|--node-image' cannot be empty." >&2
                    show_help
                    exit 1
                fi
                ;;
            -n|--cluster-name)
                if [[ -n "${2:-}" ]]; then
                    cluster_name="$2"
                    shift
                else
                    echo "ERROR: '-n|--cluster-name' cannot be empty." >&2
                    show_help
                    exit 1
                fi
                ;;
            -w|--wait)
                if [[ -n "${2:-}" ]]; then
                    wait="$2"
                    shift
                else
                    echo "ERROR: '--wait' cannot be empty." >&2
                    show_help
                    exit 1
                fi
                ;;
            -l|--verbosity)
                if [[ -n "${2:-}" ]]; then
                    verbosity="$2"
                    shift
                else
                    echo "ERROR: '-l|--verbosity' cannot be empty." >&2
                    show_help
                    exit 1
                fi
                ;;
            -k|--kubectl-version)
                if [[ -n "${2:-}" ]]; then
                    kubectl_version="$2"
                    shift
                else
                    echo "ERROR: '-k|--kubectl-version' cannot be empty." >&2
                    show_help
                    exit 1
                fi
                ;;
            -o|--install-only)
                if [[ -n "${2:-}" ]]; then
                    install_only="$2"
                    shift
                else
                    install_only=false
                fi
                ;;
            --with-registry)
                if [[ -n "${2:-}" ]]; then
                    with_registry="$2"
                    shift
                else
                    with_registry=true
                fi
                ;;
            --cloud-provider)
                if [[ -n "${2:-}" ]]; then
                    cloud_provider="$2"
                    shift
                else
                    cloud_provider=true
                fi
                ;;
            --app-namespace)
                if [[ -n "${2:-}" ]]; then
                    APP_NAMESPACE="$2"
                    shift
                else
                    echo "ERROR: '--app-namespace' cannot be empty." >&2
                    show_help
                    exit 1
                fi
                ;;
            --kyverno-namespace|-N)
                if [[ -n "${2:-}" ]]; then
                    KYVERNO_NAMESPACE="$2"
                    shift
                else
                    echo "ERROR: '--kyverno-namespace' cannot be empty." >&2
                    show_help
                    exit 1
                fi
                ;;
            --kyverno-policy-path|-p)
                if [[ -n "${2:-}" ]]; then
                    KYVERNO_POLICY_PATH="$2"
                    shift
                else
                    echo "ERROR: '--kyverno-policy-path' cannot be empty." >&2
                    show_help
                    exit 1
                fi
                ;;
            --secret-name|-s)
                if [[ -n "${2:-}" ]]; then
                    SECRET_NAME="$2"
                    shift
                else
                    echo "ERROR: '--secret-name' cannot be empty." >&2
                    show_help
                    exit 1
                fi
                ;;
            --oidc-user|-u)
                if [[ -n "${2:-}" ]]; then
                    OIDC_USER="$2"
                    shift
                else
                    echo "ERROR: '--oidc-user' cannot be empty." >&2
                    show_help
                    exit 1
                fi
                ;;
            --oidc-token|-t)
                if [[ -n "${2:-}" ]]; then
                    OIDC_TOKEN="$2"
                    shift
                else
                    echo "ERROR: '--oidc-token' cannot be empty." >&2
                    show_help
                    exit 1
                fi
                ;;
            --config-descriptor-key|-d)
                if [[ -n "${2:-}" ]]; then
                    CONFIG_DESCRIPTOR_KEY="$2"
                    shift
                else
                    echo "ERROR: '--config-descriptor-key' cannot be empty." >&2
                    show_help
                    exit 1
                fi
                ;;
            *)
                break
                ;;
        esac
        shift
    done
}

install_kind() {
    echo 'Installing kind...'

    mkdir -p "${kind_dir}"

    pushd "${kind_dir}"
    curl -sSLo "kind-linux-${arch}" "https://github.com/kubernetes-sigs/kind/releases/download/${version}/kind-linux-${arch}"
    curl -sSLo "kind-linux-${arch}.sha256sum" "https://github.com/kubernetes-sigs/kind/releases/download/${version}/kind-linux-${arch}.sha256sum"
    grep "kind-linux-${arch}" < "kind-linux-${arch}.sha256sum" | sha256sum -c
    mv "kind-linux-${arch}" kind
    rm -f "kind-linux-${arch}.sha256sum"
    chmod +x kind
    popd
}

install_kubectl() {
    echo 'Installing kubectl...'

    mkdir -p "${kubectl_dir}"

    pushd "${kubectl_dir}"
    curl -sSLo kubectl "https://dl.k8s.io/release/${kubectl_version}/bin/linux/${arch}/kubectl"
    curl -sSLo kubectl.sha256 "https://dl.k8s.io/release/${kubectl_version}/bin/linux/${arch}/kubectl.sha256"
    echo "$(cat kubectl.sha256) kubectl" | sha256sum -c
    chmod +x kubectl
    popd
}

create_config_with_registry() {
    sudo mkdir -p $(dirname "$config_with_registry_path")
    cat <<EOF | sudo tee  "$config_with_registry_path"
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry]
    config_path = "/etc/containerd/certs.d"

EOF
    sudo chmod a+r "$config_with_registry_path"
}

install_cloud_provider(){
    echo "Setting up cloud-provider-kind..."
    curl -sSLo cloud-provider-kind_${DEFAULT_CLOUD_PROVIDER_KIND_VERSION}_linux_amd64.tar.gz https://github.com/kubernetes-sigs/cloud-provider-kind/releases/download/v${DEFAULT_CLOUD_PROVIDER_KIND_VERSION}/cloud-provider-kind_${DEFAULT_CLOUD_PROVIDER_KIND_VERSION}_linux_amd64.tar.gz > /dev/null 2>&1
    curl -sSLo cloud-provider-kind_${DEFAULT_CLOUD_PROVIDER_KIND_VERSION}_checksums.txt https://github.com/kubernetes-sigs/cloud-provider-kind/releases/download/v${DEFAULT_CLOUD_PROVIDER_KIND_VERSION}/cloud-provider-kind_${DEFAULT_CLOUD_PROVIDER_KIND_VERSION}_checksums.txt

    grep "cloud-provider-kind_${DEFAULT_CLOUD_PROVIDER_KIND_VERSION}_linux_amd64.tar.gz" < "cloud-provider-kind_${DEFAULT_CLOUD_PROVIDER_KIND_VERSION}_checksums.txt" | sha256sum -c

    mkdir -p cloud-provider-kind-tmp
    tar -xzf cloud-provider-kind_${DEFAULT_CLOUD_PROVIDER_KIND_VERSION}_linux_amd64.tar.gz -C cloud-provider-kind-tmp
    chmod +x cloud-provider-kind-tmp/cloud-provider-kind
    sudo mv cloud-provider-kind-tmp/cloud-provider-kind /usr/local/bin/
    rm -rf cloud-provider-kind-tmp cloud-provider-kind_${DEFAULT_CLOUD_PROVIDER_KIND_VERSION}_linux_amd64.tar.gz

    echo "cloud-provider-kind set up successfully ✅"

    cloud-provider-kind > /tmp/cloud-provider.log 2>&1 &
    echo "cloud-provider-kind started ✅"
}

create_kind_cluster() {
    echo 'Creating kind cluster...'
    local args=(create cluster "--name=${cluster_name}" "--wait=${wait}")

    if [[ -n "${node_image}" ]]; then
        args+=("--image=${node_image}")
    fi

    if [[ -n "${config}" ]]; then
        args+=("--config=${config}")
    fi

    if [[ -n "${kubeconfig}" ]]; then
        args+=("--kubeconfig=${kubeconfig}")
    fi

    if [[ -n "${verbosity}" ]]; then
        args+=("--verbosity=${verbosity}")
    fi

    if [[ "${with_registry}" == true ]]; then
        if [[ -n "${config}" ]]; then
            echo 'WARNING: when using the "config" option, you need to manually configure the registry in the provided configurations'
        else
            create_config_with_registry
            args+=(--config "$config_with_registry_path")
        fi
    fi

    if [[ "${cloud_provider}" == true ]]; then
        install_cloud_provider
    fi

    "${kind_dir}/kind" "${args[@]}"
}

copy_docker_creds() {
    echo "🔑 Copying Docker credentials to KinD nodes..."
    docker login paymentology.jfrog.io -u "${OIDC_USER}" -p "${OIDC_TOKEN}"
    for node in $("${kind_dir}/kind" get nodes --name "${cluster_name}"); do
        docker cp $HOME/.docker/config.json $node:/var/lib/kubelet/config.json
    done
    echo "✅ Docker credentials copied."
}

setup_kyverno() {
    echo "📦 Adding Kyverno Helm repository and updating..."
    helm repo add kyverno https://kyverno.github.io/kyverno/
    helm repo update
    echo "🚀 Installing Kyverno in namespace '${KYVERNO_NAMESPACE}'..."
    helm install kyverno kyverno/kyverno --namespace "${KYVERNO_NAMESPACE}" --create-namespace
    echo "✅ Kyverno installed."
}

apply_kyverno_policies() {
    echo "📜 Applying Kyverno policies from '${KYVERNO_POLICY_PATH}'..."
    kubectl apply -f "${KYVERNO_POLICY_PATH}"
    echo "✅ Kyverno policies applied."
}

create_bl_k8s_secret() {
    echo "🔐 Creating secret '${SECRET_NAME}' in namespace '${APP_NAMESPACE}'..."
    kubectl create namespace "${APP_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
    
    if [[ -z "${CONFIG_DESCRIPTOR_KEY:-}" ]]; then
        echo "ERROR: CONFIG_DESCRIPTOR_KEY is not set!"
        exit 1
    else
        echo "Using CONFIG_DESCRIPTOR_KEY: ${CONFIG_DESCRIPTOR_KEY}"
    fi
    
    
    kubectl create secret generic "${SECRET_NAME}" \
      --from-literal=configDescriptorKey="${CONFIG_DESCRIPTOR_KEY}" \
      -n "${APP_NAMESPACE}" -o yaml | kubectl apply -f -
    echo "✅ Secret '${SECRET_NAME}' created."
}


main "$@"
