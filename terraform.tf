terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.7"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
  }
  required_version = "~> 1.13"
  # backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

provider "azuread" {
  # Configuration options
}
