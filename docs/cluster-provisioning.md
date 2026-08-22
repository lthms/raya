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

Once the image is burnt onto the disk, the latter is mounted and `k3s` is
copied in `/usrlocal/bin`, ready to be used. Which versioned is provisioned is
decided by the `image/k3s.pin`, using the same logic applied to
`image/fcos.pin`.

[fcos]: https://fedoraproject.org/coreos/
[hcloud]: https://www.hetzner.com/cloud/
[Packer]: https://developer.hashicorp.com/packer

## Provisioning the VMs

All the VMs that make up `raya` are declared via the same pattern inside the
`cluster.tf` file. The starting point is a Butane configuration file, written
as a Jinja template file thanks to the [`NikolaLohinski/jinja`][jinja]
provider. Using templates allows us (1) to share configuration snippets among
the various VMs, and (2) to inject Terraform variables when building the plan.
This configuration file is transpiled to an Ignition config using the
[`poseidon/ct` provider][ct]. The Ignition config is fed to the VM by passing
it via the `user_data` field of a new `hcloud_server` resource.

!!! warning

    Ignition configs are likely to embed secrets. Terraform does not treat
    `user_data` as a sensitive field, and `ct` does not mark its `rendered`
    result as sensitive either, even when its input is. By default, Terraform
    will therefore output `user_data` (at least partially) with `terraform
    plan`.

    To prevent that, we systematically mark it as sensitive using the
    `sensitive()` built-in, in order to avoid leaking secrets via the CI logs.

[ct]: https://registry.terraform.io/providers/poseidon/ct/latest/docs
[jinja]: https://registry.terraform.io/providers/NikolaLohinski/jinja/latest/docs

### Shared configuration

#### Users

We create one user, `core`, with a list of SSH public keys that are authorized
to log into the VMs.

Instead of providing SSH public keys verbatim, we fetch them from GitHub. The
logic is implemented in `github_keys.tf`, and relies on the fact that for a
given GitHub user `$user`, `https://github.com/$user.keys` returns the list of
public keys this user can use (one per line).

As a consequence, giving access to the VMs to someone becomes as simple as
adding their GitHub handle to `local.authorized_users` (declared in
`locals.tf`).

!!! warning

    Adding a new handle to `local.authorized_users` will change the Ignition
    config of the VMs making up `raya`, forcing a complete redeployment. The
    current declaration of `local.authorized_keys` ensures a stable order among
    `terraform plan` calls for this reason.

    Eventually, we will want to migrate to constructing the
    `~/.ssh/authorized_keys` file at startup instead.

#### Private network

The VMs are attached to the `nodes` subnet defined in `network.tf` (see
[Private network](network.md) for more details about the subnet itself).
Attaching a VM in Terraform only gets it a second network interface. That is
not enough in and of itself, as by default CoreOS does not configure that
interface.

As a consequence, our Ignition config ships a NetworkManager [keyfile][nm] for
it. The interface is `enp7s0` (see [Hetzner documentation][hetzdoc]). The
address is statically assigned, with `10.0.0.1` as gateway. This is injected by
Terraform to avoid duplicating the information between the `cluster.tf` file
(when attaching the VM to the subnet) and this file. An explicit route sends
`10.0.0.0/8` through the gateway. This makes other subnets of the network (if
we ever create one) reachable and not just this one. IPv6 is disabled.

Finally, the MTU is set to `1450` (Hetzner’s private network MTU). The MTU is
the one to get right. Leaving it to a default value (1,500 bytes being the most
standard value) does not fail in an explicit way and can even look healthy
(small packets flow). Large transfers would hang, though.

[nm]: https://networkmanager.dev/docs/api/latest/nm-settings-keyfile.html
[hetzdoc]: https://docs.hetzner.com/networking/networks/server-configuration/

!!! note

    Any systemd unit which requires the private interface to be configured
    should order itself after `network-online.target` (and `Wants=` it).
    The `may-fail=false` in the keyfile’s `[ipv4]` section is what makes
    that target wait for this interface in particular.

    ```ini
    [Unit]
    Description=Something that needs the private network
    Wants=network-online.target
    After=network-online.target

    [Service]
    Type=oneshot
    ExecStart=/usr/bin/ping -c1 10.0.1.10

    [Install]
    WantedBy=multi-user.target
    ```

    `Wants=` and `After=` are both needed: the first pulls the target into the
    boot, the second orders against it. `After=` alone silently does nothing if
    nothing else requested the target.

#### Identity of the control plane

To join a k3s cluster, an agent needs to prove it knows a token that is usually
generated by the control plane on its first boot, alongside its own certificate
authorities the first time it starts. This approach is cumbersome, because it
requires to instrument the control plane to upload its token to a vault of
sorts and the agents to wait for the secret to be available.

To avoid this cumbersome procedure, we take a different road: we let Terraform
generate both the token (using `hashicorp/random`) and the CA (using
`hashicorp/tls`), and we embed the relevant secrets in the Ignition configs of
the VMs (depending on their role).

Generating the CA in addition to the token means we can provide enough
information to the agents so that they do not need to trust the control plane
endpoint on first connection. An agent will receive exactly two things: the
address of the control plane, and a token in `k3s`'s *full* form,

```
K10<sha256 of the server CA certificate>::server:<secret>
```

and nothing else.

The two halves of that token do two different jobs. The secret proves the agent
may join. The hash is what removes the need to trust the endpoint: on first
contact the agent downloads the CA bundle from the control plane *without*
validating the certificate it is offered, hashes what it received, and compares
that against the hash embedded in its own token.
