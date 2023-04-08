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

resource "azurerm_resource_group" "environment" {
  name     = "dapr-container-apps-environment"
  location = "South Africa North"
}

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

resource "azurerm_container_registry" "registry" {
  name                = "daprcontainerappsregistry12345"
  resource_group_name = azurerm_resource_group.environment.name
  location            = azurerm_resource_group.environment.location
  sku                 = "Basic"
  admin_enabled       = true
}

resource "azurerm_servicebus_namespace" "servicebus" {
  name                = "dapr-container-apps-service-bus-broker"
  location            = azurerm_resource_group.environment.location
  resource_group_name = azurerm_resource_group.environment.name
  sku                 = "Basic"
}

resource "azurerm_cosmosdb_account" "cosmosdb" {
  name                      = "dapr-container-apps-cosmos-db"
  location                  = azurerm_resource_group.environment.location
  resource_group_name       = azurerm_resource_group.environment.name
  offer_type                = "Standard"
  kind                      = "GlobalDocumentDB"
  enable_free_tier          = true
  enable_automatic_failover = false
  consistency_policy {
    consistency_level = "BoundedStaleness"
  }
  geo_location {
    location          = azurerm_resource_group.environment.location
    failover_priority = 0
    zone_redundant    = false
  }
  capabilities {
    name = "EnableServerless"
  }
}

resource "azurerm_cosmosdb_sql_database" "cosmosdbsqldb" {
  name                = "dapr-container-apps-cosmos-sql-db"
  resource_group_name = azurerm_resource_group.environment.name
  account_name        = azurerm_cosmosdb_account.cosmosdb.name
}

resource "azurerm_cosmosdb_sql_container" "cosmosdbsqlcontainer" {
  name                = "dapr-container-apps-cosmos-sql-db-container"
  resource_group_name = azurerm_resource_group.environment.name
  account_name        = azurerm_cosmosdb_account.cosmosdb.name
  database_name       = azurerm_cosmosdb_sql_database.cosmosdbsqldb.name
  partition_key_path  = "/definition/id"
}

resource "azurerm_log_analytics_workspace" "loganalytics" {
  name                = "dapr-container-apps-la-workspace"
  location            = azurerm_resource_group.environment.location
  resource_group_name = azurerm_resource_group.environment.name
  sku                 = "PerGB2018"
}

resource "azurerm_container_app_environment" "containerappenv" {
  name                       = "dapr-container-apps-environment"
  location                   = azurerm_resource_group.environment.location
  resource_group_name        = azurerm_resource_group.environment.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.loganalytics.id
}

resource "azurerm_container_app_environment_dapr_component" "daprpubsubcomponent" {
  name                         = "pubsub"
  container_app_environment_id = azurerm_container_app_environment.containerappenv.id
  component_type               = "pubsub.azure.servicebus.queues"
  version                      = "v1"
  metadata {
    name  = "connectionString"
    value = azurerm_servicebus_namespace.servicebus.default_primary_connection_string
  }
}

resource "azurerm_container_app_environment_dapr_component" "daprstatestorecomponent" {
  name                         = "statestore"
  container_app_environment_id = azurerm_container_app_environment.containerappenv.id
  component_type               = "state.azure.cosmosdb"
  version                      = "v1"
  metadata {
    name  = "url"
    value = azurerm_cosmosdb_account.cosmosdb.endpoint
  }
  metadata {
    name  = "masterKey"
    value = azurerm_cosmosdb_account.cosmosdb.primary_key
  }
  metadata {
    name  = "database"
    value = azurerm_cosmosdb_sql_database.cosmosdbsqldb.name
  }
  metadata {
    name  = "collection"
    value = azurerm_cosmosdb_sql_container.cosmosdbsqlcontainer.name
  }
  metadata {
    name  = "actorStateStore"
    value = true
  }
}

resource "azurerm_container_app" "daprdemoorderapi" {
  name                         = "dapr-demo-order-api"
  container_app_environment_id = azurerm_container_app_environment.containerappenv.id
  resource_group_name          = azurerm_resource_group.environment.name
  revision_mode                = "Single"
  template {
    container {
      name   = "dapr-demo-order-api"
      image  = "dapr-demo/order-api:latest"
      cpu    = 0.5
      memory = "1Gi"
    }
  }
  dapr {
    app_id       = "orderapi"
    app_port     = 5000
    app_protocol = "http"
  }
  ingress {
    target_port      = 5000
    external_enabled = true
    traffic_weight {
      percentage = 100
    }
  }
}