module "aks" {
  source = "../.."

  naming                    = var.naming
  resource_group            = var.resource_group
  managed_identities        = var.managed_identities
  tenant_id                 = var.tenant_id
  node_subnet_id            = var.node_subnet_id
  kubernetes_version        = var.kubernetes_version
  sku_tier                  = var.sku_tier
  support_plan              = var.support_plan
  admin_group_object_ids    = var.admin_group_object_ids
  azure_rbac_enabled        = var.azure_rbac_enabled
  local_account_disabled    = var.local_account_disabled
  cluster_profile           = var.cluster_profile
  compliance_profile        = var.compliance_profile
  platform_security         = var.platform_security
  autoscaling               = var.autoscaling
  disruption_profile        = var.disruption_profile
  kms_encryption            = var.kms_encryption
  private_cluster           = var.private_cluster
  network                   = var.network
  system_node_pool          = var.system_node_pool
  user_node_pools           = var.user_node_pools
  auto_scaler_profile       = var.auto_scaler_profile
  automatic_upgrade_channel = var.automatic_upgrade_channel
  node_os_upgrade_channel   = var.node_os_upgrade_channel
  maintenance               = var.maintenance
  addons                    = var.addons
  storage_profile           = var.storage_profile
  integrations              = var.integrations
  backup_integration        = var.backup_integration
  pki_integration           = var.pki_integration
  diagnostic_log_categories = var.diagnostic_log_categories
  tags                      = var.tags
  manage_role_assignments   = var.manage_role_assignments
}

output "aks" {
  value = {
    cluster_id                 = module.aks.cluster_id
    cluster_name               = module.aks.cluster_name
    resource_group_name        = module.aks.resource_group_name
    resource_group_created     = module.aks.resource_group_created
    oidc_issuer_url            = module.aks.oidc_issuer_url
    node_provisioning          = module.aks.node_provisioning
    nap_gitops_required        = module.aks.nap_gitops_required
    platform_security_contract = module.aks.platform_security_contract
    cluster_profile_contract   = module.aks.cluster_profile_contract
    backup_integration         = module.aks.backup_integration
    pki_integration_contract   = module.aks.pki_integration_contract
    connect_command            = module.aks.connect_command
  }
}
