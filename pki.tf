locals {
  # Ten years, like elsa's. Rotating a CA is a cluster-level event either way, so
  # a short lifetime would buy a recurring chore and no containment.
  ca_validity_hours = 24 * 365 * 10
}

resource "tls_private_key" "server_ca" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_self_signed_cert" "server_ca" {
  private_key_pem       = tls_private_key.server_ca.private_key_pem
  is_ca_certificate     = true
  validity_period_hours = local.ca_validity_hours

  subject {
    common_name = "k3s-server-ca"
  }

  allowed_uses = [
    "cert_signing",
    "crl_signing",
    "digital_signature",
  ]
}

resource "tls_private_key" "client_ca" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_self_signed_cert" "client_ca" {
  private_key_pem       = tls_private_key.client_ca.private_key_pem
  is_ca_certificate     = true
  validity_period_hours = local.ca_validity_hours

  subject {
    common_name = "k3s-client-ca"
  }

  allowed_uses = [
    "cert_signing",
    "crl_signing",
    "digital_signature",
  ]
}
