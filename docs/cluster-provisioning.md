# Provisioning the cluster

Following the steps of [`tinkerbell`](https://github.com/lthms/tinkerbell) and
[`elsa`](https://github.com/lthms/elsa), `raya` is built on top of [Fedora
CoreOS][fcos]. Mostly for reducing costs, it is deployed on [Hetzner
Cloud][hcloud].

## Building a CoreOS image for Hetzner

While Hetzner Cloud is a great provider, it sadly does not provide a CoreOS
image its VMs can boot from. This forces us to build one ourselves, and we do
so using [Packer].

The Packer template we use is `image/fcos.pkr.hcl`. Because Fedora CoreOS
provides artifacts for Hetzner for its releases, the template mostly consists
of downloading them and burning them onto a throwaway server’s disk
(`image/install.sh`) using `dd`. As a consequence, CoreOS itself never boots
during the build, which is why Ignition still runs on first boot of every
server made from the snapshot. Once the disk is written, a snapshot is
published, with labels allowing us to use it from a Terraform configuration.
This is what the `hcloud_image.fcos` data source is used for (declared in
`cluster.tf`).

`image/build.sh` is a script that can be used to build the image iff it does
not already exist. If it does, calling the script returns without building
anything.

_Which_ image is burnt is decided by the `image/fcos.pin` file, which specifies
the stream (among `stable`, `testing`, or `next`, we use `stable` for now),
version and sha256 hash of the image. `image/fcos.pkr.hcl`, `image/build.sh`
and `cluster.tf` all read it, making it the source of truth everybody trusts.

[fcos]: https://fedoraproject.org/coreos/
[hcloud]: https://www.hetzner.com/cloud/
[Packer]: https://developer.hashicorp.com/packer

## Provisioning the VMs

All the VMs that make up `raya` are declared via the same pattern inside the
`cluster.tf` file. The starting point is a Butane configuration file, written
as a Terraform template file so that we can inject Terraform variables when
building the plan. This configuration file is transpiled to an Ignition config
using the [`poseidon/ct` provider][ct]. The Ignition config is fed to the VM by
passing it via the `user_data` field of a new `hcloud_server` resource.

!!! important

    Ignition configs are likely to embed secrets. Terraform does not treat
    `user_data` as a sensitive field, and `ct` does not mark its `rendered`
    result as sensitive either, even when its input is. By default, Terraform
    will therefore output `user_data` (at least partially) with `terraform
    plan`.

    To prevent that, we systematically mark it as sensitive using the
    `sensitive()` built-in, in order to avoid leaking secrets via the CI logs.

[ct]: https://registry.terraform.io/providers/poseidon/ct/latest/docs

### The control plane

The control plane is provisioned from the Butane config file
`control_plane.bu.tftpl`. For now, it runs a bare CoreOS image without any
user, so while the VM does get a public IP, there is no way to log into it.
