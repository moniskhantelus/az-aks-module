resource "azurerm_monitor_diagnostic_setting" "this" {
  count = local.log_analytics_workspace_id == null && local.audit_archive_storage_id == null ? 0 : 1

  name                           = local.diagnostic_setting_name
  target_resource_id             = azurerm_kubernetes_cluster.this.id
  log_analytics_workspace_id     = local.log_analytics_workspace_id
  storage_account_id             = local.audit_archive_storage_id
  log_analytics_destination_type = "Dedicated"

  dynamic "enabled_log" {
    for_each = var.diagnostic_log_categories

    content {
      category = enabled_log.value
    }
  }

  enabled_metric {
    category = "AllMetrics"
  }
}
