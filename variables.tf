variable "hcloud_token" {
  type        = string
  description = "Hetzner Cloud API token"
  sensitive   = true
}

variable "control_plane_server_type" {
  type        = string
  description = "server type for the control plane"
  default     = "cx23"
}

variable "control_plane_location" {
  type        = string
  description = "datacenter location for the control plane"
  default     = "hel1"
}
