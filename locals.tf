locals {
  is_production = var.naming.environment == "prod"
  required_production_audit_categories = toset([
    "kube-audit",
    "kube-audit-admin"
  ])
  cluster_name = "${var.naming.platform}-${var.naming.maintain_org}-${var.naming.environment}-${var.naming.region_code}-aks"
  resource_group_name = var.resource_group.create ? (
    azurerm_resource_group.this[0].name
  ) : data.azurerm_resource_group.existing[0].name

  location = var.resource_group.create ? (
    azurerm_resource_group.this[0].location
  ) : data.azurerm_resource_group.existing[0].location

  node_resource_group_name = substr("MC_${local.resource_group_name}_${local.cluster_name}_${local.location}", 0, 80)

  control_plane_identity_name = "${var.naming.platform}-${var.naming.maintain_org}-${var.naming.environment}-controlplane-${var.naming.region_code}-mi"
  kubelet_identity_name       = "${var.naming.platform}-${var.naming.maintain_org}-${var.naming.environment}-kubelet-${var.naming.region_code}-mi"

  control_plane_identity_id           = var.managed_identities.create ? azurerm_user_assigned_identity.control_plane[0].id : data.azurerm_user_assigned_identity.control_plane[0].id
  control_plane_identity_client_id    = var.managed_identities.create ? azurerm_user_assigned_identity.control_plane[0].client_id : data.azurerm_user_assigned_identity.control_plane[0].client_id
  control_plane_identity_principal_id = var.managed_identities.create ? azurerm_user_assigned_identity.control_plane[0].principal_id : data.azurerm_user_assigned_identity.control_plane[0].principal_id

  kubelet_identity_id           = var.managed_identities.create ? azurerm_user_assigned_identity.kubelet[0].id : data.azurerm_user_assigned_identity.kubelet[0].id
  kubelet_identity_client_id    = var.managed_identities.create ? azurerm_user_assigned_identity.kubelet[0].client_id : data.azurerm_user_assigned_identity.kubelet[0].client_id
  kubelet_identity_principal_id = var.managed_identities.create ? azurerm_user_assigned_identity.kubelet[0].principal_id : data.azurerm_user_assigned_identity.kubelet[0].principal_id

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
  audit_archive_storage_id   = try(var.integrations.audit_archive_storage_account_id, null)
}
