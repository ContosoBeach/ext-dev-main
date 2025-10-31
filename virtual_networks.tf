module "virtual_network" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "0.14.1"

  for_each      = local.locations
  parent_id     = module.resource_group[each.key].resource_id
  subnets       = local.subnets[each.key]
  address_space = [each.value.address_space]
  location      = each.key
  name          = each.value.vnet_name
}
