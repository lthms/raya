locals {
  dns_parent_zone = "xmu.mx"

  # The zones the cluster may write records into.
  dns_zones = [
    trimsuffix(google_dns_managed_zone.primary.dns_name, "."),
    local.dns_parent_zone,
    "soap.coffee"
  ]

  # Where Let's Encrypt sends expiry warnings, and the address raya's ACME
  # account is registered under. Not a secret, so it lives with the other naming
  # decisions rather than in a tfvars file.
  acme_email = "lthms@soap.coffee"

  # The name the `hello` application claims. Built from the pieces above rather
  # than read off the zone, so it is known at plan time: status_page.tf needs it
  # to declare a monitor, and templates/manifests/hello.yaml to declare the
  # Ingress. Spelling it once keeps the two from drifting.
  hello_hostname = "h.${var.cluster_managed_subdomain}.${local.dns_parent_zone}"
}

resource "google_dns_managed_zone" "primary" {
  name        = "raya"
  dns_name    = "${var.cluster_managed_subdomain}.${local.dns_parent_zone}."
  description = "Names raya publishes for itself"
  visibility  = "public"
}

resource "google_dns_record_set" "control_plane" {
  managed_zone = google_dns_managed_zone.primary.name
  name         = "cp.${google_dns_managed_zone.primary.dns_name}"
  type         = "A"

  # Short TTL because the record may have to be updated on VM replacement
  ttl = 300

  rrdatas = [hcloud_server.control_plane.ipv4_address]
}

resource "google_dns_record_set" "agents" {
  count = length(local.agents_server_types)

  managed_zone = google_dns_managed_zone.primary.name
  name         = "a${count.index}.${google_dns_managed_zone.primary.dns_name}"
  type         = "A"

  # Short TTL for the same reason as above.
  ttl = 300

  rrdatas = [hcloud_server.agents[count.index].ipv4_address]
}

resource "google_service_account" "external_dns" {
  account_id   = "external-dns"
  display_name = "external-dns, publishing the names raya's Ingresses claim"
}

resource "google_service_account_key" "external_dns" {
  service_account_id = google_service_account.external_dns.name
}

resource "google_project_iam_member" "external_dns" {
  project = google_service_account.external_dns.project
  role    = "roles/dns.admin"
  member  = "serviceAccount:${google_service_account.external_dns.email}"
}

# cert-manager answers ACME DNS-01 challenges by writing a TXT record under the
# name it is proving control of, which is a strict subset of what external-dns
# does — but Cloud DNS has no role narrow enough to express that, so both end up
# with `dns.admin`. A second identity is still worth the two resources: it can be
# rotated on its own, and the audit log attributes each write.
resource "google_service_account" "cert_manager" {
  account_id   = "cert-manager"
  display_name = "cert-manager, answering ACME challenges for raya's certificates"
}

resource "google_service_account_key" "cert_manager" {
  service_account_id = google_service_account.cert_manager.name
}

resource "google_project_iam_member" "cert_manager" {
  project = google_service_account.cert_manager.project
  role    = "roles/dns.admin"
  member  = "serviceAccount:${google_service_account.cert_manager.email}"
}

data "google_dns_managed_zones" "all" {}

resource "google_dns_record_set" "delegation" {
  managed_zone = one([
    for zone in data.google_dns_managed_zones.all.managed_zones :
    zone.name if zone.dns_name == "${local.dns_parent_zone}."
  ])

  name = google_dns_managed_zone.primary.dns_name
  type = "NS"
  ttl  = 3600

  # No `count` needed now that both zones live in the same provider: the whole
  # nameserver list goes in as the rrdatas of a single record.
  rrdatas = google_dns_managed_zone.primary.name_servers
}
