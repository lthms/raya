locals {
  dns_parent_zone = "xmu.mx"
  dns_subdomain   = "ry"
}

resource "google_dns_managed_zone" "primary" {
  name        = "raya"
  dns_name    = "${local.dns_subdomain}.${local.dns_parent_zone}."
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

resource "google_service_account" "external_dns" {
  account_id   = "external-dns"
  display_name = "external-dns, publishing the names raya's Ingresses claim"
}

resource "google_service_account_key" "external_dns" {
  service_account_id = google_service_account.external_dns.name
}

resource "google_dns_managed_zone_iam_member" "external_dns" {
  for_each = toset([for zone in local.dns_zones : zone.name])

  managed_zone = each.key
  role         = "roles/dns.admin"
  member       = "serviceAccount:${google_service_account.external_dns.email}"
}

output "dns_nameservers" {
  description = "Nameservers the zone has to be delegated to"
  value       = google_dns_managed_zone.primary.name_servers
}

resource "ovh_domain_zone_record" "delegation" {
  # `count` rather than `for_each` because the nameservers are only known once the
  # zone exists, and both `count` and `for_each` need their extent at plan time —
  # a literal 4 gives it to them, and Cloud DNS always assigns exactly four to a
  # public zone. The provider refreshes the OVH zone itself after each write.
  count = 4

  zone      = local.dns_parent_zone
  subdomain = local.dns_subdomain
  fieldtype = "NS"
  ttl       = 3600
  target    = google_dns_managed_zone.primary.name_servers[count.index]
}
