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
      version = "1.70.0"
    }
    ct = {
      source  = "poseidon/ct"
      version = "0.14.0"
    }
    betteruptime = {
      source  = "BetterStackHQ/better-uptime"
      version = "0.22.4"
    }
    http = {
      source  = "hashicorp/http"
      version = "3.6.2"
    }
    jinja = {
      source  = "NikolaLohinski/jinja"
      version = "2.4.3"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.9.1"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "4.4.1"
    }
    google = {
      source  = "hashicorp/google"
      version = "7.46.1"
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
