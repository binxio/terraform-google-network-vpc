locals {
  owner       = "myself"
  project     = "demo"
  environment = "dev"

  network_name = "examplevpc"
  subnets = {
    "k8nodes" = {
      ip_cidr_range = "10.7.8.0/24"
    }
  }
}

module "vpc" {
  source  = "binxio/network-vpc/google"
  version = "~> 1.0.0"

  owner       = local.owner
  project     = local.project
  environment = local.environment

  network_name = local.network_name
  subnets      = local.subnets
}
