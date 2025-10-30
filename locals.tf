# Calculate the CIDR for the subnets
locals {
  subnets = {
    for key, value in var.locations : key => {
      for key1, value1 in var.subnets : key1 => {
        name             = key1
        address_prefixes = [module.avm-utl-network-ip-addresses[key].address_prefixes[key1]]
        delegations = value1.delegation != null ? [
          {
            name = "delegation-${key1}"
            service_delegation = {
              name = value1.delegation
            }
          }
        ] : []
      }
    }
  }
}
