data "hcloud_image" "fcos" {
  with_selector     = "managed_by=raya,os=fcos,fcos_version=${local.fcos_version}"
  with_architecture = "x86"
  most_recent       = true
}

data "jinja_template" "control_plane" {
  source {
    template  = file("${path.module}/templates/control_plane.bu.j2")
    directory = "${path.module}/templates"
  }

  context {
    type = "json"
    data = jsonencode({
      private_ip      = local.control_plane_private_ip
      private_gateway = local.private_gateway
      authorized_keys = local.authorized_keys
    })
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
