# HCL expressions cannot do IO, so fetching the keys from GitHub needs a data
# source rather than a function call.
data "http" "github_keys" {
  for_each = toset(local.authorized_users)

  url = "https://github.com/${each.key}.keys"

  request_headers = {
    Accept = "text/plain"
  }

  # Fail fast at plan time instead of feeding a 404 page to Butane.
  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "could not fetch SSH keys for ${each.key}"
    }
  }
}
