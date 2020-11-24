#---------------------------------------------------------------------------------------------
# Define our locals for increased readability
#---------------------------------------------------------------------------------------------

locals {
  project     = var.project
  environment = var.environment

  # Startpoint for our VPC defaults
  module_vpc_peer_defaults = {
    peer_project_id      = null
    peer_network         = null
    export_custom_routes = false
    import_custom_routes = false
  }
  module_subnet_defaults = {
    region                   = "europe-west4"
    ip_cidr_range            = null
    purpose                  = "PRIVATE"
    role                     = null
    log_config               = null
    secondary_ip_ranges      = []
    private_ip_google_access = true
    roles                    = null
    owner                    = var.owner
  }
  module_route_defaults = {
    description         = "Terrafrom managed custom route"
    dest_range          = null
    priority            = 1000
    tags                = []
    next_hop_gateway    = null
    next_hop_instance   = null
    next_hop_ip         = null
    next_hop_vpn_tunnel = null
    next_hop_ilb        = null
  }

  # Merge defaults with module defaults and user provided variables
  subnet_defaults   = var.subnet_defaults == null ? local.module_subnet_defaults : merge(local.module_subnet_defaults, var.subnet_defaults)
  vpc_peer_defaults = var.vpc_peer_defaults == null ? local.module_vpc_peer_defaults : merge(local.module_vpc_peer_defaults, var.vpc_peer_defaults)
  route_defaults    = var.route_defaults == null ? local.module_route_defaults : merge(local.module_route_defaults, var.route_defaults)

  labels = {
    "project" = substr(replace(lower(local.project), "/[^\\p{Ll}\\p{Lo}\\p{N}_-]+/", "_"), 0, 63)
    "env"     = substr(replace(lower(local.environment), "/[^\\p{Ll}\\p{Lo}\\p{N}_-]+/", "_"), 0, 63)
    "creator" = "terraform"
  }

  # Merge global default settings with specific settings
  subnets = {
    for subnet, settings in var.subnets : subnet => merge(
      local.subnet_defaults,
      settings,
      {
        subnet_name = replace(lower(format("%s", subnet)), " ", "-")
        roles       = { for role, members in try(settings.roles, {}) : role => [for member, type in members : format("%s:%s", type, member)] }
      },
      # private_ip_google_access can not be used on subnets with purpose "INTERNAL_HTTPS_LOAD_BALANCER"
      (try(settings.purpose, "") == "INTERNAL_HTTPS_LOAD_BALANCER" ? {
        private_ip_google_access = false
      } : {})
    )
  }
  vpc_peers = {
    for peer, settings in var.vpc_peers : peer => merge(
      local.vpc_peer_defaults,
      settings,
      {
        peer_name = replace(lower(format("%s", peer)), " ", "-")
      }
    )
  }
  routes = {
    for route, settings in var.routes : route => merge(
      local.route_defaults,
      settings,
      {
        route_name = replace(lower(format("%s", route)), " ", "-")
      }
    )
  }
}

#---------------------------------------------------------------------------------------------
# GCP Resources
#---------------------------------------------------------------------------------------------

resource "google_compute_network" "vpc" {
  name                            = var.network_name
  auto_create_subnetworks         = false
  routing_mode                    = "GLOBAL"
  delete_default_routes_on_create = true
}

resource "google_compute_subnetwork" "map" {
  provider = google-beta

  for_each = local.subnets

  network                  = google_compute_network.vpc.self_link
  name                     = each.value.subnet_name
  ip_cidr_range            = each.value.ip_cidr_range
  region                   = each.value.region
  private_ip_google_access = each.value.private_ip_google_access
  purpose                  = each.value.purpose
  role                     = each.value.role

  dynamic "log_config" {
    for_each = each.value.log_config == null ? {} : { "log_config" = each.value.log_config }
    content {
      aggregation_interval = try(log_config.value.aggregation_interval, null)
      flow_sampling        = try(log_config.value.flow_sampling, null)
      metadata             = try(log_config.value.metadata, null)
    }
  }
  dynamic "secondary_ip_range" {
    for_each = each.value.secondary_ip_ranges
    content {
      range_name    = secondary_ip_range.value.range_name
      ip_cidr_range = secondary_ip_range.value.ip_cidr_range
    }
  }
}

data "google_iam_policy" "map" {
  for_each = { for subnet, settings in local.subnets : subnet => settings if settings.roles != null }

  dynamic "binding" {
    for_each = each.value.roles

    content {
      role    = binding.key
      members = binding.value
    }
  }
}

resource "google_compute_subnetwork_iam_policy" "map" {
  for_each = data.google_iam_policy.map

  subnetwork  = google_compute_subnetwork.map[each.key].name
  policy_data = each.value.policy_data
  project     = google_compute_subnetwork.map[each.key].project
  region      = google_compute_subnetwork.map[each.key].region
}

# VPC Peers
resource "google_compute_network_peering" "map" {
  for_each = local.vpc_peers

  name                 = each.value.peer_name
  network              = google_compute_network.vpc.self_link
  peer_network         = format("projects/%s/global/networks/%s", each.value.peer_project, each.value.peer_network)
  export_custom_routes = each.value.export_custom_routes
  import_custom_routes = each.value.import_custom_routes
}

# Custom Routes
resource "google_compute_route" "map" {
  for_each            = local.routes
  description         = each.value.description
  name                = each.value.route_name
  network             = google_compute_network.vpc.self_link
  dest_range          = each.value.dest_range
  priority            = try(each.value.priority, 1000)
  tags                = each.value.tags
  next_hop_vpn_tunnel = each.value.next_hop_vpn_tunnel
  next_hop_gateway    = each.value.next_hop_gateway
  next_hop_instance   = each.value.next_hop_instance
  next_hop_ip         = each.value.next_hop_ip
  next_hop_ilb        = each.value.next_hop_ilb
}

resource "google_compute_global_address" "map" {
  for_each = var.service_networking_connection

  name          = each.key
  description   = "Reserved for servicenetworking connection"
  purpose       = each.value.private_ip_address.purpose
  prefix_length = each.value.private_ip_address.prefix_length
  address_type  = each.value.private_ip_address.address_type
  network       = google_compute_network.vpc.self_link
}

resource "google_service_networking_connection" "map" {
  for_each = length(keys(var.service_networking_connection)) > 0 ? toset(["servicenetworking"]) : []

  provider = google-beta

  network = google_compute_network.vpc.self_link
  service = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [
    for address in google_compute_global_address.map : address.name
  ]

  depends_on = [
    google_compute_global_address.map
  ]
}
