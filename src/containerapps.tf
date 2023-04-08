

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