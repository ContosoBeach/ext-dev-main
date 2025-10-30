# Calculate the CIDR for the subnets
locals {
  subnets = { for key, value in var.subnets : key => {
    name             = key
    address_prefixes = [module.avm-utl-network-ip-addresses.address_prefixes[key]]
    delegations = value.delegation != null ? [
      {
        name = "delegation-${key}"
        service_delegation = {
          name = value.delegation
        }
      }
    ] : []
    }
  }
}
