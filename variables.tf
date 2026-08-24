variable "control_plane_server_type" {
  type        = string
  description = "The server_type for the VM running the k3s control plane"
}

variable "control_plane_location" {
  type        = string
  description = "The location for the VM running the k3s control plane"
}

variable "control_plane_volume_size" {
  type        = number
  description = "The size of the volume attached to the control plane VM to hold its datastore and PKI"
}

variable "authorized_users" {
  type        = list(string)
  description = "List of GitHub handles authorized to connect to the VMs over SSH, using their account’s private key"
}

variable "cluster_managed_subdomain" {
  type        = string
  description = "The subdomain of xmu.mx owned and managed by the cluster for its own needs"
}
