resource "betteruptime_status_page" "main" {
  company_name = "lthms’ cloud lab"
  company_url  = "https://soap.coffee/~lthms"
  subdomain    = "raya"
  timezone     = "Paris"
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
  position       = 0
}

resource "betteruptime_status_page_resource" "control_plane" {
  status_page_id         = betteruptime_status_page.main.id
  status_page_section_id = betteruptime_status_page_section.reachability.id
  resource_id            = betteruptime_monitor.control_plane.id
  resource_type          = "Monitor"
  public_name            = "control-plane"
  widget_type            = "history"
}
