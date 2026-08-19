locals {
  fcos_pin     = jsondecode(file("${path.module}/image/fcos.pin"))
  fcos_version = local.fcos_pin.version
}

data "hcloud_image" "fcos" {
  with_selector     = "managed_by=raya,os=fcos,fcos_version=${local.fcos_version}"
  with_architecture = "x86"
  most_recent       = true
}
