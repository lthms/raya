data "hcloud_image" "fcos" {
  with_selector     = "managed_by=raya,os=fcos,fcos_version=${local.fcos_version},k3s_version=${local.k3s_version_label}"
  with_architecture = "x86"
  most_recent       = true
}

resource "random_password" "k3s_token" {
  length  = 48
  special = false
}

data "jinja_template" "control_plane" {
  source {
    template  = file("${path.module}/templates/control_plane.bu.j2")
    directory = "${path.module}/templates"
  }

  context {
    type = "json"
    data = sensitive(jsonencode({
      private_ip      = local.control_plane_private_ip
      private_gateway = local.private_gateway
      authorized_keys = local.authorized_keys
      k3s_token       = random_password.k3s_token.result

      k3s_volume_device = local.control_plane_volume_device
      # systemd derives a .device unit name from the path by escaping `-` as
      # `\x2d` and turning `/` into `-`; the ordering in the units below needs
      # that name, and there is no way to ask systemd for it from here.
      k3s_volume_device_unit = format("%s.device", replace(
        replace(trimprefix(local.control_plane_volume_device, "/"), "-", "\\x2d"),
        "/", "-",
      ))
    }))
  }

  strict_undefined = true
}

data "ct_config" "control_plane" {
  content = data.jinja_template.control_plane.result
  strict  = true
}

resource "hcloud_server" "control_plane" {
  name        = "control-plane"
  server_type = local.control_plane_server_type
  location    = local.control_plane_location
  image       = data.hcloud_image.fcos.id
  user_data   = sensitive(data.ct_config.control_plane.rendered)
}

resource "hcloud_server_network" "control_plane" {
  server_id = hcloud_server.control_plane.id
  subnet_id = hcloud_network_subnet.nodes.id
  ip        = local.control_plane_private_ip
}

# The cluster's datastore and PKI living under /var/lib/rancher/k3s
resource "hcloud_volume" "control_plane_k3s" {
  name     = "control-plane-k3s"
  size     = local.control_plane_volume_size
  location = local.control_plane_location
}

resource "hcloud_volume_attachment" "control_plane_k3s" {
  volume_id = hcloud_volume.control_plane_k3s.id
  server_id = hcloud_server.control_plane.id

  # The mount unit in the Butane config owns this, not the guest agent.
  automount = false
}
