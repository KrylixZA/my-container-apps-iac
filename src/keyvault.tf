# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault
resource "azurerm_key_vault" "keyvault" {
  name                        = "dapr-container-apps-vault"
  location                    = azurerm_resource_group.environment.location
  resource_group_name         = azurerm_resource_group.environment.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false
  sku_name                    = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "Get",
      "List",
      "Update",
      "Create",
      "Import",
      "Delete",
      "Recover",
      "Backup",
      "Restore"
    ]

    secret_permissions = [
      "Get",
      "List",
      "Set",
      "Delete",
      "Recover",
      "Backup",
      "Restore"
    ]

    storage_permissions = [
      "Get"
    ]
  }
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_secret
resource "azurerm_key_vault_secret" "registrypasswordsecret" {
  name         = "registry-password"
  value        = azurerm_container_registry.registry.admin_password
  key_vault_id = azurerm_key_vault.keyvault.id
}