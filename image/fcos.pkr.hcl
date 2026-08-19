packer {
  required_plugins {
    hcloud = {
      source  = "github.com/hetznercloud/hcloud"
      version = ">= 1.6.0"
    }
  }
}

variable "hcloud_token" {
  type      = string
  sensitive = true
  default   = env("HCLOUD_TOKEN")
}

# image/fcos.pin is the single source of truth for which artifact we build.
locals {
  pin = jsondecode(file("fcos.pin"))

  fcos_stream       = local.pin.stream
  fcos_version      = local.pin.version
  fcos_image_sha256 = local.pin.sha256

  fcos_image_url = join("/", [
    "https://builds.coreos.fedoraproject.org/prod/streams",
    local.fcos_stream,
    "builds",
    local.fcos_version,
    "x86_64",
    "fedora-coreos-${local.fcos_version}-hetzner.x86_64.raw.xz",
  ])
}

source "hcloud" "fcos" {
  token = var.hcloud_token

  image  = "debian-12"
  rescue = "linux64"

  location     = "hel1"
  server_type  = "cx23"
  server_name  = "raya-image-builder"
  ssh_username = "root"

  snapshot_name = "fcos-${local.fcos_version}"
  snapshot_labels = {
    managed_by   = "raya"
    os           = "fcos"
    fcos_stream  = local.fcos_stream
    fcos_version = local.fcos_version
  }
}

build {
  sources = ["source.hcloud.fcos"]

  provisioner "shell" {
    script = "${path.root}/install.sh"
    environment_vars = [
      "FCOS_IMAGE_URL=${local.fcos_image_url}",
      "FCOS_IMAGE_SHA256=${local.fcos_image_sha256}",
    ]
  }
}
