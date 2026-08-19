terraform {
  cloud {
    organization = "lthms"
    workspaces {
      name = "raya"
    }
  }

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "1.64.0"
    }
    ct = {
      source  = "poseidon/ct"
      version = "0.14.0"
    }
    betteruptime = {
      source  = "BetterStackHQ/better-uptime"
      version = "0.21.13"
    }
  }
}

provider "hcloud" {
  token = var.hcloud_token
}

provider "betteruptime" {
  api_token = var.betterstack_token
}
