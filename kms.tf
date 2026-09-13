data "google_kms_key_ring" "sops" {
  name     = "raya-sops"
  location = "europe-west4"
}

data "google_kms_crypto_key" "sops" {
  name     = "sops"
  key_ring = data.google_kms_key_ring.sops.id
}

resource "google_service_account" "kustomize_controller" {
  account_id   = "kustomize-controller"
  display_name = "kustomize-controller, decrypting SOPS secrets"
}

resource "google_kms_crypto_key_iam_member" "kustomize_controller" {
  crypto_key_id = data.google_kms_crypto_key.sops.id
  role          = "roles/cloudkms.cryptoKeyDecrypter"
  member        = "serviceAccount:${google_service_account.kustomize_controller.email}"
}

resource "google_kms_crypto_key_iam_member" "sops_editor" {
  crypto_key_id = data.google_kms_crypto_key.sops.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${jsondecode(var.gcp_terraform_credentials).client_email}"
}
