locals {
  fcos_pin     = jsondecode(file("${path.module}/image/fcos.pin"))
  fcos_version = local.fcos_pin.version

  k3s_pin     = jsondecode(file("${path.module}/image/k3s.pin"))
  k3s_version = local.k3s_pin.version

  # Hetzner label values reject the `+` in the release tag. image/fcos.pkr.hcl
  # and image/build.sh apply the same rewrite when they stamp the snapshot.
  k3s_version_label = replace(local.k3s_version, "+", "-")

  control_plane_server_type = "cx23"
  control_plane_location    = "hel1"

  # 10 GB is Hetzner's floor (they go 10 GB to 10 TB in 1 GB steps), and generous
  # for a single-node sqlite datastore plus the PKI:
  # https://docs.hetzner.com/cloud/volumes/overview
  control_plane_volume_size = 10

  # Precomputed instead of reading hcloud_volume_attachement.control_plane_k3s.linux_device,
  # to avoid a circular dependency (we need to know it _before_ that attachement).
  # https://docs.hetzner.cloud/reference/cloud#volumes
  control_plane_volume_device = "/dev/disk/by-id/scsi-0HC_Volume_${hcloud_volume.control_plane_k3s.id}"

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
