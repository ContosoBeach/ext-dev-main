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

module "vnet_peering" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm//modules/peering"
  version = "0.14.1"

  parent_id                 = module.virtual_network[var.primary_region].resource_id
  remote_virtual_network_id = module.virtual_network[var.secondary_region].resource_id
  name                      = "${var.primary_region}-to-${var.secondary_region}"
  create_reverse_peering    = true
  reverse_name              = "${var.secondary_region}-to-${var.primary_region}"
}
