output "cluster_id" {
  description = "AKS resource ID."
  value       = azurerm_kubernetes_cluster.this.id
}

output "cluster_name" {
  description = "AKS cluster name."
  value       = azurerm_kubernetes_cluster.this.name
}

output "resource_group_name" {
  description = "AKS resource group name."
  value       = azurerm_kubernetes_cluster.this.resource_group_name
}

output "resource_group_id" {
  description = "Effective resource group ID, whether created or reused."
  value = var.resource_group.create ? (
    azurerm_resource_group.this[0].id
  ) : data.azurerm_resource_group.existing[0].id
}

output "resource_group_location" {
  description = "Effective resource group location."
  value       = local.location
}

output "resource_group_created" {
  description = "Whether this module creates and owns the resource group."
  value       = var.resource_group.create
}

output "node_resource_group" {
  description = "AKS-managed infrastructure resource group."
  value       = azurerm_kubernetes_cluster.this.node_resource_group
}

output "oidc_issuer_url" {
  description = "OIDC issuer for workload identity federation."
  value       = azurerm_kubernetes_cluster.this.oidc_issuer_url
}

output "control_plane_identity" {
  description = "Effective control-plane managed identity details."
  value = {
    id           = local.control_plane_identity_id
    client_id    = local.control_plane_identity_client_id
    principal_id = local.control_plane_identity_principal_id
  }
}

output "kubelet_identity" {
  description = "Effective kubelet managed identity details."
  value = {
    id           = local.kubelet_identity_id
    client_id    = local.kubelet_identity_client_id
    principal_id = local.kubelet_identity_principal_id
  }
}

output "private_fqdn" {
  description = "Private API FQDN."
  value       = azurerm_kubernetes_cluster.this.private_fqdn
}

output "portal_fqdn" {
  description = "AKS portal FQDN."
  value       = azurerm_kubernetes_cluster.this.portal_fqdn
}

output "user_node_pool_ids" {
  description = "User node pool IDs."
  value = {
    for key, value in azurerm_kubernetes_cluster_node_pool.this :
    key => value.id
  }
}

output "key_vault_secrets_provider_identity" {
  description = "Identity created by the AKS Key Vault CSI add-on."
  value = try({
    client_id = azurerm_kubernetes_cluster.this.key_vault_secrets_provider[0].secret_identity[0].client_id
    object_id = azurerm_kubernetes_cluster.this.key_vault_secrets_provider[0].secret_identity[0].object_id
  }, null)
}

output "connect_command" {
  description = "Azure CLI command for retrieving credentials."
  value       = "az aks get-credentials --resource-group ${local.resource_group_name} --name ${local.cluster_name} --overwrite-existing"
}

output "node_provisioning" {
  description = "Effective AKS capacity-management mode."
  value = {
    mode               = var.autoscaling.mode
    default_node_pools = var.autoscaling.nap_default_node_pools
    managed_karpenter  = var.autoscaling.mode == "nap"
  }
}

output "nap_gitops_required" {
  description = "True when platform-owned Karpenter NodePool and AKSNodeClass resources must be reconciled after cluster creation."
  value       = var.autoscaling.mode == "nap" && var.autoscaling.nap_default_node_pools == "None"
}

output "cluster_profile_contract" {
  description = "Profile-driven workload, storage, backup, availability, and disruption handoff."
  value = {
    profile                  = var.cluster_profile
    nap_friendly             = var.cluster_profile == "stateless"
    spot_supported           = var.cluster_profile == "stateless"
    ephemeral_os_preferred   = var.cluster_profile == "stateless"
    disruption               = var.disruption_profile
    azure_disk_csi_enabled   = var.storage_profile.disk_driver_enabled
    snapshot_enabled         = var.storage_profile.snapshot_controller_enabled
    backup_integration_ready = var.backup_integration.enabled
    multi_zone               = length(var.system_node_pool.zones) >= 2
    system_architecture      = var.system_node_pool.architecture
    user_pool_architectures  = { for key, pool in var.user_node_pools : key => pool.architecture }
  }
}

output "backup_integration" {
  description = "Inputs required by a separate backup module; no backup resources are created here."
  value = {
    enabled                     = var.backup_integration.enabled
    cluster_id                  = azurerm_kubernetes_cluster.this.id
    cluster_name                = azurerm_kubernetes_cluster.this.name
    resource_group_name         = azurerm_kubernetes_cluster.this.resource_group_name
    node_resource_group         = azurerm_kubernetes_cluster.this.node_resource_group
    control_plane_identity_id   = local.control_plane_identity_id
    control_plane_principal_id  = local.control_plane_identity_principal_id
    kubelet_identity_id         = local.kubelet_identity_id
    kubelet_principal_id        = local.kubelet_identity_principal_id
    blob_driver_enabled         = var.storage_profile.blob_driver_enabled
    disk_driver_enabled         = var.storage_profile.disk_driver_enabled
    file_driver_enabled         = var.storage_profile.file_driver_enabled
    snapshot_controller_enabled = var.storage_profile.snapshot_controller_enabled
  }
}

output "pki_integration_contract" {
  description = "Enterprise PKI handoff only; the module does not install PKI components."
  value       = var.pki_integration
}

output "admission_controller_ownership" {
  description = "Confirms admission policy engines remain owned by the bootstrap/GitOps layer."
  value       = "external-neutral"
}

output "platform_security_contract" {
  description = "Security requirements that infrastructure and the bootstrap/GitOps layer must jointly enforce."
  value = {
    fips_required               = var.platform_security.fips_required
    psa_enforce_level           = var.platform_security.psa_enforce_level
    default_deny_network_policy = var.platform_security.default_deny_network_policy
    network_policy_engine       = "cilium"
  }
}

output "production_security_readiness" {
  description = "Effective Story 1 production security controls and externally owned readiness items."
  value = {
    production                            = local.is_production
    private_api                           = var.private_cluster.enabled && !var.private_cluster.public_fqdn_enabled
    azure_rbac                            = var.azure_rbac_enabled
    local_accounts_disabled               = var.local_account_disabled
    mandatory_admin_groups_retained       = length(var.mandatory_admin_group_object_ids) > 0 && length(setsubtract(var.mandatory_admin_group_object_ids, toset(var.admin_group_object_ids))) == 0
    kms_etcd_encryption                   = var.kms_encryption.enabled
    kms_private_key_vault_access          = var.kms_encryption.key_vault_network_access == "Private"
    audit_workspace_configured            = local.log_analytics_workspace_id != null
    audit_archive_configured              = local.audit_archive_storage_id != null
    mandatory_audit_categories_configured = length(setsubtract(local.required_production_audit_categories, var.diagnostic_log_categories)) == 0
    ssh_disable_supported_by_provider     = false
    ssh_disable_ownership                 = "External until the approved AzureRM provider exposes AKS securityProfile.sshAccess in Azure Government."
  }
}
