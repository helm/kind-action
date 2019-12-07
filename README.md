# Kind action

A GitHub Action for Kubernetes IN Docker - local clusters for testing Kubernetes, using [kubernetes-sigs/kind](https://kind.sigs.k8s.io/).

## Usage

### Pre-requisites

1. Create a workflow `.yml` file in your `.github/workflows` directory. An [example workflow](#example-workflow) is available below. For more information, reference the GitHub Help Documentation for [Creating a workflow file](https://help.github.com/en/articles/configuring-a-workflow#creating-a-workflow-file).

### Inputs

For more information on these inputs, see the [API Documentation](https://developer.github.com/v3/repos/releases/#input)

- `version`: The kind version to use (default: `v0.5.1`)
- `config`: The path to the kind config file
- `node-image`: The Docker image for the cluster nodes
- `name`: The name of the cluster to create (default: `chart-testing`)
- `wait`: The duration to wait for the control plane to become ready (default: `60s`)
- `log-level`: The log level for kind
- `install-local-path-provisioner`: If true, Rancher's local-path provisioner
  is installed which supports dynamic volume provisioning on multi-node
  clusters. The newly created local-path StorageClass is made the default.

### Example workflow

Create a workflow (eg: .github/workflows/chart-testing.yml see Creating a Workflow file):

```yaml
name: chart actions

on:
  push:
    branches:    
      - master 

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Create cluster
        uses: helm/kind-action@v1
        with:
          installLocalPathProvisioner: true
```

This uses [`@helm/kind-action`](https://www.github.com/helm/chart-releaser-action) to create a local Kubernetes cluster using [kubernetes-sigs/kind](https://kind.sigs.k8s.io/) – during every push to `master`.

## Code of conduct

Participation in the Helm community is governed by the [Code of Conduct](CODE_OF_CONDUCT.md).
