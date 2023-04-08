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

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/container_registry
resource "azurerm_container_registry" "registry" {
  name                = "daprcontainerappsregistry12345"
  resource_group_name = azurerm_resource_group.environment.name
  location            = azurerm_resource_group.environment.location
  sku                 = "Basic"
  admin_enabled       = true
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/servicebus_namespace.html
resource "azurerm_servicebus_namespace" "servicebus" {
  name                = "dapr-container-apps-service-bus-broker"
  location            = azurerm_resource_group.environment.location
  resource_group_name = azurerm_resource_group.environment.name
  sku                 = "Basic"
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/cosmosdb_account
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

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/cosmosdb_sql_database
resource "azurerm_cosmosdb_sql_database" "cosmosdbsqldb" {
  name                = "dapr-container-apps-cosmos-sql-db"
  resource_group_name = azurerm_resource_group.environment.name
  account_name        = azurerm_cosmosdb_account.cosmosdb.name
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/cosmosdb_sql_container
resource "azurerm_cosmosdb_sql_container" "cosmosdbsqlcontainer" {
  name                = "dapr-container-apps-cosmos-sql-db-container"
  resource_group_name = azurerm_resource_group.environment.name
  account_name        = azurerm_cosmosdb_account.cosmosdb.name
  database_name       = azurerm_cosmosdb_sql_database.cosmosdbsqldb.name
  partition_key_path  = "/definition/id"
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/log_analytics_workspace
resource "azurerm_log_analytics_workspace" "loganalytics" {
  name                = "dapr-container-apps-la-workspace"
  location            = azurerm_resource_group.environment.location
  resource_group_name = azurerm_resource_group.environment.name
  sku                 = "PerGB2018"
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/container_app_environment
resource "azurerm_container_app_environment" "containerappenv" {
  name                       = "dapr-container-apps-environment"
  location                   = azurerm_resource_group.environment.location
  resource_group_name        = azurerm_resource_group.environment.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.loganalytics.id
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/container_app_environment_dapr_component
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

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/container_app_environment_dapr_component
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

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/container_app
resource "azurerm_container_app" "daprdemoorderapi" {
  name                         = "dapr-demo-order-api"
  container_app_environment_id = azurerm_container_app_environment.containerappenv.id
  resource_group_name          = azurerm_resource_group.environment.name
  revision_mode                = "Single"
  template {
    container {
      name   = "dapr-demo-order-api"
      image  = "daprcontainerappsregistry12345.azurecr.io/dapr-demo/order-api:latest"
      cpu    = 0.5
      memory = "1Gi"
    }
  }
  dapr {
    app_id       = "orderapi"
    app_port     = 5000
    app_protocol = "http"
  }
  # https://github.com/hashicorp/terraform-provider-azurerm/issues/20435#issuecomment-1443418097
  ingress {
    target_port      = 5000
    external_enabled = true
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
  registry {
    server               = azurerm_container_registry.registry.login_server
    username             = azurerm_container_registry.registry.admin_username
    password_secret_name = "registry-password"
  }
  secret {
    name  = "registry-password"
    value = azurerm_container_registry.registry.admin_password
  }
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/container_app
resource "azurerm_container_app" "daprdemogarbagecollector" {
  name                         = "dapr-demo-garbage-collector"
  container_app_environment_id = azurerm_container_app_environment.containerappenv.id
  resource_group_name          = azurerm_resource_group.environment.name
  revision_mode                = "Single"
  template {
    container {
      name   = "dapr-demo-garbage-collector"
      image  = "daprcontainerappsregistry12345.azurecr.io/dapr-demo/garbage-collector:latest"
      cpu    = 0.5
      memory = "1Gi"
    }
  }
  dapr {
    app_id       = "garbagecollector"
    app_port     = 5000
    app_protocol = "http"
  }
  # https://github.com/hashicorp/terraform-provider-azurerm/issues/20435#issuecomment-1443418097
  ingress {
    target_port      = 5000
    external_enabled = true
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
  registry {
    server               = azurerm_container_registry.registry.login_server
    username             = azurerm_container_registry.registry.admin_username
    password_secret_name = "registry-password"
  }
  secret {
    name  = "registry-password"
    value = azurerm_container_registry.registry.admin_password
  }
}