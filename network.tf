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

