resource "random_password" "admin_password" {
  length           = 16
  override_special = "!#$%&*()-_=+[]{}<>:?"
  special          = true
}

module "private_dns_zone_sql" {
  source  = "Azure/avm-res-network-privatednszone/azurerm"
  version = "0.4.2"

  parent_id   = module.resource_group["southcentralus"].resource_id
  domain_name = "privatelink.database.windows.net"

  virtual_network_links = {
    vnetlink1 = {
      vnetlinkname = "sql-server-dnslink"
      vnetid       = module.virtual_network["southcentralus"].resource_id
    }
    vnetlink2 = {
      vnetlinkname = "sql-server-dnslink"
      vnetid       = module.virtual_network["northcentralus"].resource_id
    }
  }
}

module "sql-server" {
  source  = "Azure/avm-res-sql-server/azurerm"
  version = "0.1.6"

  for_each                     = var.locations
  name                         = each.value.sql_server_name
  location                     = each.key
  resource_group_name          = module.resource_group[each.key].name
  server_version               = "12.0"
  administrator_login          = "sqladmin"
  administrator_login_password = random_password.admin_password.result


  private_endpoints = {
    primary = {
      private_dns_zone_resource_id = module.private_dns_zone_sql.resource_id
      subnet_resource_id           = module.virtual_network[each.key].subnets["snet-pe"].resource_id
      subresource_name             = "sqlServer"
    }
  }
}

module "main_database" {
  source  = "Azure/avm-res-sql-server/azurerm//modules/database"
  version = "0.1.6"

  name = "maindb"
  sql_server = {
    resource_id = module.sql-server["southcentralus"].resource_id
  }
  sku_name           = "S0"
  license_type       = "LicenseIncluded"
  max_size_gb        = 10
  read_scale         = false
  zone_redundant     = true
  geo_backup_enabled = false
  short_term_retention_policy = {
    retention_days           = 1
    backup_interval_in_hours = 24
  }
  long_term_retention_policy = null
}

resource "azurerm_mssql_failover_group" "db_failover_group" {
  name      = "maindb-failover-group"
  server_id = module.sql-server["southcentralus"].resource_id
  databases = [
    module.main_database.resource_id
  ]

  partner_server {
    id = module.sql-server["northcentralus"].resource_id
  }

  read_write_endpoint_failover_policy {
    mode          = "Automatic"
    grace_minutes = 80
  }

}
