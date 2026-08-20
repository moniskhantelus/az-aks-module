resource "azurerm_kubernetes_cluster" "this" {
  name                = var.name
  location            = local.location
  resource_group_name = local.resource_group_name

  dns_prefix          = substr(var.name, 0, 54)
  kubernetes_version  = var.kubernetes_version
  sku_tier            = var.sku_tier
  support_plan        = var.support_plan
  node_resource_group = local.node_resource_group_name

  private_cluster_enabled             = var.private_cluster.enabled
  private_dns_zone_id                 = var.private_cluster.enabled ? var.private_cluster.private_dns_zone_id : null
  private_cluster_public_fqdn_enabled = var.private_cluster.enabled ? var.private_cluster.public_fqdn_enabled : false

  local_account_disabled            = var.local_account_disabled
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
    identity_ids = [azurerm_user_assigned_identity.control_plane.id]
  }

  kubelet_identity {
    client_id                 = azurerm_user_assigned_identity.kubelet.client_id
    object_id                 = azurerm_user_assigned_identity.kubelet.principal_id
    user_assigned_identity_id = azurerm_user_assigned_identity.kubelet.id
  }

  api_server_access_profile {
    authorized_ip_ranges = var.private_cluster.enabled ? null : var.private_cluster.api_server_authorized_ips
  }

  default_node_pool {
    name                         = "system"
    vm_size                      = var.system_node_pool.vm_size
    vnet_subnet_id               = var.node_subnet_id
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
    tenant_id              = var.tenant_id
    azure_rbac_enabled     = var.azure_rbac_enabled
    admin_group_object_ids = var.admin_group_object_ids
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
    network_mode      = var.network.network_mode
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
  }

  maintenance_window_node_os {
    frequency   = var.maintenance.node_os.frequency
    interval    = var.maintenance.node_os.interval
    duration    = var.maintenance.node_os.duration
    day_of_week = try(var.maintenance.node_os.day_of_week, null)
    start_time  = var.maintenance.node_os.start_time
    utc_offset  = var.maintenance.node_os.utc_offset
  }

  tags = var.tags

  depends_on = [
    azurerm_role_assignment.control_plane_network,
    azurerm_role_assignment.control_plane_kubelet_identity_operator
  ]

  lifecycle {
    precondition {
      condition     = !var.local_account_disabled || length(var.admin_group_object_ids) > 0
      error_message = "Disabling local accounts requires at least one Entra administrator group."
    }

    precondition {
      condition     = var.sku_tier != "Premium" || var.support_plan == "AKSLongTermSupport"
      error_message = "Premium tier must use AKSLongTermSupport."
    }

    precondition {
      condition     = var.support_plan != "AKSLongTermSupport" || var.sku_tier == "Premium"
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
      condition     = var.compliance_profile != "fips" || (var.platform_security.fips_required && var.system_node_pool.fips_enabled && var.system_node_pool.host_encryption_enabled)
      error_message = "compliance_profile fips requires the FIPS contract, FIPS, and host encryption on the fixed system pool."
    }

    precondition {
      condition = var.compliance_profile != "fips" || var.autoscaling.mode == "nap" || alltrue([
        for pool in values(var.user_node_pools) : pool.os_type != "Linux" || (pool.fips_enabled && pool.host_encryption_enabled)
      ])
      error_message = "compliance_profile fips requires FIPS and host encryption on every Terraform-managed Linux user pool."
    }

    precondition {
      condition     = var.cluster_profile != "stateful" || (var.storage_profile.disk_driver_enabled && var.storage_profile.snapshot_controller_enabled)
      error_message = "stateful clusters require Azure Disk CSI and the snapshot controller."
    }

    precondition {
      condition     = var.cluster_profile != "stateful" || var.backup_integration.enabled
      error_message = "stateful clusters require the external backup integration hook to be enabled."
    }

    precondition {
      condition     = var.cluster_profile != "stateful" || length(var.system_node_pool.zones) >= 2
      error_message = "stateful clusters require a multi-zone fixed system pool."
    }

    precondition {
      condition     = var.cluster_profile != "stateful" || var.disruption_profile.consolidation == "conservative"
      error_message = "stateful clusters require conservative disruption/consolidation policy."
    }

    precondition {
      condition     = var.cluster_profile != "stateful" || alltrue([for pool in values(var.user_node_pools) : pool.priority != "Spot"])
      error_message = "stateful clusters cannot use Terraform-managed Spot pools; isolate Spot capacity in a stateless cluster profile."
    }
  }
}
