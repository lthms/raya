variable "control_plane_server_type" {
  type        = string
  description = "The server_type for the VM running the k3s control plane"
}

# Every VM in one location also means every hcloud volume is in that location,
# so the CSI driver's location constraint never bites. Worth knowing that the
# day one agent moves elsewhere is the day a stateful pod stops being able to
# follow it.
variable "cluster_location" {
  type        = string
  description = "The location for the VMs making up the cluster"
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
