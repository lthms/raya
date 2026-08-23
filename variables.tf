variable "hcloud_token" {
  type        = string
  description = "Hetzner Cloud API token"
  sensitive   = true
}

variable "betterstack_token" {
  type        = string
  description = "BetterStack API token"
  sensitive   = true
}

# A Google service account key, as JSON. Terraform uses it to manage the zone;
# the key the cluster itself holds is a different one, minted by dns.tf and
# scoped to that zone alone.
variable "gcp_terraform_credentials" {
  type        = string
  description = "Google service account key Terraform manages Cloud DNS with"
  sensitive   = true
}

# An OVHcloud OAuth2 service account, needed for one thing only: the NS records
# in xmu.mx that delegate ry.xmu.mx to Google.
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
