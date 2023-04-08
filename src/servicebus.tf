# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/servicebus_namespace.html
resource "azurerm_servicebus_namespace" "servicebus" {
  name                = "dapr-container-apps-service-bus-broker"
  location            = azurerm_resource_group.environment.location
  resource_group_name = azurerm_resource_group.environment.name
  sku                 = "Basic"
}