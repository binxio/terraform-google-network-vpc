output "vpc" {
  description = "The generated VPC network url"
  value       = google_compute_network.vpc.self_link
}
output "vpc_id" {
  description = "The generated VPC network id"
  value       = google_compute_network.vpc.id
}

output "subnet_defaults" {
  description = "The generic defaults used for subnet settings"
  value       = local.subnet_defaults
}
output "vpc_peer_defaults" {
  description = "The generic defaults used for subnet settings"
  value       = local.vpc_peer_defaults
}
output "route_defaults" {
  description = "The generic defaults used for subnet settings"
  value       = local.module_route_defaults
}

output "map" {
  description = "outputs for all google_compute_subnetwork created"
  value       = google_compute_subnetwork.map
}

output "compute_global_addresses" {
  description = "Compute global addresses created for service networking connections"
  value       = google_compute_global_address.map
}
