locals {
  fcos_pin     = jsondecode(file("${path.module}/image/fcos.pin"))
  fcos_version = local.fcos_pin.version

  k3s_pin     = jsondecode(file("${path.module}/image/k3s.pin"))
  k3s_version = local.k3s_pin.version

  # Hetzner label values reject the `+` in the release tag. image/fcos.pkr.hcl
  # and image/build.sh apply the same rewrite when they stamp the snapshot.
  k3s_version_label = replace(local.k3s_version, "+", "-")

  agents_server_types = jsondecode(file("${path.module}/deploy/kube-system/agents.json")).agents
}

data "hcloud_image" "fcos" {
  with_selector     = "managed_by=raya,os=fcos,fcos_version=${local.fcos_version},k3s_version=${local.k3s_version_label}"
  with_architecture = "x86"
  most_recent       = true
}

resource "random_password" "k3s_token" {
  length  = 48
  special = false
}

locals {
  control_plane_volume_device = "/dev/disk/by-id/scsi-0HC_Volume_${hcloud_volume.control_plane_k3s.id}"
}

data "jinja_template" "control_plane" {
  source {
    template  = file("${path.module}/templates/control_plane.bu.j2")
    directory = "${path.module}/templates"
  }

  context {
    type = "json"
    data = sensitive(jsonencode({
      private_ip      = local.control_plane_private_ip
      private_gateway = local.private_gateway
      authorized_keys = local.authorized_keys
      k3s_token       = random_password.k3s_token.result

      k3s_volume_device = local.control_plane_volume_device
      # systemd derives a .device unit name from the path by escaping `-` as
      # `\x2d` and turning `/` into `-`; the ordering in the units below needs
      # that name, and there is no way to ask systemd for it from here.
      k3s_volume_device_unit = format("%s.device", replace(
        replace(trimprefix(local.control_plane_volume_device, "/"), "-", "\\x2d"),
        "/", "-",
      ))

      # Seeded into /var/lib/rancher/k3s/server/tls before k3s first starts, so
      # the cluster's trust root comes from here rather than from the node. See
      # pki.tf.
      server_ca_cert = tls_self_signed_cert.server_ca.cert_pem
      server_ca_key  = tls_private_key.server_ca.private_key_pem
      client_ca_cert = tls_self_signed_cert.client_ca.cert_pem
      client_ca_key  = tls_private_key.client_ca.private_key_pem

      gcp_project = jsondecode(var.gcp_terraform_credentials).project_id

      # Two keys, two service accounts: one for the component that publishes
      # names, one for the component that proves we own them. See dns.tf.
      gcp_dns_credentials      = google_service_account_key.external_dns.private_key
      gcp_acme_dns_credentials = google_service_account_key.cert_manager.private_key

      acme_email = local.acme_email

      # The zone the cluster's own names are built under. See dns.tf.
      primary_dns_zone = trimsuffix(google_dns_managed_zone.primary.dns_name, ".")

      # Handed to Flux through a ConfigMap rather than baked into a manifest,
      # so deploy/kube-system/hello.yaml and status_page.tf share one spelling.
      # See dns.tf.
      hello_hostname = local.hello_hostname

      sops_age_key = var.sops_age_key
    }))
  }

  strict_undefined = true
}

data "ct_config" "control_plane" {
  content = data.jinja_template.control_plane.result
  strict  = true
}

resource "hcloud_server" "control_plane" {
  name        = "control-plane"
  server_type = var.control_plane_server_type
  location    = var.cluster_location
  image       = data.hcloud_image.fcos.id
  user_data   = sensitive(data.ct_config.control_plane.rendered)
}

resource "hcloud_server_network" "control_plane" {
  server_id = hcloud_server.control_plane.id
  subnet_id = hcloud_network_subnet.nodes.id
  ip        = local.control_plane_private_ip
}

# The cluster's datastore and PKI living under /var/lib/rancher/k3s
resource "hcloud_volume" "control_plane_k3s" {
  name     = "control-plane-k3s"
  size     = var.control_plane_volume_size
  location = var.cluster_location
}

resource "hcloud_volume_attachment" "control_plane_k3s" {
  volume_id = hcloud_volume.control_plane_k3s.id
  server_id = hcloud_server.control_plane.id

  # The mount unit in the Butane config owns this, not the guest agent.
  automount = false
}

data "jinja_template" "agents" {
  count = length(local.agents_server_types)

  source {
    template  = file("${path.module}/templates/agent.bu.j2")
    directory = "${path.module}/templates"
  }

  context {
    type = "json"
    data = sensitive(jsonencode({
      control_plane_private_ip = local.control_plane_private_ip
      private_ip               = local.agents_private_ips[count.index]
      private_gateway          = local.private_gateway
      authorized_keys          = local.authorized_keys

      # Full form join token `K10<CA hash>::<user>:<secret>`, see
      # https://github.com/k3s-io/k3s/blob/v1.36.3%2Bk3s1/pkg/clientaccess/token.go
      k3s_token = "K10${sha256(tls_self_signed_cert.server_ca.cert_pem)}::server:${random_password.k3s_token.result}"


      node_name     = "agent-${count.index}"
      node_password = sha256("${random_password.k3s_token.result}:agent-${count.index}")
    }))
  }

  strict_undefined = true
}

data "ct_config" "agents" {
  count = length(local.agents_server_types)

  content = data.jinja_template.agents[count.index].result
  strict  = true
}

resource "hcloud_server" "agents" {
  count = length(local.agents_server_types)

  name        = "agent-${count.index}"
  server_type = local.agents_server_types[count.index]
  location    = var.cluster_location
  image       = data.hcloud_image.fcos.id
  user_data   = sensitive(data.ct_config.agents[count.index].rendered)
}

resource "hcloud_server_network" "agents" {
  count = length(local.agents_server_types)

  server_id = hcloud_server.agents[count.index].id
  subnet_id = hcloud_network_subnet.nodes.id
  ip        = local.agents_private_ips[count.index]
}
