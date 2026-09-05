# Architecture

`raya` can be divided into three layers:

**The platform.** `raya` is made of several VMs, one running k3s’ control plane
and as many agents as declared in the repo (see
`deploy/kube-system/agents.json`). They are hosted by Hetzner, run a Fedora
CoreOS system provisioned via Ignition, and communicate via a private network.
A lot of efforts have been dedicated to ensure the VMs themselves can be thrown
away.

**The cluster services.** I have tried to build a convenient production
environment for my experiments. I kept k3s’ choice for the Ingress controller
(Traefik), set up external-dns and cert-manager, provided the necessary
credentials to Hetzner CSI driver to dynamically allocate external disks,
provisioned a shared Postgres instance with WAL archiving and nightly backups
to a Cloudflare bucket using CloudNativePG, and automated my deployments from
Git repositories using Flux.

**The workloads.** The actual services I have deployed on top of `raya` are
defined in [a dedicated repository][cloud-lab]. They are not documented here.

[cloud-lab]: https://github.com/lthms/cloud-lab/tree/raya

----

For each layer, the same guiding principle applies: manual actions should be
limited to the strict minimum. Deployment happens automatically after a change
reaches the main branch of the appropriate repositories, either because the CI
runs the deployment or because the cluster itself applies the changes.
