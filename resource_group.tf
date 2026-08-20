resource "azurerm_resource_group" "this" {
  count = var.resource_group.create ? 1 : 0

  name     = var.resource_group.name
  location = var.resource_group.location
  tags     = var.tags
}

data "azurerm_resource_group" "existing" {
  count = var.resource_group.create ? 0 : 1

  name = var.resource_group.name
}
