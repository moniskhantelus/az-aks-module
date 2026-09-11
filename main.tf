resource "azurerm_kubernetes_cluster" "this" {
  name                = local.cluster_name
  location            = local.location
  resource_group_name = local.resource_group_name

  dns_prefix          = substr(local.cluster_name, 0, 54)
  kubernetes_version  = local.effective_kubernetes_version
  sku_tier            = local.effective_sku_tier
  support_plan        = local.effective_support_plan
  node_resource_group = local.node_resource_group_name

  private_cluster_enabled             = var.private_cluster.enabled
  private_dns_zone_id                 = var.private_cluster.enabled ? var.private_cluster.private_dns_zone_id : null
  private_cluster_public_fqdn_enabled = var.private_cluster.enabled ? var.private_cluster.public_fqdn_enabled : false

  local_account_disabled            = local.effective_local_account_disabled
  role_based_access_control_enabled = true
  oidc_issuer_enabled               = true
  workload_identity_enabled         = true
  azure_policy_enabled              = var.addons.azure_policy_enabled

  automatic_upgrade_channel = var.automatic_upgrade_channel
  node_os_upgrade_channel   = var.node_os_upgrade_channel

  image_cleaner_enabled        = var.addons.image_cleaner_enabled
  image_cleaner_interval_hours = var.addons.image_cleaner_enabled ? var.addons.image_cleaner_interval_hours : null


  node_provisioning_profile {
    mode               = var.autoscaling.mode == "nap" ? "Auto" : "Manual"
    default_node_pools = var.autoscaling.nap_default_node_pools
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [local.control_plane_identity_id]
  }

  kubelet_identity {
    client_id                 = local.kubelet_identity_client_id
    object_id                 = local.kubelet_identity_principal_id
    user_assigned_identity_id = local.kubelet_identity_id
  }

  api_server_access_profile {
    authorized_ip_ranges = var.private_cluster.enabled ? null : var.private_cluster.api_server_authorized_ips

    virtual_network_integration_enabled = var.private_cluster.api_server_vnet_integration_enabled

    subnet_id = var.private_cluster.api_server_vnet_integration_enabled ? (
      var.private_cluster.api_server_subnet_id
    ) : null
  }

  default_node_pool {
    name                         = local.system_node_pool_name
    vm_size                      = var.system_node_pool.vm_size
    vnet_subnet_id               = local.effective_node_subnet_id
    auto_scaling_enabled         = var.autoscaling.mode == "manual"
    min_count                    = var.autoscaling.mode == "manual" ? var.system_node_pool.min_count : null
    max_count                    = var.autoscaling.mode == "manual" ? var.system_node_pool.max_count : null
    node_count                   = var.autoscaling.mode == "manual" ? var.system_node_pool.min_count : var.system_node_pool.node_count
    zones                        = var.system_node_pool.zones
    os_sku                       = var.system_node_pool.os_sku
    os_disk_type                 = var.system_node_pool.os_disk_type
    os_disk_size_gb              = var.system_node_pool.os_disk_size_gb
    max_pods                     = var.system_node_pool.max_pods
    only_critical_addons_enabled = var.system_node_pool.only_critical_addons
    node_labels                  = local.system_node_labels
    host_encryption_enabled      = var.system_node_pool.host_encryption_enabled
    fips_enabled                 = var.system_node_pool.fips_enabled
    temporary_name_for_rotation  = var.system_node_pool.temporary_rotation_name
    tags                         = var.tags

    upgrade_settings {
      max_surge = var.system_node_pool.max_surge
    }
  }

  azure_active_directory_role_based_access_control {
    tenant_id              = local.effective_tenant_id
    azure_rbac_enabled     = local.effective_azure_rbac_enabled
    admin_group_object_ids = local.effective_admin_group_object_ids
  }

  dynamic "auto_scaler_profile" {
    for_each = var.autoscaling.mode == "manual" ? [1] : []

    content {
      balance_similar_node_groups      = var.auto_scaler_profile.balance_similar_node_groups
      expander                         = var.auto_scaler_profile.expander
      max_graceful_termination_sec     = var.auto_scaler_profile.max_graceful_termination_sec
      max_node_provisioning_time       = var.auto_scaler_profile.max_node_provisioning_time
      max_unready_nodes                = var.auto_scaler_profile.max_unready_nodes
      max_unready_percentage           = var.auto_scaler_profile.max_unready_percentage
      new_pod_scale_up_delay           = var.auto_scaler_profile.new_pod_scale_up_delay
      scale_down_delay_after_add       = var.auto_scaler_profile.scale_down_delay_after_add
      scale_down_delay_after_delete    = var.auto_scaler_profile.scale_down_delay_after_delete
      scale_down_delay_after_failure   = var.auto_scaler_profile.scale_down_delay_after_failure
      scan_interval                    = var.auto_scaler_profile.scan_interval
      scale_down_unneeded              = var.auto_scaler_profile.scale_down_unneeded
      scale_down_unready               = var.auto_scaler_profile.scale_down_unready
      scale_down_utilization_threshold = var.auto_scaler_profile.scale_down_utilization_threshold
      empty_bulk_delete_max            = var.auto_scaler_profile.empty_bulk_delete_max
      skip_nodes_with_local_storage    = var.auto_scaler_profile.skip_nodes_with_local_storage
      skip_nodes_with_system_pods      = var.auto_scaler_profile.skip_nodes_with_system_pods
    }
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_data_plane  = "cilium"
    network_policy      = "cilium"

    pod_cidr          = var.network.pod_cidr
    service_cidr      = var.network.service_cidr
    dns_service_ip    = var.network.dns_service_ip
    outbound_type     = var.network.outbound_type
    load_balancer_sku = var.network.load_balancer_sku
  }

  storage_profile {
    blob_driver_enabled         = var.storage_profile.blob_driver_enabled
    disk_driver_enabled         = var.storage_profile.disk_driver_enabled
    file_driver_enabled         = var.storage_profile.file_driver_enabled
    snapshot_controller_enabled = var.storage_profile.snapshot_controller_enabled
  }

  workload_autoscaler_profile {
    keda_enabled                    = var.addons.keda_enabled
    vertical_pod_autoscaler_enabled = var.addons.vertical_pod_autoscaler_enabled
  }

  dynamic "key_vault_secrets_provider" {
    for_each = var.addons.key_vault_csi_enabled ? [1] : []

    content {
      secret_rotation_enabled  = var.addons.key_vault_secret_rotation
      secret_rotation_interval = var.addons.key_vault_rotation_interval
    }
  }

  dynamic "key_management_service" {
    for_each = var.kms_encryption.enabled ? [var.kms_encryption] : []

    content {
      key_vault_key_id         = key_management_service.value.key_vault_key_id
      key_vault_network_access = key_management_service.value.key_vault_network_access
    }
  }

  dynamic "oms_agent" {
    for_each = var.addons.container_insights_enabled ? [1] : []

    content {
      log_analytics_workspace_id      = local.log_analytics_workspace_id
      msi_auth_for_monitoring_enabled = true
    }
  }

  dynamic "monitor_metrics" {
    for_each = var.addons.managed_prometheus_enabled ? [1] : []
    content {}
  }

  dynamic "microsoft_defender" {
    for_each = var.addons.defender_enabled ? [1] : []

    content {
      log_analytics_workspace_id = local.defender_workspace_id
    }
  }

  dynamic "service_mesh_profile" {
    for_each = var.addons.istio_enabled ? [1] : []

    content {
      mode                             = "Istio"
      revisions                        = var.addons.istio_revisions
      internal_ingress_gateway_enabled = var.addons.istio_internal_gateway_enabled
      external_ingress_gateway_enabled = var.addons.istio_external_gateway_enabled
    }
  }

  maintenance_window_auto_upgrade {
    frequency   = var.maintenance.auto_upgrade.frequency
    interval    = var.maintenance.auto_upgrade.interval
    duration    = var.maintenance.auto_upgrade.duration
    day_of_week = try(var.maintenance.auto_upgrade.day_of_week, null)
    start_time  = var.maintenance.auto_upgrade.start_time
    utc_offset  = var.maintenance.auto_upgrade.utc_offset

    dynamic "not_allowed" {
      for_each = var.maintenance.auto_upgrade.not_allowed
      content {
        start = not_allowed.value.start
        end   = not_allowed.value.end
      }
    }
  }

  maintenance_window_node_os {
    frequency   = var.maintenance.node_os.frequency
    interval    = var.maintenance.node_os.interval
    duration    = var.maintenance.node_os.duration
    day_of_week = try(var.maintenance.node_os.day_of_week, null)
    start_time  = var.maintenance.node_os.start_time
    utc_offset  = var.maintenance.node_os.utc_offset

    dynamic "not_allowed" {
      for_each = var.maintenance.node_os.not_allowed
      content {
        start = not_allowed.value.start
        end   = not_allowed.value.end
      }
    }
  }

  tags = var.tags

  depends_on = [
    azurerm_role_assignment.control_plane_network,
    azurerm_role_assignment.control_plane_kubelet_identity_operator,
    azurerm_role_assignment.control_plane_api_server_network,
    azurerm_role_assignment.control_plane_key_vault_contributor,
    azurerm_role_assignment.control_plane_key_vault_crypto_user
  ]

  lifecycle {
    precondition {
      condition = (
        try(jsondecode(var.tags["KAAS_TAG"]).mo, "") == var.naming.maintain_org &&
        try(jsondecode(var.tags["KAAS_TAG"]).env, "") == var.naming.environment &&
        try(jsondecode(var.tags["KAAS_INFRA_TAG"]).persistence, "") == local.effective_cluster_profile
      )
      error_message = "KaaS tag identity/environment/persistence must match naming and cluster_profile inputs."
    }
    precondition {
      condition     = !local.effective_local_account_disabled || length(local.effective_admin_group_object_ids) > 0
      error_message = "Disabling local accounts requires at least one Entra administrator group."
    }

    precondition {
      condition     = !local.is_production || var.private_cluster.enabled
      error_message = "Production clusters require a private API endpoint."
    }

    precondition {
      condition     = !local.is_production || !var.private_cluster.public_fqdn_enabled
      error_message = "Production private clusters must not expose a public FQDN."
    }

    precondition {
      condition     = !local.is_production || length(var.private_cluster.api_server_authorized_ips) == 0
      error_message = "Production private clusters must not configure public API authorized IP ranges."
    }

    precondition {
      condition     = !local.is_production || local.effective_azure_rbac_enabled
      error_message = "Production clusters require Azure RBAC for Kubernetes authorization."
    }

    precondition {
      condition     = !local.is_production || local.effective_local_account_disabled
      error_message = "Production clusters must disable AKS local administrator accounts."
    }

    precondition {
      condition     = !local.is_production || length(local.effective_mandatory_admin_group_object_ids) > 0
      error_message = "Production clusters require at least one mandatory platform administrator group."
    }

    precondition {
      condition = !local.is_production || length(setsubtract(
        local.effective_mandatory_admin_group_object_ids,
        toset(local.effective_admin_group_object_ids)
      )) == 0
      error_message = "admin_group_object_ids must retain every mandatory platform administrator group."
    }

    precondition {
      condition     = !local.is_production || var.kms_encryption.enabled
      error_message = "Production clusters require KMS-backed etcd encryption."
    }

    precondition {
      condition     = !local.is_production || var.kms_encryption.key_vault_network_access == "Private"
      error_message = "Production KMS encryption requires private Key Vault network access."
    }

    precondition {
      condition     = !local.is_production || try(trimspace(var.integrations.log_analytics_workspace_id), "") != ""
      error_message = "Production clusters require an approved Log Analytics workspace."
    }

    precondition {
      condition     = !local.is_production || try(trimspace(var.integrations.audit_archive_storage_account_id), "") != ""
      error_message = "Production clusters require an audit archival storage destination."
    }

    precondition {
      condition = !local.is_production || length(setsubtract(
        local.required_production_audit_categories,
        var.diagnostic_log_categories
      )) == 0
      error_message = "Production diagnostics must include kube-audit and kube-audit-admin."
    }

    precondition {
      condition     = local.effective_sku_tier != "Premium" || local.effective_support_plan == "AKSLongTermSupport"
      error_message = "Premium tier must use AKSLongTermSupport."
    }

    precondition {
      condition     = local.effective_support_plan != "AKSLongTermSupport" || local.effective_sku_tier == "Premium"
      error_message = "AKSLongTermSupport requires Premium tier."
    }

    precondition {
      condition = !(
        var.automatic_upgrade_channel == "node-image" &&
        var.node_os_upgrade_channel != "NodeImage"
      )
      error_message = "The node-image cluster channel requires node_os_upgrade_channel = NodeImage."
    }


    precondition {
      condition = (
        local.effective_tenant_id != null && trimspace(local.effective_tenant_id) != "" &&
        local.effective_node_subnet_id != null && trimspace(local.effective_node_subnet_id) != "" &&
        local.effective_sku_tier != null && local.effective_support_plan != null &&
        local.effective_cluster_profile != null && local.effective_compliance_profile != null &&
        length(local.effective_admin_group_object_ids) > 0
      )
      error_message = "The effective normalized contract must provide tenant, subnet, SKU, support plan, cluster/compliance profiles, and at least one administrator group."
    }

    precondition {
      condition     = local.all_module_owned_names_valid
      error_message = "One or more module-created/derived names violate the KaaS/Azure naming constraints. Inspect the naming_readiness output."
    }

    precondition {
      condition     = local.production_sla_valid
      error_message = "Production clusters require a supported criticality and Standard or Premium AKS tier; Free is non-production only."
    }

    precondition {
      condition     = try(jsondecode(var.tags["KAAS_TAG"]).tier, "") == var.availability_policy.criticality
      error_message = "availability_policy.criticality must match KAAS_TAG.tier from onboarding."
    }

    precondition {
      condition     = !local.is_production || length(distinct(var.system_node_pool.zones)) >= 2
      error_message = "Production system pools require at least two distinct availability zones."
    }

    precondition {
      condition     = local.system_os_policy_valid && local.user_pool_os_policy_valid
      error_message = "Production node pools default to AzureLinux. Ubuntu or Windows requires availability_policy.node_os_exceptions metadata with matching os_sku, approval_reference, and justification."
    }

    precondition {
      condition     = !local.is_production || (length(var.approved_kubernetes_versions) > 0 && local.version_is_approved)
      error_message = "Production requires an explicit kubernetes_version contained in approved_kubernetes_versions."
    }

    precondition {
      condition     = local.safe_production_upgrade_channels
      error_message = "Production requires automatic_upgrade_channel patch/stable and node_os_upgrade_channel NodeImage/SecurityPatch."
    }

    precondition {
      condition     = local.cidrs_do_not_overlap
      error_message = "network.pod_cidr and network.service_cidr must not overlap."
    }

    precondition {
      condition     = local.dns_inside_service_cidr
      error_message = "network.dns_service_ip must be a usable address inside network.service_cidr and cannot be the network or broadcast address."
    }

    precondition {
      condition     = var.autoscaling.mode != "nap" || !local.is_production || local.nap_capacity_declared
      error_message = "Production NAP clusters require network.capacity so pod CIDR capacity can be validated against declared max_nodes and max_pods_per_node."
    }

    precondition {
      condition     = !local.is_production || local.pod_capacity_sufficient
      error_message = "network.pod_cidr does not provide enough addresses for the declared maximum node/pod capacity."
    }

    precondition {
      condition     = var.autoscaling.mode != "nap" || length(var.user_node_pools) == 0
      error_message = "NAP mode cannot be combined with Terraform-managed user node pools. Manage Karpenter NodePool and AKSNodeClass resources through GitOps."
    }

    precondition {
      condition     = var.autoscaling.mode != "nap" || var.network.load_balancer_sku == "standard"
      error_message = "NAP with a custom VNet requires Standard Load Balancer."
    }

    precondition {
      condition     = var.autoscaling.mode != "nap" || alltrue([for pool in values(var.user_node_pools) : pool.os_type != "Windows"])
      error_message = "Windows node pools are not supported with AKS Node Auto-Provisioning."
    }

    precondition {
      condition     = local.effective_compliance_profile != "fips" || (var.platform_security.fips_required && var.system_node_pool.fips_enabled && var.system_node_pool.host_encryption_enabled)
      error_message = "compliance_profile fips requires the FIPS contract, FIPS, and host encryption on the fixed system pool."
    }

    precondition {
      condition = local.effective_compliance_profile != "fips" || var.autoscaling.mode == "nap" || alltrue([
        for pool in values(var.user_node_pools) : pool.os_type != "Linux" || (pool.fips_enabled && pool.host_encryption_enabled)
      ])
      error_message = "compliance_profile fips requires FIPS and host encryption on every Terraform-managed Linux user pool."
    }

    precondition {
      condition     = local.effective_cluster_profile != "stateful" || (var.storage_profile.disk_driver_enabled && var.storage_profile.snapshot_controller_enabled)
      error_message = "stateful clusters require Azure Disk CSI and the snapshot controller."
    }

    precondition {
      condition     = local.effective_cluster_profile != "stateful" || var.backup_integration.enabled
      error_message = "stateful clusters require the external backup integration hook to be enabled."
    }

    precondition {
      condition     = local.effective_cluster_profile != "stateful" || length(var.system_node_pool.zones) >= 2
      error_message = "stateful clusters require a multi-zone fixed system pool."
    }

    precondition {
      condition     = local.effective_cluster_profile != "stateful" || var.disruption_profile.consolidation == "conservative"
      error_message = "stateful clusters require conservative disruption/consolidation policy."
    }

    precondition {
      condition     = local.effective_cluster_profile != "stateful" || alltrue([for pool in values(var.user_node_pools) : pool.priority != "Spot"])
      error_message = "stateful clusters cannot use Terraform-managed Spot pools; isolate Spot capacity in a stateless cluster profile."
    }
  }
}
