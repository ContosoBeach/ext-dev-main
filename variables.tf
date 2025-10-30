variable "locations" {
  description = "The list of Azure locations to deploy resources in."
  type = map(object({
    vnet_name       = string,
    address_space   = string,
    asp_name        = string,
    app_name        = string,
    sql_server_name = string
  }))
  default = {
    "southcentralus" = {
      vnet_name       = "vnet-demoapp-southcentralus"
      address_space   = "10.0.0.0/16"
      asp_name        = "asp-demoapp-southcentralus"
      app_name        = "demoapp-southcentralus"
      sql_server_name = "sqlserver-demoapp-southcentralus"
    },
    "northcentralus" = {
      vnet_name       = "vnet-demoapp-northcentralus"
      address_space   = "10.1.0.0/16"
      asp_name        = "asp-demoapp-northcentralus"
      app_name        = "demoapp-northcentralus"
      sql_server_name = "sqlserver-demoapp-northcentralus"
    }
  }
}

variable "subnets" {
  type = map(object({
    size       = number
    delegation = optional(string)
  }))
  default = {
    "snet-webapp" = {
      size       = 24
      delegation = "Microsoft.Web/serverFarms"
    },
    "snet-apiapp" = {
      size       = 24
      delegation = "Microsoft.Web/serverFarms"
    },
    "snet-pe" = {
      size = 24
    },
    "snet-management" = {
      size = 24
    }
  }
  description = "The subnets"
}


