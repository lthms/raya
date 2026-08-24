# Status page

`raya` has its own [status page] hosted on BetterStack. It is completely
specified in `status_page.tf` using the `betteruptime` provider.

The status page is public (and unauthenticated), so anyone can read it. This
means it will “leak” some information about `raya`, like the number of VMs it
is made up of, for instance. Considering `raya`’s IaC is hosted on GitHub, with
`terraform apply` being run by one of the repository’s workflows (whose logs are
public), that disclosure is more than reasonable.

[status page]: https://raya.betteruptime.com

## VMs are reachable

VMs that make up `raya` are reached out to using `ping` every 3 minutes, from
four regions (US, EU, Asia and Australia). This is the most basic test,
ensuring they are still reachable from the Internet via their IPv4 address.

Reachability monitors are attached to the namesake
`betteruptime_status_page_section`. See the `control_plane` monitor and its
`betteruptime_status_page_resource` for a reproducible example.

A single missed check is not enough to declare an outage: BetterStack keeps
probing for another 3 minutes (`confirmation_period`) before flipping the
monitor to down. The status page can therefore lag reality by up to 6 minutes.

!!! note

    The monitor targets `hcloud_server.control_plane.ipv4_address`, not a name.
    Terraform replaces the server whenever its image or Ignition config
    changes, and when it happens the monitor is “recycled” to track the new
    address. The history is kept in the process.

    As a consequence, a rebuild taking more than 3 minutes can trigger an outage.

## End-to-end connectivity with the cluster

`raya` exposes a basic HTTP server at `h.ry.xmu.mx`, and we create a monitor
monitoring that endpoint over HTTPS.

A green check from that monitor actually covers quite a lot: the DNS delegation
resolves (`ry.xmu.mx` is managed by Google Cloud DNS), `external-dns` published
the record on our application installation, a node accepted the connection,
`cert-manager`’s certificate is valid for the name, Traefik routed it, and the
pod answered.
