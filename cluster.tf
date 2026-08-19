locals {
  fcos_pin     = jsondecode(file("${path.module}/image/fcos.pin"))
  fcos_version = local.fcos_pin.version
}

data "hcloud_image" "fcos" {
  with_selector     = "managed_by=raya,os=fcos,fcos_version=${local.fcos_version}"
  with_architecture = "x86"
  most_recent       = true
}

data "ct_config" "control_plane" {
  content = templatefile("${path.module}/control_plane.bu.tftpl", {})
  strict  = true
}

resource "hcloud_server" "control_plane" {
  name        = "control-plane"
  server_type = var.control_plane_server_type
  location    = var.control_plane_location
  image       = data.hcloud_image.fcos.id
  user_data   = sensitive(data.ct_config.control_plane.rendered)
}
