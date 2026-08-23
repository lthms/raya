# The kube-system namespace

`k3s` ships a handful of components of its own in `kube-system`, and installs
most of them from bundled Helm charts (see [the boot sequence](boot.md)).

This page describes what the resulting cluster offers to the charts deployed on
top of it.

## Traefik, the ingress controller

Applications deployed on `raya` are expected to declare `traefik` as their
`ingressClassName`.

By default, `k3s` deploys Traefik as a single-replica `Deployment`. In such a
setup, a request received by node A is redirected to node B (to reach Traefik)
then to node C (to reach the application).

```mermaid
graph TB
  client(["client"])

  subgraph nodeA["node A"]
    svclb_a["svclb-traefik<br/>:80 · :443"]
  end

  subgraph nodeB["node B"]
    svclb_b["svclb-traefik<br/>:80 · :443"]
    traefik_b["traefik"]
  end

  subgraph nodeC["node C"]
    svclb_c["svclb-traefik<br/>:80 · :443"]
    app["the application"]
  end

  client --> svclb_a
  svclb_a -->|"kube-proxy picks the<br/>only endpoint · source-NAT"| traefik_b
  traefik_b -->|pod network| app

  classDef idle stroke-dasharray:4 3
  class svclb_b,svclb_c idle
```

With such a topology, replacing the node running Traefik results in a
cluster-wide outage until it is rescheduled, which can take several minutes if
Traefik happened to run on the control plane (since the API is down, nothing can
reschedule it).

`k3s` installs Traefik from a `HelmChart` of its own, which `raya` has no
reason to fork. Instead, we deploy a `HelmChartConfig` sharing the same name.
It is used to overwrite the default configuration of `k3s` deployment.

`raya` runs Traefik as a `DaemonSet` instead, and configures the Traefik service
with `externalTrafficPolicy: Local`, meaning a node only ever hands a request to
its own Traefik pod, never to another node’s. Every node terminates ingress
traffic itself.

```mermaid
graph TB
  client(["client"])

  subgraph nodeA["node A"]
    svclb_a["svclb-traefik<br/>:80 · :443"]
    traefik_a["traefik"]
  end

  subgraph nodeB["node B"]
    svclb_b["svclb-traefik<br/>:80 · :443"]
    traefik_b["traefik"]
  end

  subgraph nodeC["node C"]
    svclb_c["svclb-traefik<br/>:80 · :443"]
    traefik_c["traefik"]
    app["the application"]
  end

  client --> svclb_a
  svclb_a -->|"the local pod only<br/>no NAT"| traefik_a
  traefik_a -->|pod network| app

  %% invisible links: keep the three nodes in the same order as above
  traefik_a ~~~ svclb_b
  svclb_b ~~~ app

  classDef idle stroke-dasharray:4 3
  class svclb_b,svclb_c,traefik_b,traefik_c idle
```

As a by-product, since the request is not source-NAT’ed on its way in, Traefik
sees the client’s own address. That is what makes the `X-Forwarded-For` header it
sets trustworthy, and IP allowlisting or per-address rate limiting possible at
all.

Finally, the `websecure` entrypoint (`:443`) has TLS enabled at the chart level,
so an `Ingress` only has to name the `Secret` holding its certificate; there is
nothing to configure on the entrypoint itself.

## external-dns, the name publisher

`external-dns` automates the lifecycle of records necessary for an application
deployed on `raya` to be reached via its declared domain. The DNS zones
`external-dns` can manage are defined in `local.dns_zones`.

By default, `external-dns` writes the address reported by the Ingress’ load
balancer. In our case, since Traefik is a `DaemonSet`, `external-dns` creates
one record per node making up `raya`. DNS sends a client to any node, and every
node can terminate.

Google Cloud DNS is one of the providers external-dns speaks natively. It
authenticates as a service account holding `dns.admin` on a project that holds
nothing but our zones. Records are owned rather than merely written.
`external-dns` keeps a TXT record next to each one, stamped with this cluster’s
name, and runs with `--policy=sync`: a name that stops being claimed is deleted
again, and one that was never ours is left alone.
