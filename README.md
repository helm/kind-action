# *Kind* Action

[![](https://github.com/helm/kind-action/workflows/Test/badge.svg?branch=main)](https://github.com/helm/kind-action/actions)

A GitHub Action for Kubernetes IN Docker - local clusters for testing Kubernetes using [kubernetes-sigs/kind](https://kind.sigs.k8s.io/).

## Usage

### Pre-requisites

Create a workflow YAML file in your `.github/workflows` directory. An [example workflow](#example-workflow) is available below.
For more information, reference the GitHub Help Documentation for [Creating a workflow file](https://help.github.com/en/articles/configuring-a-workflow#creating-a-workflow-file).

### Supported Operating Systems

The action can install `kind` and `kubectl` on Linux, macOS, and Windows runners.

- **Cluster creation requires Docker.** `kind` creates Kubernetes clusters using Docker containers with Linux node images, so a cluster can only be created where Docker (with Linux container support) is available. GitHub-hosted `ubuntu-latest` runners satisfy this.
- **Hosted macOS and Windows runners do not provide Docker for Linux containers.** On these runners use `install_only: true` to install the `kind` and `kubectl` binaries without creating a cluster (the binaries are still added to `PATH`).
- **`registry` and `cloud_provider` are Linux-only.** Enabling either on a non-Linux runner fails with a clear error, since they rely on Linux-specific tools and paths (`sudo`, `/etc/hosts`, `/usr/local/bin`, Docker networking).

### Running in a GitHub Actions job container

When a job runs inside a container, the job container and the kind control-plane
container may not share a network. If the cluster is created but API requests
fail with `connection refused`, configure kind to use the job's Docker network
and address the control plane by its container name. The job container must
already have access to a Docker daemon.

For example, set the network used by the job container and provide a kind
configuration file:

```yaml
# kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  apiServerAddress: "127.0.0.1"
  apiServerPort: 6443
```

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    container:
      image: your-image-with-docker-access
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - uses: helm/kind-action@v1.15.1
        env:
          KIND_EXPERIMENTAL_DOCKER_NETWORK: ${{ job.container.network }}
        with:
          cluster_name: kind
          config: ./kind-config.yaml
      - name: Verify cluster
        run: |
          kubectl config set-cluster kind-kind --server=https://kind-control-plane:6443
          kubectl cluster-info
```

`job.container.network` must resolve to the Docker network shared with the
runner's Docker daemon. If the runner does not expose that network name, set
`KIND_EXPERIMENTAL_DOCKER_NETWORK` to the network name available to the job
container instead. The `kubectl config set-cluster` command assumes the
`cluster_name` is `kind`; for another name, use the corresponding `kind-<name>`
context and node container name. The CI workflow exercises this setup in the
`test-with-job-container` job.

### Inputs

For more information on inputs, see the [API Documentation](https://developer.github.com/v3/repos/releases/#input)

- `version`: The kind version to use (default: `v0.33.0`)
- `version_file`: The path to a file containing the kind version to use. Supports the asdf [`.tool-versions`](https://asdf-vm.com/manage/configuration.html#tool-versions) layout (the `kind` entry) and plain version files. The version is used as-is, so include the leading `v` (for example `kind v0.33.0`). Takes precedence over `version` when set.
- `config`: The path to the kind config file
- `node_image`: The Docker image for the cluster nodes
- `cluster_name`: The name of the cluster to create (default: `chart-testing`)
- `wait`: The duration to wait for the control plane to become ready (default: `60s`)
- `verbosity`: info log verbosity, higher value produces more output
- `kubectl_version`: The kubectl version to use (default: `v1.37.1`)
- `registry`: Whether to configure an insecure local registry (default: `false`)
- `registry_image`: The registry image to use (default: `registry:2`)
- `registry_name`: The registry name to use (default: `kind-registry`)
- `registry_port`: The local port used to bind the registry (default: `5000`)
- `registry_enable_delete`: Enable delete operations on the registry (default: `false`)
- `install_only`: Skips cluster creation, only install kind (default: `false`)
- `ignore_failed_clean`: Whether to ignore the post delete cluster action failing (default: `false`)
- `cloud_provider`: Whether to use cloud provider loadbalancer (default: `false`)

### Example Workflow

Create a workflow (eg: `.github/workflows/create-cluster.yml`):

```yaml
name: Create Cluster

on: pull_request

jobs:
  create-cluster:
    runs-on: ubuntu-latest
    steps:
      - name: Create k8s Kind Cluster
        uses: helm/kind-action@v1
```

This uses [@helm/kind-action](https://github.com/helm/kind-action) GitHub Action to spin up a [kind](https://kind.sigs.k8s.io/) Kubernetes cluster on every Pull Request.
See [@helm/chart-testing-action](https://github.com/helm/chart-testing-action) for a more practical example.

### Configuring Local Registry

Create a workflow (eg: `.github/workflows/create-cluster-with-registry.yml`):


```yaml
name: Create Cluster with Registry

on: pull_request

jobs:
  create-cluster-with-registry:
    runs-on: ubuntu-latest
    steps:
      - name: Kubernetes KinD Cluster
        id: kind
        uses: helm/kind-action@v1
        with:
          registry: true
          registry_name: my-registry
          registry_port: 5001
          registry_enable_delete: true
```

This configures the cluster to use an insecure local registry at `my-registry:5001` and exposes it on the runner host at port `5001`. Use `localhost:5001` for Docker commands on the runner host, and the `LOCAL_REGISTRY` output (i.e. `${{ steps.kind.outputs.LOCAL_REGISTRY }}`) for image references used by workloads inside the cluster.

**Note**: If `config` option is used, you must manually configure the cluster nodes with registry config dir enabled at `/etc/containerd/certs.d`. For example:

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry]
    config_path = "/etc/containerd/certs.d"
```

## Code of conduct

Participation in the Helm community is governed by the [Code of Conduct](CODE_OF_CONDUCT.md).
