# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.50.0"
    }
  }
  backend "azurerm" {
    resource_group_name  = "terraform-rg"
    storage_account_name = "tfstorageaccount12345"
    container_name       = "tfstate"
    key                  = "container_apps_env.tfstate"
  }

  required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {}
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group
resource "azurerm_resource_group" "environment" {
  name     = "dapr-container-apps-environment"
  location = "South Africa North"
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network
resource "azurerm_virtual_network" "vnet" {
  name                = "dapr-container-apps-vnet"
  location            = azurerm_resource_group.environment.location
  resource_group_name = azurerm_resource_group.environment.name
  address_space       = ["10.0.0.0/16"]

  subnet {
    name           = "dapr-container-apps-subnet"
    address_prefix = "10.0.0.0/21"
  }
}