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

# image/fcos.pin and image/k3s.pin are the single source of truth for what we
# build: the base artifact and the k3s binary baked into it.
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

  k3s_pin = jsondecode(file("k3s.pin"))

  k3s_version       = local.k3s_pin.version
  k3s_binary_sha256 = local.k3s_pin.sha256

  # Hetzner label values accept only alphanumerics, `-`, `_` and `.`, so the `+`
  # in the release tag cannot go in as-is. locals.tf applies the same rewrite to
  # build the image selector, so the two must stay in step.
  k3s_label = replace(local.k3s_version, "+", "-")

  # In the URL, on the other hand, the `+` has to be percent-encoded.
  k3s_binary_url = join("/", [
    "https://github.com/k3s-io/k3s/releases/download",
    replace(local.k3s_version, "+", "%2B"),
    "k3s",
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

  snapshot_name = "fcos-${local.fcos_version}-k3s-${local.k3s_label}"
  snapshot_labels = {
    managed_by   = "raya"
    os           = "fcos"
    fcos_stream  = local.fcos_stream
    fcos_version = local.fcos_version
    k3s_version  = local.k3s_label
  }
}

build {
  sources = ["source.hcloud.fcos"]

  provisioner "shell" {
    script = "${path.root}/install.sh"
    environment_vars = [
      "FCOS_IMAGE_URL=${local.fcos_image_url}",
      "FCOS_IMAGE_SHA256=${local.fcos_image_sha256}",
      "K3S_BINARY_URL=${local.k3s_binary_url}",
      "K3S_BINARY_SHA256=${local.k3s_binary_sha256}",
    ]
  }
}
