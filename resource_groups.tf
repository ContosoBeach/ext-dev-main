resource "random_pet" "resource_group_name" {
  length    = 2
  separator = "-"
  prefix    = "rg"
}

# The resource group
module "resource_group" {
  source   = "Azure/avm-res-resources-resourcegroup/azurerm"
  version  = "0.2.1"
  for_each = var.locations
  location = each.key
  name     = "${random_pet.resource_group_name.id}-${each.key}"
}
