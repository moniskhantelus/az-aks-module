variable "subscription_id" { type = string }
variable "tenant_id" { type = string }
variable "naming" { type = any }
variable "resource_group" { type = any }
variable "node_subnet_id" { type = string }
variable "kubernetes_version" {
  type     = string
  nullable = true
}
variable "sku_tier" { type = string }
variable "support_plan" { type = string }
variable "admin_group_object_ids" { type = list(string) }
variable "azure_rbac_enabled" { type = bool }
variable "local_account_disabled" { type = bool }
variable "cluster_profile" { type = string }
variable "compliance_profile" { type = string }
variable "platform_security" { type = any }
variable "autoscaling" { type = any }
variable "disruption_profile" { type = any }
variable "availability_policy" { type = any }
variable "approved_kubernetes_versions" { type = set(string) }
variable "private_cluster" { type = any }
variable "network" { type = any }
variable "kms_encryption" { type = any }
variable "system_node_pool" { type = any }
variable "user_node_pools" { type = any }
variable "auto_scaler_profile" { type = any }
variable "automatic_upgrade_channel" { type = string }
variable "node_os_upgrade_channel" { type = string }
variable "maintenance" { type = any }
variable "addons" { type = any }
variable "storage_profile" { type = any }
variable "integrations" { type = any }
variable "backup_integration" { type = any }
variable "pki_integration" { type = any }
variable "diagnostic_log_categories" { type = set(string) }
variable "tags" { type = map(string) }
variable "manage_role_assignments" {
  description = "Whether this module creates Azure RBAC role assignments required by AKS."
  type        = bool
}
variable "managed_identities" {
  description = "Existing or module-managed AKS identities."
  type = object({
    create                    = bool
    control_plane_identity_id = optional(string)
    kubelet_identity_id       = optional(string)
  })
}
# variable "location" {
#   description = "Azure region in which regional AKS resources are deployed."
#   type        = string
# }
