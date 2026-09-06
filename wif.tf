locals {
  wif_audience = "//iam.googleapis.com/${google_iam_workload_identity_pool_provider.raya_provider.name}"
}

resource "google_iam_workload_identity_pool" "raya_pool" {
  workload_identity_pool_id = "raya-pool"
  description               = "Identity pool for raya authentication"
}

resource "google_iam_workload_identity_pool_provider" "raya_provider" {
  workload_identity_pool_provider_id = "raya-provider"
  workload_identity_pool_id          = google_iam_workload_identity_pool.raya_pool.workload_identity_pool_id

  attribute_mapping = {
    "google.subject" = "assertion.sub"
  }

  oidc {
    issuer_uri = "https://${local.oidc_hostname}"
  }
}

resource "google_service_account_iam_member" "external_dns" {
  service_account_id = google_service_account.external_dns.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principal://iam.googleapis.com/${google_iam_workload_identity_pool.raya_pool.name}/subject/system:serviceaccount:kube-system:external-dns"
}

resource "google_service_account_iam_member" "cert_manager" {
  service_account_id = google_service_account.cert_manager.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principal://iam.googleapis.com/${google_iam_workload_identity_pool.raya_pool.name}/subject/system:serviceaccount:kube-system:cert-manager"
}
