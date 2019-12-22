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

DEFAULT_KIND_VERSION=v0.6.1
DEFAULT_CLUSTER_NAME=chart-testing
KUBECTL_VERSION=v1.17.0

show_help() {
cat << EOF
Usage: $(basename "$0") <options>

    -h, --help                              Display help
    -v, --version                           The kind version to use (default: v0.6.1)"
    -c, --config                            The path to the kind config file"
    -i, --node-image                        The Docker image for the cluster nodes"
    -n, --cluster-name                      The name of the cluster to create (default: chart-testing)"
    -w, --wait                              The duration to wait for the control plane to become ready (default: 60s)"
    -l, --log-level                         The log level for kind [panic, fatal, error, warning, info, debug, trace] (default: warning)
    -p, --install-local-path-provisioner    If true, Rancher's local-path provisioner is installed which supports
                                            dynamic volume provisioning on multi-node clusters. The newly created
                                            local-path StorageClass is made the default.

EOF
}

main() {
    local version="$DEFAULT_KIND_VERSION"
    local config=
    local node_image=
    local cluster_name="$DEFAULT_CLUSTER_NAME"
    local wait=60s
    local log_level=
    local install_local_path_provisioner=

    parse_command_line "$@"

    install_kind
    install_kubectl
    create_kind_cluster

    if [[ -n "$install_local_path_provisioner" ]]; then
        install_local_path_provisioner
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
            -l|--log-level)
                if [[ -n "${2:-}" ]]; then
                    log_level="$2"
                    shift
                else
                    echo "ERROR: '--log-level' cannot be empty." >&2
                    show_help
                    exit 1
                fi
                ;;
            -p|--install-local-path-provisioner)
                install_local_path_provisioner=true
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
    curl -sSLo kind "https://github.com/kubernetes-sigs/kind/releases/download/$version/kind-linux-amd64"
    chmod +x kind
    sudo mv kind /usr/local/bin/kind
}

install_kubectl() {
    echo 'Installing kubectl...'
    curl -sSLO "https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/kubectl
}

create_kind_cluster() {
    echo 'Creating kind cluster...'
    local args=(create cluster "--name=$cluster_name" "--wait=$wait")

    if [[ -n "$node_image" ]]; then
        args+=("--image=$node_image")
    fi

    if [[ -n "$config" ]]; then
        args+=("--config=$config")
    fi

    if [[ -n "$log_level" ]]; then
        args+=("--loglevel=$log_level")
    fi

    kind "${args[@]}"
}

install_local_path_provisioner() {
    echo 'Installing local-path provisioner...'
    kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml

    echo 'Changing default StorageClass...'
    kubectl patch storageclass standard --patch '{"metadata": {"annotations": {"storageclass.kubernetes.io/is-default-class": "false"}}}'
    kubectl patch storageclass standard --patch '{"metadata": {"annotations": {"storageclass.beta.kubernetes.io/is-default-class": "false"}}}'
    kubectl patch storageclass local-path --patch '{"metadata": {"annotations": {"storageclass.kubernetes.io/is-default-class": "true"}}}'
    kubectl patch storageclass local-path --patch '{"metadata": {"annotations": {"storageclass.beta.kubernetes.io/is-default-class": "true"}}}'

    echo 'Available StorageClasses:'
    kubectl get storageclasses
}

main "$@"
