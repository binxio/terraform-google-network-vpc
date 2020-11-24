locals {
  owner       = "myself"
  project     = "demo"
  environment = "dev"

  network_name = "example-vpc"

  subnets = {
    "k8nodes" = {
      region        = var.location
      ip_cidr_range = "10.9.0.0/29"
    }
    "vms" = {
      region        = var.location
      ip_cidr_range = "10.10.0.0/24"
      log_config = {
        flow_sampling        = 1.0
        aggregation_interval = "INTERVAL_5_MIN"
      }
      roles = {
        "roles/compute.networkUser" = {
          format("%s", var.sa_user_email) = "serviceAccount"
        }
      }
    }
  }
  routes = {
    "gdns" = {
      dest_range       = "8.8.8.8/32"
      next_hop_gateway = "default-internet-gateway"
      tags             = ["gdns"]
    }
  }

  service_networking_connection = {
    "google-managed-services-cloudsql" = {
      private_ip_address = {
        purpose       = "VPC_PEERING"
        prefix_length = "24"
        address_type  = "INTERNAL"
      }
    }
  }
}

module "vpc" {
  source  = "binxio/network-vpc/google"
  version = "~> 1.0.0"

  owner       = local.owner
  project     = local.project
  environment = local.environment

  network_name                  = local.network_name
  subnets                       = local.subnets
  routes                        = local.routes
  service_networking_connection = local.service_networking_connection
}
