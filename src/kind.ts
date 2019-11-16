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
import * as toolCache from '@actions/tool-cache';
import * as exec from '@actions/exec';
import * as io from '@actions/io';
import * as path from 'path';

const defaultKindVersion = "v0.5.1";
const defaultClusterName = "chart-testing";

export class Kind {
    constructor(private readonly version: string, private readonly config: string, private readonly nodeImage: string,
                private readonly clusterName: string, private readonly waitDuration: string, private readonly logLevel: string,
                private readonly installLocalPathProvisioner: boolean) {
        if (version === "") {
            this.version = defaultKindVersion;
        }
        if (waitDuration === "") {
            this.waitDuration = "60s"
        }
        if (clusterName === "") {
            this.clusterName = defaultClusterName
        }
    }

    async install() {
        const binDir = path.join(process.env["HOME"] || "", "bin");

        let downloadUrl = `https://github.com/kubernetes-sigs/kind/releases/download/${this.version}/kind-linux-amd64`;
        await installTool("kind", binDir, downloadUrl);

        downloadUrl = "https://storage.googleapis.com/kubernetes-release/release/v1.16.0/bin/linux/amd64/kubectl";
        await installTool("kubectl", binDir, downloadUrl);

        core.addPath(binDir);
    }

    async createCluster() {
        console.log("Creating kind cluster...");

        let args: string[] = ["create", "cluster"];
        if (this.config !== "") {
            args.push("--config", this.config);
        }
        if (this.nodeImage !== "") {
            args.push("--image", this.nodeImage);
        }
        if (this.clusterName !== "") {
            args.push("--name", this.clusterName);
        }
        if (this.waitDuration !== "") {
            args.push("--wait", this.waitDuration);
        }
        if (this.logLevel !== "") {
            args.push("--loglevel", this.logLevel)
        }

        await exec.exec("kind", args);

        await this.setKubeconfig();

        await kubectl("cluster-info");
        await kubectl("get", "nodes");

        if (this.installLocalPathProvisioner) {
            console.log("Installing local-path provisioner...");
            await kubectl(
                "apply",
                "-f",
                "https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml"
            );

            console.log("Changing default StorageClass...");
            await kubectl(
                "patch",
                "storageclass",
                "standard",
                "--patch",
                '{"metadata": {"annotations": {"storageclass.kubernetes.io/is-default-class": "false"}}}'
            );
            await kubectl(
                "patch",
                "storageclass",
                "local-path",
                "--patch",
                '{"metadata": {"annotations": {"storageclass.kubernetes.io/is-default-class": "true"}}}'
            );

            console.log("Available StorageClasses:");
            await kubectl(
                "get",
                "storageclasses"
            );
        }
    }

    async setKubeconfig() {
        let output = '';

        const options = {};
        // @ts-ignore
        options.listeners = {
            stdout: (data: Buffer) => {
                output += data.toString();
            },
        };

        const args = ["get", "kubeconfig-path", "--name", this.clusterName];
        await exec.exec("kind", args, options);

        const defaultKubeconfigPath = path.join(process.env["HOME"] || "", ".kube", "config");
        io.mv(output.trim(), defaultKubeconfigPath)
    }
}

async function kubectl(...args: string[]) {
    await exec.exec("kubectl", args)
}

async function installTool(name: string, binDir: string, downloadUrl: string) {
    console.log(`Installing ${name}...`);

    console.log(`Downloading ${downloadUrl}`);
    let tempBinary: string | null;
    tempBinary = await toolCache.downloadTool(downloadUrl);

    await io.mkdirP(binDir);

    console.log(`Moving ${name} binary to ${binDir}`);
    const binary = path.join(binDir, name);
    await io.mv(tempBinary, binary);

    await exec.exec("chmod", ["+x", binary]);
}
