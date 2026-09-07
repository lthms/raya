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

resource "random_password" "k3s_agent_token" {
  length  = 48
  special = false
}

locals {
  control_plane_volume_device = "/dev/disk/by-id/scsi-0HC_Volume_${hcloud_volume.control_plane_k3s.id}"
}

locals {
  # Everything the control plane's Ignition needs that does not say which node
  # it is. The name is the one piece left out: it is a hash of this render, so
  # it cannot be part of it.
  control_plane_shared_context = {
    private_ip      = local.control_plane_private_ip
    private_gateway = local.private_gateway
    authorized_keys = local.authorized_keys
    k3s_token       = random_password.k3s_token.result
    k3s_agent_token = random_password.k3s_agent_token.result

    k3s_volume_device = local.control_plane_volume_device
    # systemd derives a .device unit name from the path by escaping `-` as
    # `\x2d` and turning `/` into `-`; the ordering in the units below needs
    # that name, and there is no way to ask systemd for it from here.
    k3s_volume_device_unit = format("%s.device", replace(
      replace(trimprefix(local.control_plane_volume_device, "/"), "-", "\\x2d"),
      "/", "-",
    ))

    gcp_project  = jsondecode(var.gcp_terraform_credentials).project_id
    wif_audience = local.wif_audience

    # cert-manager's DNS-01 solver. The component that publishes names
    # federates instead. See dns.tf.
    gcp_acme_dns_credentials = google_service_account_key.cert_manager.private_key

    acme_email = local.acme_email

    # The zone the cluster's own names are built under. See dns.tf.
    primary_dns_zone = trimsuffix(google_dns_managed_zone.primary.dns_name, ".")

    # Handed to Flux through a ConfigMap rather than baked into a manifest,
    # so deploy/kube-system/hello.yaml and status_page.tf share one spelling.
    # See dns.tf.
    hello_hostname = local.hello_hostname
    oidc_hostname  = local.oidc_hostname

    sops_age_key = var.sops_age_key
  }
}

data "jinja_template" "control_plane_identity" {
  source {
    template  = file("${path.module}/templates/control_plane.bu.j2")
    directory = "${path.module}/templates"
  }

  context {
    type = "json"
    data = sensitive(jsonencode(merge(local.control_plane_shared_context, {
      node_name = "control-plane"
    })))
  }

  strict_undefined = true
}

locals {
  control_plane_revision = substr(sha256(join("\n", [
    data.jinja_template.control_plane_identity.result,
    data.hcloud_image.fcos.id,
    var.cluster_location,
    var.control_plane_server_type,
  ])), 0, 8)

  control_plane_name = "control-plane-${local.control_plane_revision}"
}

data "jinja_template" "control_plane" {
  source {
    template  = file("${path.module}/templates/control_plane.bu.j2")
    directory = "${path.module}/templates"
  }

  context {
    type = "json"
    data = sensitive(jsonencode(merge(local.control_plane_shared_context, {
      node_name = local.control_plane_name
    })))
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

locals {
  # Everything the agent's Ignition needs that does not say which agent it is.
  # The identity and the private address are the only per-index pieces; both are
  # stubbed out for the render below and filled in for the real one.
  agents_shared_context = {
    control_plane_private_ip = local.control_plane_private_ip
    private_gateway          = local.private_gateway
    authorized_keys          = local.authorized_keys

    k3s_agent_token = random_password.k3s_agent_token.result
  }
}

data "jinja_template" "agents_identity" {
  source {
    template  = file("${path.module}/templates/agent.bu.j2")
    directory = "${path.module}/templates"
  }

  context {
    type = "json"
    data = sensitive(jsonencode(merge(local.agents_shared_context, {
      node_name     = "agent"
      node_password = ""
      private_ip    = "0.0.0.0"
    })))
  }

  strict_undefined = true
}

locals {
  agents_revisions = [
    for index in range(length(local.agents_server_types)) :
    substr(sha256(join("\n", [
      data.jinja_template.agents_identity.result,
      data.hcloud_image.fcos.id,
      var.cluster_location,
      local.agents_server_types[index],
    ])), 0, 8)
  ]

  agents_names = [
    for index in range(length(local.agents_server_types)) :
    "agent-${index}-${local.agents_revisions[index]}"
  ]
}

data "jinja_template" "agents" {
  count = length(local.agents_server_types)

  source {
    template  = file("${path.module}/templates/agent.bu.j2")
    directory = "${path.module}/templates"
  }

  context {
    type = "json"
    data = sensitive(jsonencode(merge(local.agents_shared_context, {
      private_ip = local.agents_private_ips[count.index]
      node_name  = local.agents_names[count.index]

      # Derived from the name, not random. See templates/agent.bu.j2.
      node_password = sha256("${random_password.k3s_agent_token.result}:${local.agents_names[count.index]}")
    })))
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
