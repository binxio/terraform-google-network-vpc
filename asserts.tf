#######################################################################################################
#
# Terraform does not have a easy way to check if the input parameters are in the correct format.
# On top of that, terraform will sometimes produce a valid plan but then fail during apply.
# To handle these errors beforehad, we're using the 'file' hack to throw errors on known mistakes.
#
#######################################################################################################
locals {
  # Regular expressions
  regex_network_name   = "[a-z]([-a-z0-9]{0,61}[a-z0-9])?" # See https://www.terraform.io/docs/providers/google/r/compute_network.html
  regex_subnet_name    = "[a-z]([-a-z0-9]{0,61}[a-z0-9])?" # See https://www.terraform.io/docs/providers/google/r/compute_subnetwork.html
  regex_subnet_purpose = "(PRIVATE|INTERNAL_HTTPS_LOAD_BALANCER)"
  regex_subnet_role    = "(ACTIVE|BACKUP)"

  # Terraform assertion hack
  assert_head = "\n\n-------------------------- /!\\ ASSERTION FAILED /!\\ --------------------------\n\n"
  assert_foot = "\n\n-------------------------- /!\\ ^^^^^^^^^^^^^^^^ /!\\ --------------------------\n"

  asserts_global = {
    assert_network_regex = can(regex("^${local.regex_network_name}$", var.network_name)) ? "ok" : file(format("%sNetwork name %s does not match regex:%s\n%s", local.assert_head, var.network_name, local.regex_network_name, local.assert_foot))
  }

  assert_subnets = {
    for subnet, settings in local.subnets : subnet => merge({
      name_too_long = length(settings.subnet_name) > 63 ? file(format("%ssubnet [%s]'s generated name is too long:\n%s\n%s > 63 chars!%s", local.assert_head, subnet, settings.subnet_name, length(settings.subnet_name), local.assert_foot)) : "ok"
      name_regex    = can(regex("^${local.regex_subnet_name}$", settings.subnet_name)) ? "ok" : file(format("%ssubnet [%s]'s generated name [%s] does not match regex ^%s$%s", local.assert_head, subnet, settings.subnet_name, local.regex_subnet_name, local.assert_foot))

      # https://cloud.google.com/vpc/docs/vpc#vpc_networks_and_subnets - Every subnet has four reserved IP addresses in its primary IP range.
      # https://cloud.google.com/vpc/docs/using-vpc - The minimum primary or secondary range size is eight IP addresses. In other words, the longest subnet mask you can use is /29.
      # We check this by using the cidrsubnet function to see if we can have the minimum required /32 addresses in the given subnet (7 for /29, 63 for /26)
      valid_cidr       = can(cidrsubnet(settings.ip_cidr_range, 3, 7)) ? "ok" : file(format("%ssubnet [%s]'s IP CIDR block [%s] is too small or invalid, minimum is /29!%s", local.assert_head, subnet, settings.ip_cidr_range, local.assert_foot))
      valid_proxy_cidr = settings.purpose != "INTERNAL_HTTPS_LOAD_BALANCING" || can(cidrsubnet(settings.ip_cidr_range, 6, 63)) ? "ok" : file(format("%ssubnet [%s]'s IP CIDR block [%s] is too small or invalid, minimum is /26 for subnets with purpose INTERNAL_HTTPS_LOAD_BALANCING!%s", local.assert_head, subnet, settings.ip_cidr_range, local.assert_foot))

      valid_purpose = settings.purpose != null ? (
        settings.role == null && settings.purpose == "INTERNAL_HTTPS_LOAD_BALANCING" ? file(format("%ssubnet [%s] has purpose [%s] defined without the 'role' setting being provided. Don't know what to do now!%s", local.assert_head, subnet, settings.purpose, local.assert_foot)) : (
          can(regex("^${local.regex_subnet_purpose}$", settings.purpose)) ? "ok" : file(format("%ssubnet [%s]'s purpose [%s] does not match valid values: %s%s", local.assert_head, subnet, settings.purpose, local.regex_subnet_purpose, local.assert_foot))
        )
      ) : "ok"

      valid_role = settings.role != null ? (
        settings.purpose == "PRIVATE" ? file(format("%ssubnet [%s] has role [%s] defined while the 'purpose' setting is [PRIVATE]. Don't know what to do now!%s", local.assert_head, subnet, settings.role, local.assert_foot)) : (
          can(regex("^${local.regex_subnet_role}$", settings.role)) ? "ok" : file(format("%ssubnet [%s]'s role [%s] does not match valid values: %s%s", local.assert_head, subnet, settings.role, local.regex_subnet_role, local.assert_foot))
        )
      ) : "ok"

      keytest = {
        for setting in keys(settings) : setting => merge(
          {
            keytest = can(local.subnet_defaults[setting]) ? "ok" : file(format("%sUnknown subnet variable assigned - subnet [%s] defines [%q] -- Please check for typos etc!%s", local.assert_head, subnet, setting, local.assert_foot))
        }) if setting != "subnet_name"
      }
    })
  }
  assert_routes = {
    for route, settings in local.routes : route => merge({
      name_too_long = length(settings.route_name) > 63 ? file(format("%sroute [%s]'s generated name is too long:\n%s\n%s > 63 chars!%s", local.assert_head, route, settings.route_name, length(settings.route_name), local.assert_foot)) : "ok"
      # Make sure ONE of the next_hop_X settings are filled out
      # hopvalues = [settings.next_hop_gateway, settings.next_hop_instance, settings.next_hop_vpn_tunnel, settings.next_hop_ip, settings.next_hop_ilb] # this won't work, we can't reference it :/
      hoptest   = length(compact([settings.next_hop_gateway, settings.next_hop_instance, settings.next_hop_vpn_tunnel, settings.next_hop_ip, settings.next_hop_ilb])) == 1 ? "ok" : file(format("%sRoute [%s] has %s next hop values defined - Please supply ONE nexthop!%s", local.assert_head, route, length(compact([settings.next_hop_gateway, settings.next_hop_instance, settings.next_hop_vpn_tunnel, settings.next_hop_ip, settings.next_hop_ilb])), local.assert_foot))
      tunnelhop = try(settings.next_hop_vpn_tunnel, null) == null || can(regex("/vpnTunnels/", settings.next_hop_vpn_tunnel)) ? "ok" : file(format("%sRoute [%s]'s tunnel next hop [%s] does not look like a VPN tunnel to me - make sure you are referencing the target TUNNEL and not the Gateway or some other resource!%s", local.assert_head, route, settings.next_hop_vpn_tunnel, local.assert_foot))
      keytest = {
        for setting in keys(settings) : setting => merge(
          {
            keytest = can(local.route_defaults[setting]) ? "ok" : file(format("%sUnknown route variable assigned - route [%s] defines [%q] -- Please check for typos etc!%s", local.assert_head, route, setting, local.assert_foot))
        }) if setting != "route_name"
      }
    })
  }
}
