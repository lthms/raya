# Provisioning strategies

`k3s` ships a handful of components of its own in `kube-system`, and installs
most of them from bundled Helm charts. `raya` builds on top of that, tweaking
the behavior of some charts or installing others. This is achieved by two
distinct mechanisms:

- The auto-deploy mechanism of `k3s`, as detailed in the [boot
  procedure](boot.md). Modifying these services requires replacing the control
  plane.
- Flux reconciliation. `raya` is configured to track the content of the
  `deploy/` directory.

Because replacing the control plane is disruptive, any services which can
be deployed via a Flux kustomization relies on that mechanism. The remaining
ones cannot for various reasons, and end-up being provisioned via Ignition.

Independently of how they end up being deployed on `raya`, this page describes
the provided services.

The following diagram explicits the Kustomization deployed on this cluster, as
well as their respective dependencies.

```mermaid
flowchart TD
    cert_manager["cert-manager"]
    oidc["oidc"]
    kube_system["kube-system"]
    cluster["cluster"]
    cnpg_system["cnpg-system"]
    postgresql["postgresql"]
    cloud_lab["cloud-lab"]

    cert_manager --> oidc
    oidc --> kube_system
    kube_system --> cluster
    kube_system --> cnpg_system
    cluster --> cnpg_system
    cnpg_system --> postgresql
    cluster --> cloud_lab
    postgresql --> cloud_lab

    classDef raya fill:#dbeafe,stroke:#2563eb,color:#172554
    classDef cloudLab fill:#f3e8ff,stroke:#9333ea,color:#3b0764
    class flux_config,cert_manager,oidc,kube_system,cluster,cnpg_system,postgresql raya
    class cloud_lab cloudLab
```
