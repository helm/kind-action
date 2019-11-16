import * as core from '@actions/core';
import {Kind} from './kind';

const VersionInput = "version";
const NodeImageInput = "nodeImage";
const ConfigFileInput = "configFile";
const ClusterNameInput = "clusterName";
const WaitDurationInput = "waitDuration";
const LogLevelInput = "logLevel";

const KubeConfigPathOutput = "kubeConfigPath";

export function createKind(): Kind {
    const version: string = core.getInput(VersionInput);
    const configFile: string = core.getInput(ConfigFileInput);
    const nodeImage: string = core.getInput(NodeImageInput);
    const clusterName: string = core.getInput(ClusterNameInput);
    const waitDuration: string = core.getInput(WaitDurationInput);
    const logLevel: string = core.getInput(LogLevelInput);

    return new Kind(version, configFile, nodeImage, clusterName, waitDuration, logLevel)
}

async function run() {
    try {
        const kind = createKind()
        await kind.install();
        await kind.createCluster();
        const kubeConfigPath = await kind.getKubeConfigPath()
        core.setOutput(KubeConfigPathOutput, kubeConfigPath)
    } catch (error) {
        core.setFailed(error.message);
    }
}

run();
