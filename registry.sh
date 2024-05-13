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

DEFAULT_REGISTRY_IMAGE=registry:2
DEFAULT_REGISTRY_NAME=kind-registry
DEFAULT_REGISTRY_PORT=5000
DEFAULT_CLUSTER_NAME=chart-testing

show_help() {
cat <<EOF
Usage: $(basename "$0") <options>

    -h, --help                              Display help
    -i, --registry-image                    The registry image to use (default: $DEFAULT_REGISTRY_IMAGE)
    -n, --registry-name                     The registry name to use (default: $DEFAULT_REGISTRY_NAME)
    -p, --registry-port                     The local port used to bind the registry (default: $DEFAULT_REGISTRY_PORT)
    -d, --enable-delete                     Enable delete operations on the registry (default: false)
        --cluster-name                      The name of the cluster to configure with the registry (default: $DEFAULT_CLUSTER_NAME)

EOF
}

main() {
    local registry_name="$DEFAULT_REGISTRY_NAME"
    local registry_image="$DEFAULT_REGISTRY_IMAGE"
    local registry_port="$DEFAULT_REGISTRY_PORT"
    local enable_delete=false
    local cluster_name="${DEFAULT_CLUSTER_NAME}"

    parse_command_line "$@"

    create_registry
    connect_registry
    config_registry_for_nodes
    document_registry
}

parse_command_line() {
    while :; do
        case "${1:-}" in
            -h|--help)
                show_help
                exit
                ;;
            -n|--registry-name)
                if [[ -n "${2:-}" ]]; then
                    registry_name="$2"
                    shift
                else
                    echo "ERROR: '-n|--registry-name' cannot be empty." >&2
                    show_help
                    exit 1
                fi
                ;;
            -i|--registry-image)
                if [[ -n "${2:-}" ]]; then
                    registry_image="$2"
                    shift
                else
                    echo "ERROR: '-i|--registry-image' cannot be empty." >&2
                    show_help
                    exit 1
                fi
                ;;
            -p|--registry-port)
                if [[ -n "${2:-}" ]]; then
                    registry_port="$2"
                    shift
                else
                    echo "ERROR: '-p|--registry-port' cannot be empty." >&2
                    show_help
                    exit 1
                fi            
                ;;
            -d|--enable-delete)
                if [[ -n "${2:-}" ]]; then
                    enable_delete="$2"
                    shift
                else
                    enable_delete=true
                fi           
                ;;
            --cluster-name)
                if [[ -n "${2:-}" ]]; then
                    cluster_name="$2"
                    shift
                else
                    echo "ERROR: '--cluster-name' cannot be empty." >&2
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

create_registry() {
    echo "Creating local registry..."

    docker run -d --restart=always \
        --name "${registry_name}" \
        --network bridge \
        -p "${registry_port}:5000" \
        -e REGISTRY_STORAGE_DELETE_ENABLED="$enable_delete" \
        $registry_image

    # Local registry is available at $registry_name:$registry_port
    echo "127.0.0.1 $registry_name" | sudo tee -a /etc/hosts

    # Write registry address to output for subsequent steps
    echo "LOCAL_REGISTRY=$registry_name:$registry_port" >> "$GITHUB_OUTPUT"
}

connect_registry() {
    echo "Connecting local registry to cluster network..."

    docker network connect kind "$registry_name"
}

config_registry_for_nodes() {
    # Reference: https://github.com/containerd/containerd/blob/main/docs/hosts.md
    REGISTRY_DIR="/etc/containerd/certs.d/${registry_name}:${registry_port}"

    for node in $(kind get nodes -n "${cluster_name}"); do
        docker exec "${node}" mkdir -p "${REGISTRY_DIR}"
        cat <<EOF | docker exec -i "${node}" cp /dev/stdin "${REGISTRY_DIR}/hosts.toml"
[host."http://${registry_name}:5000"]
EOF
    done
}

document_registry() {
    # Reference: https://github.com/kubernetes/enhancements/tree/master/keps/sig-cluster-lifecycle/generic/1755-communicating-a-local-registry
    echo "Documenting local registry..."

    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "${registry_name}:${registry_port}"
    hostFromClusterNetwork: "${registry_name}:${registry_port}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"

EOF
}

main "$@"
