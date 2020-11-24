#------------------------------------------------------------------------------------------------------------------------
#
# Generic variables
#
#------------------------------------------------------------------------------------------------------------------------
variable "owner" {
  description = "Owner of the resource. This variable is used to set the 'owner' label. Will be used as default for each subnet, but can be overridden using the subnet settings."
  type        = string
}

variable "project" {
  description = "Company project name."
  type        = string
}

variable "environment" {
  description = "Company environment for which the resources are created (e.g. dev, tst, acc, prd, all)."
  type        = string
}

#------------------------------------------------------------------------------------------------------------------------
#
# Network and subnet variables
#
#------------------------------------------------------------------------------------------------------------------------

variable "network_name" {
  description = "Name of the VPC"
  type        = string
}

variable "vpc_peers" {
  description = "Map of VPC Peers to be created. The key will be used for the name."
  type        = any
  default     = {}
}

variable "vpc_peer_defaults" {
  description = "Default settings to be used for your vpc peers so you don't need to provide them for each vpc peer separately."
  type = object({
    peer_project_id      = string
    peer_network         = string
    export_custom_routes = bool
    import_custom_routes = bool
  })
  default = null
}

variable "subnets" {
  description = "Map of subnets to be created. The key will be used for the subnet name so it should describe the subnet purpose. The value can be a map with keys to override default settings."
  type        = any
  default     = {}
}

variable "subnet_defaults" {
  description = "Default settings to be used for your subnets so you don't need to provide them for each subnet separately."
  type = object({
    region        = string
    ip_cidr_range = string
    purpose       = string
    role          = string
    secondary_ip_ranges = list(object({
      range_name    = string
      ip_cidr_range = string
    }))
    log_config = object({
      aggregation_interval = string
      flow_sampling        = number
      metadata             = string
    })
    private_ip_google_access = bool
    roles                    = map(map(string))
  })
  default = null
}

variable "routes" {
  description = "Map of custom routes to be created."
  type        = any
  default     = {}
}

variable "route_defaults" {
  description = "Default settings to be used for your routes so you don't need to provide them for each route separately."
  type = object({
    description = string
    dest_range  = string
    priority    = number
    tags        = list(string)
    # Pick only 1 of the following per route
    next_hop_gateway    = string
    next_hop_instance   = string
    next_hop_ip         = string
    next_hop_vpn_tunnel = string # Make sure this points to a TUNNEL (e.g. /vpnTunnels/ in the url) and not a gateway!
    next_hop_ilb        = string
  })
  default = null
}

variable "service_networking_connection" {
  description = "map for private_ip_address settings to use for creation of a service_networking_connection"
  type = map(object({
    private_ip_address = object({
      purpose       = string
      prefix_length = number
      address_type  = string
    })
  }))

  default = {}
}
