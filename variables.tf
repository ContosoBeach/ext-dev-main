variable "primary_region" {
  description = "The primary region for the deployment."
  type        = string
  default     = "uksouth"
}

variable "secondary_region" {
  description = "The secondary region for the deployment."
  type        = string
  default     = "ukwest"
}

variable "primary_address_space" {
  description = "The address space for the primary region."
  type        = string
  default     = "10.0.0.0/16"
}

variable "secondary_address_space" {
  description = "The address space for the secondary region."
  type        = string
  default     = "10.1.0.0/16"
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
    },
    "AzureBastionSubnet" = {
      size = 24
    }
  }
  description = "The subnets"
}

variable "frontdoor_prefix" {
  description = "Prefix for Front Door resources"
  type        = string
  default     = "fdemo"
}

variable "api_app_primary_auth_client_id" {
  description = "The client ID for the API App registration in the primary region."
  type        = string
}

variable "web_app_primary_auth_client_id" {
  description = "The client ID for the Web App registration in the primary region."
  type        = string
}

variable "api_app_secondary_auth_client_id" {
  description = "The client ID for the API App registration in the secondary region."
  type        = string
}
variable "web_app_secondary_auth_client_id" {
  description = "The client ID for the Web App registration in the secondary region."
  type        = string
}
