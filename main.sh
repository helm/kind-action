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

SCRIPT_DIR=$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}" || realpath "${BASH_SOURCE[0]}")")

main() {
    local args=()
    local registry_args=()
    post_kind_args=()

    if [[ -n "${INPUT_VERSION:-}" ]]; then
        args+=(--version "${INPUT_VERSION}")
    fi

    if [[ -n "${INPUT_CONFIG:-}" ]]; then
        args+=(--config "${INPUT_CONFIG}")
    fi

    if [[ -n "${INPUT_KUBECONFIG:-}" ]]; then
        args+=(--kubeconfig "${INPUT_KUBECONFIG}")
    fi

    if [[ -n "${INPUT_NODE_IMAGE:-}" ]]; then
        args+=(--node-image "${INPUT_NODE_IMAGE}")
    fi

    if [[ -n "${INPUT_CLUSTER_NAME:-}" ]]; then
        args+=(--cluster-name "${INPUT_CLUSTER_NAME}")
        registry_args+=(--cluster-name "${INPUT_CLUSTER_NAME}")
        post_kind_args+=(--cluster-name "${INPUT_CLUSTER_NAME}")
    fi

    if [[ -n "${INPUT_WAIT:-}" ]]; then
        args+=(--wait "${INPUT_WAIT}")
    fi

    if [[ -n "${INPUT_VERBOSITY:-}" ]]; then
        args+=(--verbosity "${INPUT_VERBOSITY}")
    fi

    if [[ -n "${INPUT_KUBECTL_VERSION:-}" ]]; then
        args+=(--kubectl-version "${INPUT_KUBECTL_VERSION}")
    fi

    if [[ -n "${INPUT_INSTALL_ONLY:-}" ]]; then
        args+=(--install-only)
    fi

    if [[ -n "${INPUT_REGISTRY:-}" ]]; then
        args+=(--with-registry "${INPUT_REGISTRY}")
    fi

    if [[ -n "${INPUT_REGISTRY_IMAGE:-}" ]]; then
        registry_args+=(--registry-image "${INPUT_REGISTRY_IMAGE}")
    fi

    if [[ -n "${INPUT_REGISTRY_NAME:-}" ]]; then
        registry_args+=(--registry-name "${INPUT_REGISTRY_NAME}")
    fi

    if [[ -n "${INPUT_REGISTRY_PORT:-}" ]]; then
        registry_args+=(--registry-port "${INPUT_REGISTRY_PORT}")
    fi

    if [[ -n "${INPUT_REGISTRY_ENABLE_DELETE:-}" ]]; then
        registry_args+=(--enable-delete "${INPUT_REGISTRY_ENABLE_DELETE}")
    fi

    if [[ -n "${INPUT_CLOUD_PROVIDER:-}" ]]; then
        args+=(--cloud-provider "${INPUT_CLOUD_PROVIDER}")
    fi

    if [[ -n "${INPUT_KYVERNO_NAMESPACE:-}" ]]; then
        args+=(--kyverno-namespace "${INPUT_KYVERNO_NAMESPACE}")
    fi

    if [[ -n "${INPUT_KYVERNO_POLICY_PATH:-}" ]]; then
        args+=(--kyverno-policy-path "${INPUT_KYVERNO_POLICY_PATH}")
    fi

    if [[ -n "${INPUT_APP_NAMESPACE:-}" ]]; then
        args+=(--app-namespace "${INPUT_APP_NAMESPACE}")
    fi
    
    if [[ -n "${INPUT_SECRET_NAME:-}" ]]; then
        args+=(--secret-name "${INPUT_SECRET_NAME}")
    fi

    if [[ -n "${INPUT_OIDC_USER:-}" ]]; then
        args+=(--oidc-user "${INPUT_OIDC_USER}")
    fi

    if [[ -n "${INPUT_OIDC_TOKEN:-}" ]]; then
        args+=(--oidc-token "${INPUT_OIDC_TOKEN}")
    fi
    if [[ -n "${INPUT_CONFIG_DESCRIPTOR_KEY:-}" ]]; then
        echo "CONFIG_DESCRIPTOR_KEY: ${INPUT_CONFIG_DESCRIPTOR_KEY}"
        args+=(--config-descriptor-key "${INPUT_CONFIG_DESCRIPTOR_KEY}")
    fi



    "${SCRIPT_DIR}/kind.sh" ${args[@]+"${args[@]}"}

    if [[ "${INPUT_REGISTRY:-}" == true ]]; then
        "${SCRIPT_DIR}/registry.sh" "${registry_args[@]}"
    fi
}

main
