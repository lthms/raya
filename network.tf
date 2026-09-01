locals {
  network_zone     = "eu-central"
  network_ip_range = "10.0.0.0/16"
  nodes_ip_range   = "10.0.1.0/24"

  # Hetzner routes the private network through the first address of the network
  # range, not of the subnet.
  private_gateway          = cidrhost(local.network_ip_range, 1)
  control_plane_private_ip = cidrhost(local.nodes_ip_range, 10)

  # Agents start a decade above the control plane, so the two ranges never
  # collide and the address of a node can be read as its role. The index is the
  # position in local.agents_server_types, which is also the agent's name and the
  # record dns.tf publishes for it.
  agents_private_ips = [
    for i in range(length(local.agents_server_types)) :
    cidrhost(local.nodes_ip_range, 20 + i)
  ]
}

resource "hcloud_network" "raya" {
  name     = "raya"
  ip_range = local.network_ip_range
}

resource "hcloud_network_subnet" "nodes" {
  network_id   = hcloud_network.raya.id
  type         = "cloud"
  network_zone = local.network_zone
  ip_range     = local.nodes_ip_range
}

resource "hcloud_firewall" "nodes" {
  name = "nodes"

  # SSH is the only way in to a node, and the only way to the API server:
  # docs/administrating.md tunnels 6443 over it.
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = ["0.0.0.0/0"]
  }

  # Traefik runs as a DaemonSet behind ServiceLB, so every node answers on both
  # ports, control plane included. 80 only redirects — ACME is DNS-01.
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "80"
    source_ips = ["0.0.0.0/0"]
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "443"
    source_ips = ["0.0.0.0/0"]
  }

  # Dropping ICMP costs a ping and breaks path MTU discovery.
  rule {
    direction  = "in"
    protocol   = "icmp"
    source_ips = ["0.0.0.0/0"]
  }
}

resource "hcloud_firewall_attachment" "nodes" {
  firewall_id = hcloud_firewall.nodes.id

  server_ids = concat(
    [hcloud_server.control_plane.id],
    hcloud_server.agents[*].id,
  )
}
