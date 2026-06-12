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

# Resolve the kind version from a version file. Supports the asdf
# '.tool-versions' format (a line such as "kind v0.31.0") as well as a plain
# file that contains only the version string.
resolve_version_from_file() {
    local file="$1"
    local version=""

    if [[ ! -f "${file}" ]]; then
        echo "ERROR: version_file '${file}' does not exist." >&2
        exit 1
    fi

    # asdf '.tool-versions' format: a line such as "kind v0.31.0".
    version=$(grep -E '^[[:space:]]*kind[[:space:]]+' "${file}" | head -n 1 | tr -d '\r' | awk '{print $2}') || true

    # Otherwise treat the file as a plain version file (first token of the
    # first non-empty, non-comment line).
    if [[ -z "${version}" ]]; then
        version=$(grep -vE '^[[:space:]]*(#|$)' "${file}" | head -n 1 | tr -d '\r' | awk '{print $1}') || true
    fi

    if [[ -z "${version}" ]]; then
        echo "ERROR: no kind version found in version_file '${file}'." >&2
        exit 1
    fi

    echo "${version}"
}

main() {
    local args=()
    local registry_args=()

    # A version file takes precedence over the 'version' input when set.
    if [[ -n "${INPUT_VERSION_FILE:-}" ]]; then
        INPUT_VERSION="$(resolve_version_from_file "${INPUT_VERSION_FILE}")"
        echo "Using kind version '${INPUT_VERSION}' from version_file '${INPUT_VERSION_FILE}'." >&2
    fi

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
        args+=(--install-only "${INPUT_INSTALL_ONLY}")
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

    "${SCRIPT_DIR}/kind.sh" ${args[@]+"${args[@]}"}

    if [[ "${INPUT_REGISTRY:-}" == true ]]; then
        "${SCRIPT_DIR}/registry.sh" "${registry_args[@]}"
    fi
}

main
