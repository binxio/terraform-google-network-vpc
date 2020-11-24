output "subnets" {
  value = module.vpc.map
}

output "vpc_id" {
  value = module.vpc.vpc_id
}
output "vpc" {
  value = module.vpc.vpc
}
