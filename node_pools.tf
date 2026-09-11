resource "azurerm_kubernetes_cluster_node_pool" "this" {
  for_each = var.autoscaling.mode == "manual" ? var.user_node_pools : {}

  name                  = each.value.name
  kubernetes_cluster_id = azurerm_kubernetes_cluster.this.id
  vm_size               = each.value.vm_size
  vnet_subnet_id        = local.effective_node_subnet_id

  auto_scaling_enabled = true
  min_count            = each.value.min_count
  max_count            = each.value.max_count
  node_count           = max(each.value.min_count, 1)

  zones                   = each.value.zones
  os_type                 = each.value.os_type
  os_sku                  = each.value.os_sku
  os_disk_type            = each.value.os_disk_type
  os_disk_size_gb         = each.value.os_disk_size_gb
  max_pods                = each.value.max_pods
  priority                = each.value.priority
  eviction_policy         = each.value.priority == "Spot" ? each.value.eviction_policy : null
  spot_max_price          = each.value.priority == "Spot" ? each.value.spot_max_price : null
  node_labels             = each.value.node_labels
  node_taints             = each.value.node_taints
  host_encryption_enabled = each.value.host_encryption_enabled
  fips_enabled            = each.value.fips_enabled
  ultra_ssd_enabled       = each.value.ultra_ssd_enabled
  mode                    = "User"

  temporary_name_for_rotation = coalesce(
    each.value.temporary_rotation_name,
    substr("${each.value.name}tmp", 0, 12)
  )

  upgrade_settings {
    max_surge = each.value.max_surge
  }

  tags = var.tags
}
