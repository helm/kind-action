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
    args=()

    if [[ -n "${INPUT_VERSION:-}" ]]; then
        args+=(--version "${INPUT_VERSION}")
    fi

    if [[ -n "${INPUT_CONFIG:-}" ]]; then
        args+=(--config "${INPUT_CONFIG}")
    fi

    if [[ -n "${INPUT_NODE_IMAGE:-}" ]]; then
        args+=(--node-image "${INPUT_NODE_IMAGE}")
    fi

    if [[ -n "${INPUT_CLUSTER_NAME:-}" ]]; then
        args+=(--cluster-name "${INPUT_CLUSTER_NAME}")
    fi

    if [[ -n "${INPUT_WAIT:-}" ]]; then
        args+=(--wait "${INPUT_WAIT}")
    fi

    if [[ -n "${INPUT_LOG_LEVEL:-}" ]]; then
        args+=(--log-level "${INPUT_LOG_LEVEL}")
    fi


    if [[ -n "${INPUT_REGISTRY:-}" ]] && [[ "${INPUT_REGISTRY,,}" = "true" ]]; then
        "$SCRIPT_DIR/registry.sh" "${args[@]}"

        if [[ -n "${INPUT_CONFIG:-}" ]]; then
            echo 'WARNING: when using the "config" option, you need to manually configure the registry in the provided configuration'
        else
            args+=(--config "/etc/kind-registry/config.yaml")
        fi
    fi

    "$SCRIPT_DIR/kind.sh" "${args[@]}"
}

main
