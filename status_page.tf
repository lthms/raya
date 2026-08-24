resource "betteruptime_status_page" "main" {
  company_name = "lthms’ cloud lab"
  company_url  = "https://soap.coffee/~lthms"
  subdomain    = "raya"
  timezone     = "Paris"

  design = "v2"
  theme  = "light"
  layout = "vertical"
}

resource "betteruptime_monitor" "control_plane" {
  url                 = hcloud_server.control_plane.ipv4_address
  monitor_type        = "ping"
  check_frequency     = 180
  confirmation_period = 180

  # All four regions BetterStack offers, so a probe-side network problem in one
  # of them can be told apart from the VM actually being down.
  regions = ["us", "eu", "as", "au"]
}

resource "betteruptime_status_page_section" "reachability" {
  status_page_id = betteruptime_status_page.main.id
  name           = "VMs are reachable"
  position       = 1
}

resource "betteruptime_status_page_resource" "control_plane" {
  status_page_id         = betteruptime_status_page.main.id
  status_page_section_id = betteruptime_status_page_section.reachability.id
  resource_id            = betteruptime_monitor.control_plane.id
  resource_type          = "Monitor"
  public_name            = "control-plane"
  widget_type            = "history"
}

resource "betteruptime_monitor" "hello" {
  url          = "https://${local.hello_hostname}"
  monitor_type = "keyword"

  # traefik/whoami echoes the request back, starting with the name of the pod
  # that served it. See templates/manifests/hello.yaml.
  required_keyword = "Hostname:"

  check_frequency     = 180
  confirmation_period = 180

  regions = ["us", "eu", "as", "au"]
}

resource "betteruptime_status_page_section" "serving" {
  status_page_id = betteruptime_status_page.main.id
  name           = "The cluster serves traffic"
  position       = 0
}

resource "betteruptime_status_page_resource" "hello" {
  status_page_id         = betteruptime_status_page.main.id
  status_page_section_id = betteruptime_status_page_section.serving.id
  resource_id            = betteruptime_monitor.hello.id
  resource_type          = "Monitor"
  public_name            = "hello over HTTPS"
  widget_type            = "history"
}
