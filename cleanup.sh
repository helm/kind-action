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

DEFAULT_CLUSTER_NAME=chart-testing
DEFAULT_REGISTRY_NAME=kind-registry

main() {
    args=(--name "${INPUT_CLUSTER_NAME:-$DEFAULT_CLUSTER_NAME}")
    registry_args=("${INPUT_REGISTRY_NAME:-$DEFAULT_REGISTRY_NAME}")

    if [[ "${INPUT_CLOUD_PROVIDER:-false}" == true ]]; then
        rm -f /usr/local/bin/cloud-provider-kind || true
        rm -rf cloud-provider-kind || true
        rm -f /tmp/cloud-provider.log || true
        rm -f cloud-provider-kind_*_checksums.txt || true
    fi

    docker rm -f "${registry_args[@]}" || "${INPUT_IGNORE_FAILED_CLEAN}"
    
    kind delete cluster "${args[@]}" || "${INPUT_IGNORE_FAILED_CLEAN}"
}

main
