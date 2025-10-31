module "azure_bastion" {
  source  = "Azure/avm-res-network-bastionhost/azurerm//examples/Basic-sku"
  version = "0.8.1"

  location            = var.primary_region
  name                = "bastion-host-${var.primary_region}"
  resource_group_name = module.resource_group[var.primary_region].name

  ip_configuration = {
    name                   = "bastion-ipconfig"
    subnet_id              = module.virtual_network[var.primary_region].subnets["AzureBastionSubnet"].resource_id
    create_public_ip       = true
    public_ip_address_name = "bastion-pip-${var.primary_region}"
  }
  sku = "Basic"
}

data "azurerm_client_config" "current" {}

module "keyvault" {
  source  = "Azure/avm-res-keyvault-vault/azurerm"
  version = "=0.10.2"

  location            = var.primary_region
  name                = "kv-${random_pet.resource_group_name.id}-${var.primary_region}"
  resource_group_name = module.resource_group[var.primary_region].name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  network_acls = {
    default_action = "Allow"
  }
  #   role_assignments = {
  #     deployment_user_secrets = {
  #       role_definition_id_or_name = "Key Vault Secrets Officer"
  #       principal_id               = data.azurerm_client_config.current.object_id
  #     }
  #   }
  #   wait_for_rbac_before_secret_operations = {
  #     create = "60s"
  #   }
}

module "mgmtvm" {
  source  = "Azure/avm-res-compute-virtualmachine/azurerm"
  version = "0.19.3"

  location = var.primary_region
  name     = "mgmtvm-${var.primary_region}"
  network_interfaces = {
    network_interface_1 = {
      name = "mgmtvm-nic-${var.primary_region}"
      ip_configurations = {
        ip_configuration_1 = {
          name                          = "mgmtvm-nic-ipconfig1"
          private_ip_subnet_resource_id = module.virtual_network[var.primary_region].subnets["snet-mgmt"].resource_id
        }
      }
    }
  }
  resource_group_name = module.resource_group[var.primary_region].name
  zone                = null
  account_credentials = {
    key_vault_configuration = {
      resource_id = module.keyvault.resource_id
    }
  }
  os_type  = "Linux"
  sku_size = "Standard_B2as_v2"
  source_image_reference = {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
}
