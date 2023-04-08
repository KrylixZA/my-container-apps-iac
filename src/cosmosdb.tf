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