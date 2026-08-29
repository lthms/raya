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

variable "sops_age_key" {
  type        = string
  description = "Age private key to be used to decrypt credentials"
  sensitive   = true
}
