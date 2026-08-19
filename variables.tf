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
