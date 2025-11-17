module "private_dns_zone_appservice" {
  source  = "Azure/avm-res-network-privatednszone/azurerm"
  version = "0.4.2"

  parent_id   = module.resource_group[var.primary_region].resource_id
  domain_name = "privatelink.azurewebsites.net"

  virtual_network_links = {
    vnetlink1 = {
      vnetlinkname = "app-service-dnslink-${var.primary_region}"
      vnetid       = module.virtual_network[var.primary_region].resource_id
    }
    vnetlink2 = {
      vnetlinkname = "app-service-dnslink-${var.secondary_region}"
      vnetid       = module.virtual_network[var.secondary_region].resource_id
    }
  }
}

module "app_service_plan" {
  source  = "Azure/avm-res-web-serverfarm/azurerm"
  version = "1.0.0"

  for_each                        = local.locations
  location                        = each.key
  name                            = each.value.asp_name
  os_type                         = "Linux"
  resource_group_name             = module.resource_group[each.key].name
  sku_name                        = "P1v3"
  premium_plan_auto_scale_enabled = true
  #   zone_balancing_enabled          = each.key == var.primary_region ? true : false
  zone_balancing_enabled = false
}

module "web_app_service" {
  source  = "Azure/avm-res-web-site/azurerm"
  version = "0.19.1"

  for_each                 = local.locations
  name                     = each.value.webapp_name
  kind                     = "webapp"
  location                 = each.key
  resource_group_name      = module.resource_group[each.key].name
  service_plan_resource_id = module.app_service_plan[each.key].resource_id
  os_type                  = "Linux"
  https_only               = true
  site_config = {
    linux_fx_version    = "DOTNETCORE|9.0"
    minTlsVersion       = "1.2"
    ftpsState           = "FtpsOnly"
    vnetRouteAllEnabled = true
    alwaysOn            = true
  }

  managed_identities = {
    system_assigned = true
  }
  virtual_network_subnet_id = module.virtual_network[each.key].subnets["snet-webapp"].resource_id
}

module "api_app_service" {
  source  = "Azure/avm-res-web-site/azurerm"
  version = "0.19.1"

  for_each                 = local.locations
  name                     = each.value.apiapp_name
  kind                     = "webapp"
  location                 = each.key
  resource_group_name      = module.resource_group[each.key].name
  service_plan_resource_id = module.app_service_plan[each.key].resource_id
  os_type                  = "Linux"
  https_only               = true
  site_config = {
    linux_fx_version    = "DOTNETCORE|9.0"
    minTlsVersion       = "1.2"
    ftpsState           = "FtpsOnly"
    vnetRouteAllEnabled = true
    alwaysOn            = true
  }

  managed_identities = {
    system_assigned = true
  }
  virtual_network_subnet_id = module.virtual_network[each.key].subnets["snet-apiapp"].resource_id

  private_endpoints = {
    primary = {
      private_dns_zone_resource_ids = [module.private_dns_zone_appservice.resource_id]
      subnet_resource_id            = module.virtual_network[each.key].subnets["snet-pe"].resource_id
    }
  }

  connection_strings = {
    sqldb_connection = {
      name  = "SampleApiContext"
      type  = "SQLAzure"
      value = "Server=tcp:${module.sql-server[each.key].resource_name}.database.windows.net,1433;Initial Catalog=${module.main_database.name};Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;Authentication=\"Active Directory Default\";"
    }
  }

  auth_settings_v2 = {
    setting1 = {
      auth_enabled     = true
      default_provider = "AzureActiveDirectory"
      active_directory_v2 = {
        aad1 = {
          client_id            = "<client-id>"
          tenant_auth_endpoint = "https://login.microsoftonline.com/${data.azurerm_client_config.current.tenant_id}/v2.0/"
        }
      }
      login = {
        login1 = {
          token_store_enabled = true
        }
      }
    }
  }
}

# resource symbolicname 'Microsoft.Web/sites/config@2022-03-01' = if(useAuth) {
#   name: 'authsettingsV2'
#   parent: webApp
#   properties: {
#     identityProviders: {
#       azureActiveDirectory: {
#         enabled: true
#         registration: {
#           clientId: authClientId
#           clientSecretSettingName: clientSecretKey
#           openIdIssuer: 'https://sts.windows.net/${tenant().tenantId}/v2.0'
#         }
#         validation: {
#           allowedAudiences: [
#             'api://${authClientId}'
#           ]
#         }
#       }
#     }
#     globalValidation: {
#       redirectToProvider: 'AzureActiveDirectory'
#       unauthenticatedClientAction: isApi ? 'Return401' : 'RedirectToLoginPage'

#     } 
#     login: {
#       tokenStore: {
#         enabled: true
#       }
#     }
#   }
# }

