variable "hcloud_token" {
  type        = string
  description = "Hetzner Cloud API token"
  sensitive   = true
}

variable "hcloud_cluster_token" {
  type        = string
  description = "Hetzner Cloud API token the components running inside the cluster authenticate with"
  sensitive   = true
}

variable "betterstack_token" {
  type        = string
  description = "BetterStack API token"
  sensitive   = true
}

variable "gcp_terraform_credentials" {
  type        = string
  description = "Google service account key for Terraform"
  sensitive   = true
}

variable "ovh_client_id" {
  type        = string
  description = "OVHcloud OAuth2 client ID"
  sensitive   = true
}

variable "ovh_client_secret" {
  type        = string
  description = "OVHcloud OAuth2 client secret"
  sensitive   = true
}
