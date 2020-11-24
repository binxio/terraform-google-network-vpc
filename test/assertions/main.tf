locals {
  owner       = var.owner
  project     = "testapp"
  environment = var.environment

  network_name = "assert_vpc_name"
  subnets = {
    "no-role" = {
      purpose       = "INTERNAL_HTTPS_LOAD_BALANCING"
      ip_cidr_range = "127.0.0.0/28"
    }
    "role-with-wrong-purpose" = {
      purpose       = "PRIVATE"
      role          = "ACTIVE"
      ip_cidr_range = "127.0.0.0/28"
    }
    "invalid-role" = {
      purpose       = "INTERNAL_HTTPS_LOAD_BALANCING"
      role          = "trigger-invalid"
      ip_cidr_range = "127.0.0.0/28"
    }
    "invalid-purpose" = {
      purpose       = "trigger-invalid"
      role          = "ACTIVE"
      ip_cidr_range = "127.0.0.0/28"
    }
    "trigger-assertions for subnet 'cause this name is too long and has invalid chars" = {
      not_existing  = "should-fail"
      ip_cidr_range = "127.0.0.0/30"
    }
  }
  routes = {
    "nohops" = {
      dest_range  = "127.0.0.1/32"
      description = "No next hop"
    }
    "twohops" = {
      dest_range       = "127.0.0.0/8"
      description      = "No next hop"
      next_hop_gateway = "default-internet-gateway"
      next_hop_ip      = "127.0.0.1"
    }
  }
}

module "vpc" {
  source = "../../"

  owner       = local.owner
  project     = local.project
  environment = local.environment

  network_name = local.network_name
  subnets      = local.subnets
  routes       = local.routes
}
