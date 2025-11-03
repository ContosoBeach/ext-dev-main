# Calculate the CIDR for the subnets
locals {
  subnets = {
    for key, value in local.locations : key => {
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

  locations = {
    (var.primary_region) = {
      vnet_name       = "vnet-demoapp-${var.primary_region}"
      address_space   = var.primary_address_space
      asp_name        = "asp-demoapp-${var.primary_region}"
      webapp_name     = "demoapp-${var.primary_region}"
      apiapp_name     = "apiapp-${var.primary_region}"
      sql_server_name = "sqlserver-demoapp-${var.primary_region}"
    },
    (var.secondary_region) = {
      vnet_name       = "vnet-demoapp-${var.secondary_region}"
      address_space   = var.secondary_address_space
      asp_name        = "asp-demoapp-${var.secondary_region}"
      webapp_name     = "demoapp-${var.secondary_region}"
      apiapp_name     = "apiapp-${var.secondary_region}"
      sql_server_name = "sqlserver-demoapp-${var.secondary_region}"
    }
  }
}
