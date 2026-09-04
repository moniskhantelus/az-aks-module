resource "azurerm_user_assigned_identity" "control_plane" {
  count = var.managed_identities.create ? 1 : 0

  name                = local.control_plane_identity_name
  location            = local.location
  resource_group_name = local.resource_group_name
  tags                = var.tags

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_user_assigned_identity" "kubelet" {
  count = var.managed_identities.create ? 1 : 0

  name                = local.kubelet_identity_name
  location            = local.location
  resource_group_name = local.resource_group_name
  tags                = var.tags

  lifecycle {
    prevent_destroy = true
  }
}

data "azurerm_user_assigned_identity" "control_plane" {
  count = var.managed_identities.create ? 0 : 1

  name                = basename(var.managed_identities.control_plane_identity_id)
  resource_group_name = split("/", var.managed_identities.control_plane_identity_id)[4]
}

data "azurerm_user_assigned_identity" "kubelet" {
  count = var.managed_identities.create ? 0 : 1

  name                = basename(var.managed_identities.kubelet_identity_id)
  resource_group_name = split("/", var.managed_identities.kubelet_identity_id)[4]
}

resource "azurerm_role_assignment" "control_plane_network" {
  count                = var.manage_role_assignments ? 1 : 0
  scope                = var.node_subnet_id
  role_definition_name = "Network Contributor"
  principal_id         = local.control_plane_identity_principal_id
}

# AKS must be allowed to assign the caller-provided kubelet identity to its
# agent pools. Scope this permission to that identity rather than the resource
# group or subscription.
resource "azurerm_role_assignment" "control_plane_kubelet_identity_operator" {
  count                            = var.manage_role_assignments ? 1 : 0
  scope                            = local.kubelet_identity_id
  role_definition_name             = "Managed Identity Operator"
  principal_id                     = local.control_plane_identity_principal_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "acr_pull" {
  count                = var.manage_role_assignments && var.integrations.acr_id != null ? 1 : 0
  scope                = local.acr_id
  role_definition_name = "AcrPull"
  principal_id         = local.kubelet_identity_principal_id
}

resource "azurerm_role_assignment" "control_plane_api_server_network" {
  count = (
    var.manage_role_assignments &&
    var.private_cluster.api_server_vnet_integration_enabled
  ) ? 1 : 0
  scope                            = var.private_cluster.api_server_subnet_id
  role_definition_name             = "Network Contributor"
  principal_id                     = local.control_plane_identity_principal_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "control_plane_key_vault_contributor" {
  count = (
    var.manage_role_assignments &&
    var.kms_encryption.enabled &&
    var.kms_encryption.key_vault_network_access == "Private"
  ) ? 1 : 0

  scope                            = var.kms_encryption.key_vault_resource_id
  role_definition_name             = "Key Vault Contributor"
  principal_id                     = local.control_plane_identity_principal_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "control_plane_key_vault_crypto_user" {
  count = (
    var.manage_role_assignments &&
    var.kms_encryption.enabled
  ) ? 1 : 0

  scope                            = var.kms_encryption.key_vault_resource_id
  role_definition_name             = "Key Vault Crypto User"
  principal_id                     = local.control_plane_identity_principal_id
  skip_service_principal_aad_check = true
}
