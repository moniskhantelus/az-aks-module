locals {
  is_production = var.naming.environment == "prod"

  required_production_audit_categories = toset([
    "kube-audit",
    "kube-audit-admin"
  ])

  # Normalized interface. Legacy top-level inputs remain supported while new
  # composition/CAPI consumers can use module_interface as one stable contract.
  effective_tenant_id = var.module_interface == null ? var.tenant_id : var.module_interface.access.tenant_id
  effective_node_subnet_id = var.module_interface == null ? var.node_subnet_id : var.module_interface.network_attachment.node_subnet_id
  effective_kubernetes_version = var.module_interface == null ? var.kubernetes_version : try(var.module_interface.cluster.kubernetes_version, null)
  effective_sku_tier = var.module_interface == null ? var.sku_tier : var.module_interface.cluster.sku_tier
  effective_support_plan = var.module_interface == null ? var.support_plan : var.module_interface.cluster.support_plan
  effective_cluster_profile = var.module_interface == null ? var.cluster_profile : var.module_interface.cluster.profile
  effective_compliance_profile = var.module_interface == null ? var.compliance_profile : var.module_interface.cluster.compliance_profile
  effective_admin_group_object_ids = var.module_interface == null ? var.admin_group_object_ids : var.module_interface.access.admin_group_object_ids
  effective_mandatory_admin_group_object_ids = var.module_interface == null ? var.mandatory_admin_group_object_ids : var.module_interface.access.mandatory_admin_group_object_ids
  effective_azure_rbac_enabled = var.module_interface == null ? var.azure_rbac_enabled : var.module_interface.access.azure_rbac_enabled
  effective_local_account_disabled = var.module_interface == null ? var.local_account_disabled : var.module_interface.access.local_account_disabled

  cluster_name = "${var.naming.platform}-${var.naming.maintain_org}-${var.naming.environment}-${var.naming.region_code}-aks"
  resource_group_name = var.resource_group.create ? azurerm_resource_group.this[0].name : data.azurerm_resource_group.existing[0].name
  location = var.resource_group.create ? azurerm_resource_group.this[0].location : data.azurerm_resource_group.existing[0].location
  node_resource_group_name = substr("MC_${local.resource_group_name}_${local.cluster_name}_${local.location}", 0, 80)

  control_plane_identity_name = "${var.naming.platform}-${var.naming.maintain_org}-${var.naming.environment}-controlplane-${var.naming.region_code}-mi"
  kubelet_identity_name       = "${var.naming.platform}-${var.naming.maintain_org}-${var.naming.environment}-kubelet-${var.naming.region_code}-mi"
  diagnostic_setting_name     = "diag-${local.cluster_name}"
  system_node_pool_name       = "system"

  control_plane_identity_id           = var.managed_identities.create ? azurerm_user_assigned_identity.control_plane[0].id : data.azurerm_user_assigned_identity.control_plane[0].id
  control_plane_identity_client_id    = var.managed_identities.create ? azurerm_user_assigned_identity.control_plane[0].client_id : data.azurerm_user_assigned_identity.control_plane[0].client_id
  control_plane_identity_principal_id = var.managed_identities.create ? azurerm_user_assigned_identity.control_plane[0].principal_id : data.azurerm_user_assigned_identity.control_plane[0].principal_id

  kubelet_identity_id           = var.managed_identities.create ? azurerm_user_assigned_identity.kubelet[0].id : data.azurerm_user_assigned_identity.kubelet[0].id
  kubelet_identity_client_id    = var.managed_identities.create ? azurerm_user_assigned_identity.kubelet[0].client_id : data.azurerm_user_assigned_identity.kubelet[0].client_id
  kubelet_identity_principal_id = var.managed_identities.create ? azurerm_user_assigned_identity.kubelet[0].principal_id : data.azurerm_user_assigned_identity.kubelet[0].principal_id

  system_node_labels = merge({
    "platform.boeing.com/pool"           = "system"
    "platform.boeing.com/workload-class" = "platform"
  }, var.system_node_pool.node_labels)

  log_analytics_workspace_id = try(var.integrations.log_analytics_workspace_id, null)
  acr_id                     = try(var.integrations.acr_id, null)
  defender_workspace_id      = try(var.integrations.defender_log_analytics_id, null)
  audit_archive_storage_id   = try(var.integrations.audit_archive_storage_account_id, null)

  # Story 3: production availability/SLA and OS exception policy.
  production_sla_valid = !local.is_production || (
    local.effective_sku_tier != "Free" &&
    contains(["tier-1", "tier-2", "tier-3"], var.availability_policy.criticality)
  )
  system_os_exception = try(var.availability_policy.node_os_exceptions["system"], null)
  system_os_policy_valid = !local.is_production || var.system_node_pool.os_sku == "AzureLinux" || try(
    local.system_os_exception.os_sku == var.system_node_pool.os_sku,
    false
  )
  user_pool_os_policy_valid = alltrue([
    for key, pool in var.user_node_pools :
    !local.is_production || pool.os_sku == "AzureLinux" || try(
      var.availability_policy.node_os_exceptions[key].os_sku == pool.os_sku,
      false
    )
  ])

  # Story 5: deterministic IPv4 CIDR arithmetic without external IPAM ownership.
  pod_cidr_parts     = split("/", var.network.pod_cidr)
  service_cidr_parts = split("/", var.network.service_cidr)
  pod_ip_octets_raw     = try([for octet in split(".", local.pod_cidr_parts[0]) : tonumber(octet)], [])
  service_ip_octets_raw = try([for octet in split(".", local.service_cidr_parts[0]) : tonumber(octet)], [])
  dns_ip_octets_raw     = try([for octet in split(".", var.network.dns_service_ip) : tonumber(octet)], [])
  pod_ip_octets         = length(local.pod_ip_octets_raw) == 4 ? local.pod_ip_octets_raw : [0, 0, 0, 0]
  service_ip_octets     = length(local.service_ip_octets_raw) == 4 ? local.service_ip_octets_raw : [0, 0, 0, 0]
  dns_ip_octets         = length(local.dns_ip_octets_raw) == 4 ? local.dns_ip_octets_raw : [0, 0, 0, 0]
  pod_prefix         = try(tonumber(local.pod_cidr_parts[1]), 32)
  service_prefix     = try(tonumber(local.service_cidr_parts[1]), 32)
  pod_ip_number      = local.pod_ip_octets[0] * 16777216 + local.pod_ip_octets[1] * 65536 + local.pod_ip_octets[2] * 256 + local.pod_ip_octets[3]
  service_ip_number  = local.service_ip_octets[0] * 16777216 + local.service_ip_octets[1] * 65536 + local.service_ip_octets[2] * 256 + local.service_ip_octets[3]
  dns_ip_number      = local.dns_ip_octets[0] * 16777216 + local.dns_ip_octets[1] * 65536 + local.dns_ip_octets[2] * 256 + local.dns_ip_octets[3]
  pod_cidr_size      = pow(2, 32 - local.pod_prefix)
  service_cidr_size  = pow(2, 32 - local.service_prefix)
  pod_network_start  = floor(local.pod_ip_number / local.pod_cidr_size) * local.pod_cidr_size
  service_network_start = floor(local.service_ip_number / local.service_cidr_size) * local.service_cidr_size
  pod_network_end     = local.pod_network_start + local.pod_cidr_size - 1
  service_network_end = local.service_network_start + local.service_cidr_size - 1
  cidrs_do_not_overlap = local.pod_network_end < local.service_network_start || local.service_network_end < local.pod_network_start
  dns_inside_service_cidr = local.dns_ip_number > local.service_network_start && local.dns_ip_number < local.service_network_end

 manual_required_pod_addresses = var.system_node_pool.max_count * var.system_node_pool.max_pods + sum(concat([0], [
  for pool in values(var.user_node_pools) : pool.max_count * pool.max_pods
]))
  nap_capacity_declared = try(var.network.capacity, null) != null
  nap_required_pod_addresses = local.nap_capacity_declared ? var.network.capacity.max_nodes * var.network.capacity.max_pods_per_node : 0
  required_pod_addresses = var.autoscaling.mode == "nap" ? local.nap_required_pod_addresses : local.manual_required_pod_addresses
  pod_capacity_sufficient = local.required_pod_addresses > 0 && local.pod_cidr_size >= local.required_pod_addresses

  # Story 4: version governance and effective maintenance exclusions.
  version_is_approved = local.effective_kubernetes_version != null && contains(var.approved_kubernetes_versions, local.effective_kubernetes_version)
  safe_production_upgrade_channels = !local.is_production || (
    contains(["patch", "stable"], var.automatic_upgrade_channel) &&
    contains(["NodeImage", "SecurityPatch"], var.node_os_upgrade_channel)
  )

  naming_readiness = {
    cluster_name_valid = length(local.cluster_name) >= 1 && length(local.cluster_name) <= 63 && can(regex("^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$", local.cluster_name))
    control_plane_identity_name_valid = length(local.control_plane_identity_name) >= 3 && length(local.control_plane_identity_name) <= 128 && can(regex("^[a-z0-9][a-z0-9-_]{1,126}[a-z0-9]$", local.control_plane_identity_name))
    kubelet_identity_name_valid = length(local.kubelet_identity_name) >= 3 && length(local.kubelet_identity_name) <= 128 && can(regex("^[a-z0-9][a-z0-9-_]{1,126}[a-z0-9]$", local.kubelet_identity_name))
    node_resource_group_name_valid = length(local.node_resource_group_name) <= 90
    diagnostic_setting_name_valid = length(local.diagnostic_setting_name) <= 260
  }
  all_module_owned_names_valid = alltrue(values(local.naming_readiness))
}
