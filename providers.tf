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
    http = {
      source  = "hashicorp/http"
      version = "3.5.0"
    }
    jinja = {
      source  = "NikolaLohinski/jinja"
      version = "2.4.3"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.9.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "4.3.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "7.45.0"
    }
  }
}

provider "hcloud" {
  token = var.hcloud_token
}

provider "betteruptime" {
  api_token = var.betterstack_token
}

provider "google" {
  credentials = var.gcp_terraform_credentials
  project     = jsondecode(var.gcp_terraform_credentials).project_id
}
