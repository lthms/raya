# The flux-system namespace

The control plane API endpoint is only reachable from within the cluster, via
its private interface. This means our only opportunity to _push_ something to
the cluster is at provision time via the Ignition config of the control plane.

To deploy workloads, we use [Flux] to _pull_ specs instead from git
repositories. Flux is configured in two steps. A “bootstrap” is embedded in the
Ignition config. This bootstraps declares a `GitRepository` resource for
`raya`’s own upstream, and a `Kustomization` telling Flux to watch the
`deploy/` directory.

As a consequence, any (transitive) changes to `deploy/kustomization.yaml` will
trigger Flux to sync the cluster accordingly.

Three of the chart’s six controllers are installed. `source-controller` and
`kustomize-controller` are the two a git-to-cluster reconciliation needs.
`helm-controller` joins them to reconcile the `HelmRelease` resources.

!!! note

    The chart ships three more controllers, which `raya` turns off.

    - `image-reflector-controller` and `image-automation-controller` watch a
      registry for new tags and commit the update back to git. That would
      streamline remaining up-to-date.
    - `notification-controller` sends events outwards and receives webhooks,
      which lets a push trigger a sync rather than waiting for the interval to
      come round. We will definitely enable that one in the future.

[Flux]: https://fluxcd.io/

## SOPS decryption

Flux pulls from public repositories, so any secret a workload needs and cannot
derive (an API token, a bucket key, etc.) has to be committed. [SOPS] encrypts
those values in place, and Flux decrypts them on its way into the cluster.

`.sops.yaml` selects the Google Cloud KMS key `raya-sops/sops` in
`europe-west4`. Each encrypted file stores its data key wrapped by that KMS key.
Flux authenticates through workload identity: `kms.tf` grants its Google
service account permission to decrypt, and `wif.tf` permits the Kubernetes
service account to use it. `deploy/flux-decryption/helm-config.yaml` configures
that identity as the controller's default for decryption.

[SOPS]: https://github.com/getsops/sops

A `Kustomization` opts into decryption using the controller's default identity:

```yaml
spec:
  decryption:
    provider: sops
```

See `deploy/kube-system.yaml`, `deploy/postgresql.yaml` and
`deploy/cloud-lab.yaml` for concrete examples.

Adding a credential is then three steps: write the `Secret` in cleartext,
encrypt it in place (`sops -e -i`), and reference it from the directory’s
`kustomization.yaml`.

```bash
sops -e -i deploy/postgresql/r2-secret.yaml
```

Editing one later is `sops deploy/postgresql/r2-secret.yaml`, which decrypts to
a temporary file, opens `$EDITOR`, and re-encrypts on save. Local editing
requires Google credentials with KMS encrypt and decrypt permissions for that key.
`sops` itself is pinned in `mise.toml`.
