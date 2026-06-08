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

DEFAULT_KIND_VERSION=v0.31.0
DEFAULT_CLUSTER_NAME=chart-testing
DEFAULT_KUBECTL_VERSION=v1.35.0
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

    parse_command_line "$@"

    if [[ ! -d "${RUNNER_TOOL_CACHE}" ]]; then
        echo "Cache directory '${RUNNER_TOOL_CACHE}' does not exist" >&2
        exit 1
    fi

    local os
    case $(uname -s) in
        Linux)  os="linux" ;;
        Darwin) os="darwin" ;;
        CYGWIN*|MINGW*|MSYS*) os="windows" ;;
        *) echo "Unsupported OS" >&2; exit 1 ;;
    esac

    local binary_ext=""
    if [[ "${os}" == "windows" ]]; then
        binary_ext=".exe"
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
    if [[ ! -x "${kind_dir}/kind${binary_ext}" ]]; then
        install_kind
    fi

    echo 'Adding kind directory to PATH...'
    echo "${kind_dir}" >> "${GITHUB_PATH}"

    local kubectl_dir="${cache_dir}/kubectl/bin/"
    if [[ ! -x "${kubectl_dir}/kubectl${binary_ext}" ]]; then
        install_kubectl
    fi

    echo 'Adding kubectl directory to PATH...'
    echo "${kubectl_dir}" >> "${GITHUB_PATH}"

    "${kind_dir}/kind${binary_ext}" version
    "${kubectl_dir}/kubectl${binary_ext}" version --client=true

    if [[ "${install_only}" == false ]]; then
      create_kind_cluster
    fi
}

parse_command_line() {
    while :; do
        case "${1:-}" in
            -h|--help)
                show_help
                exit
                ;;
            --version)
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
            -v|--verbosity)
                if [[ -n "${2:-}" ]]; then
                    verbosity="$2"
                    shift
                else
                    echo "ERROR: '--verbosity' cannot be empty." >&2
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
                    install_only=true
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
    pushd "${kind_dir}" > /dev/null

    local binary_name="kind-${os}-${arch}"
    
    # Download Binary
    curl -sSLo "${binary_name}" "https://github.com/kubernetes-sigs/kind/releases/download/${version}/${binary_name}"
    
    # Download Checksum
    curl -sSLo "${binary_name}.sha256sum" "https://github.com/kubernetes-sigs/kind/releases/download/${version}/${binary_name}.sha256sum"
    
    # Verify Checksum
    local sum_cmd="sha256sum"
    if ! command -v sha256sum &> /dev/null; then
        if command -v shasum &> /dev/null; then
            sum_cmd="shasum -a 256"
        else
            echo "Error: No checksum tool found" >&2; exit 1
        fi
    fi
    
    local expected_sum
    expected_sum=$(awk '{print $1}' "${binary_name}.sha256sum")
    
    local actual_sum
    actual_sum=$($sum_cmd "${binary_name}" | awk '{print $1}')

    if [[ "${expected_sum}" != "${actual_sum}" ]]; then
        echo "Checksum verification failed!" >&2
        exit 1
    fi

    # Install
    if [[ "${os}" == "windows" ]]; then
        mv "${binary_name}" kind.exe
    else
        mv "${binary_name}" kind
        chmod +x kind
    fi
    
    rm -f "${binary_name}.sha256sum"
    popd > /dev/null
}

install_kubectl() {
    echo 'Installing kubectl...'

    mkdir -p "${kubectl_dir}"
    pushd "${kubectl_dir}" > /dev/null
    
    local kubectl_filename="kubectl"
    local url_os="${os}"
    
    if [[ "${os}" == "windows" ]]; then
        kubectl_filename="kubectl.exe"
    fi

    local url="https://dl.k8s.io/release/${kubectl_version}/bin/${url_os}/${arch}/${kubectl_filename}"
    
    curl -sSLo "${kubectl_filename}" "${url}"
    curl -sSLo "${kubectl_filename}.sha256" "${url}.sha256"
    
    local sum_cmd="sha256sum"
    if ! command -v sha256sum &> /dev/null; then
        if command -v shasum &> /dev/null; then
            sum_cmd="shasum -a 256"
        else
            echo "Error: No checksum tool found" >&2; exit 1
        fi
    fi
    
    local expected_sum
    expected_sum=$(awk '{print $1}' "${kubectl_filename}.sha256")
    
    local actual_sum
    actual_sum=$($sum_cmd "${kubectl_filename}" | awk '{print $1}')

    if [[ "${expected_sum}" != "${actual_sum}" ]]; then
        echo "Checksum verification failed!" >&2
        exit 1
    fi
    
    if [[ "${os}" != "windows" ]]; then
        chmod +x kubectl
    fi
    popd > /dev/null
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

    "${kind_dir}/kind${binary_ext}" "${args[@]}"
}

main "$@"
