module "virtual_network" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "0.14.1"

  for_each      = var.locations
  parent_id     = module.resource_group.resource_id
  subnets       = local.subnets
  address_space = [each.value.address_space]
  location      = each.key
  name          = each.value.vnet_name
}
