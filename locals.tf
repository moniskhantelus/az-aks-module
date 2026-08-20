locals {
  resource_group_name = var.resource_group.create ? (
    azurerm_resource_group.this[0].name
  ) : data.azurerm_resource_group.existing[0].name
  location = var.resource_group.create ? (
    azurerm_resource_group.this[0].location
  ) : data.azurerm_resource_group.existing[0].location

  node_resource_group_name = substr("nrg-${var.name}", 0, 80)

  system_node_labels = merge(
    {
      "platform.boeing.com/pool"           = "system"
      "platform.boeing.com/workload-class" = "platform"
    },
    var.system_node_pool.node_labels
  )

  log_analytics_workspace_id = try(var.integrations.log_analytics_workspace_id, null)
  acr_id                     = try(var.integrations.acr_id, null)
  defender_workspace_id      = try(var.integrations.defender_log_analytics_id, null)
}
