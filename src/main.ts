// Copyright The Helm Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import * as core from '@actions/core';
import {Kind} from './kind';

const VersionInput = "version";
const NodeImageInput = "node-image";
const ConfigInput = "config";
const ClusterNameInput = "cluster-name";
const WaitDurationInput = "wait-duration";
const LogLevelInput = "log-level";
const InstallLocalPathProvisionerInput = "install-local-path-provisioner";

export function createKind(): Kind {
    const version: string = core.getInput(VersionInput);
    const config: string = core.getInput(ConfigInput);
    const nodeImage: string = core.getInput(NodeImageInput);
    const clusterName: string = core.getInput(ClusterNameInput);
    const waitDuration: string = core.getInput(WaitDurationInput);
    const logLevel: string = core.getInput(LogLevelInput);
    const installLocalPathProvisioner = core.getInput(InstallLocalPathProvisionerInput) === "true";

    return new Kind(version, config, nodeImage, clusterName, waitDuration, logLevel, installLocalPathProvisioner)
}

async function run() {
    try {
        const kind = createKind();
        await kind.install();
        await kind.createCluster();
    } catch (error) {
        core.setFailed(error.message);
    }
}

run();
