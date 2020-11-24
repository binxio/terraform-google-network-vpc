locals {
  owner       = "myself"
  project     = "testapp"
  environment = var.environment

  network_name = "testvpc"
  subnets = {
    "k8nodes" = {
      ip_cidr_range = "10.7.8.0/24"
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
}

output "map" {
  value = module.vpc.map
}

output "vpc" {
  value = module.vpc.vpc
}

