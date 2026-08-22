locals {
  fcos_pin     = jsondecode(file("${path.module}/image/fcos.pin"))
  fcos_version = local.fcos_pin.version

  control_plane_server_type = "cx23"
  control_plane_location    = "hel1"

  network_zone     = "eu-central"
  network_ip_range = "10.0.0.0/16"
  nodes_ip_range   = "10.0.1.0/24"

  # Hetzner routes the private network through the first address of the network
  # range, not of the subnet.
  private_gateway          = cidrhost(local.network_ip_range, 1)
  control_plane_private_ip = cidrhost(local.nodes_ip_range, 10)

  authorized_users = ["lthms"]
  authorized_keys = sort(flatten([
    for user in local.authorized_users :
    compact(split("\n", data.http.github_keys[user].response_body))
  ]))
}
