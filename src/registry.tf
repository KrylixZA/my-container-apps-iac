# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/container_registry
resource "azurerm_container_registry" "registry" {
  name                = "daprcontainerappsregistry12345"
  resource_group_name = azurerm_resource_group.environment.name
  location            = azurerm_resource_group.environment.location
  sku                 = "Basic"
  admin_enabled       = true
}