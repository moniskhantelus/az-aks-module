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
    profile                  = local.effective_cluster_profile
    nap_friendly             = local.effective_cluster_profile == "stateless"
    spot_supported           = local.effective_cluster_profile == "stateless"
    ephemeral_os_preferred   = local.effective_cluster_profile == "stateless"
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
    azure_rbac                            = local.effective_azure_rbac_enabled
    local_accounts_disabled               = local.effective_local_account_disabled
    mandatory_admin_groups_retained       = length(local.effective_mandatory_admin_group_object_ids) > 0 && length(setsubtract(local.effective_mandatory_admin_group_object_ids, toset(local.effective_admin_group_object_ids))) == 0
    kms_etcd_encryption                   = var.kms_encryption.enabled
    kms_private_key_vault_access          = var.kms_encryption.key_vault_network_access == "Private"
    audit_workspace_configured            = local.log_analytics_workspace_id != null
    audit_archive_configured              = local.audit_archive_storage_id != null
    mandatory_audit_categories_configured = length(setsubtract(local.required_production_audit_categories, var.diagnostic_log_categories)) == 0
    ssh_disable_supported_by_provider     = false
    ssh_disable_ownership                 = "External until the approved AzureRM provider exposes AKS securityProfile.sshAccess in Azure Government."
  }
}


output "effective_kubernetes_version" {
  description = "Effective AKS Kubernetes version after provider resolution."
  value       = azurerm_kubernetes_cluster.this.kubernetes_version
}

output "naming_readiness" {
  description = "Story 7 validation of every module-created or derived resource name. Caller-owned existing resources are not renamed."
  value       = local.naming_readiness
}

output "availability_readiness" {
  description = "Story 3 production availability, SLA, zones, and node OS policy readiness."
  value = {
    production                    = local.is_production
    criticality                   = var.availability_policy.criticality
    sku_tier                      = local.effective_sku_tier
    supported_sla_tier            = local.production_sla_valid
    system_zones                  = var.system_node_pool.zones
    multi_zone_production_ready   = !local.is_production || length(distinct(var.system_node_pool.zones)) >= 2
    system_os_sku                 = var.system_node_pool.os_sku
    node_os_policy_ready          = local.system_os_policy_valid && local.user_pool_os_policy_valid
    node_os_exceptions            = var.availability_policy.node_os_exceptions
  }
}

output "upgrade_readiness" {
  description = "Story 4 governed upgrade/version contract and maintenance exclusions."
  value = {
    requested_version             = local.effective_kubernetes_version
    effective_version             = azurerm_kubernetes_cluster.this.kubernetes_version
    approved_versions             = sort(tolist(var.approved_kubernetes_versions))
    requested_version_approved    = local.version_is_approved
    automatic_upgrade_channel     = var.automatic_upgrade_channel
    node_os_upgrade_channel       = var.node_os_upgrade_channel
    safe_production_channels      = local.safe_production_upgrade_channels
    auto_upgrade_exclusions       = var.maintenance.auto_upgrade.not_allowed
    node_os_exclusions            = var.maintenance.node_os.not_allowed
  }
}

output "network_readiness" {
  description = "Story 5 deterministic network safety and pod-capacity calculations."
  value = {
    pod_cidr                     = var.network.pod_cidr
    service_cidr                 = var.network.service_cidr
    dns_service_ip               = var.network.dns_service_ip
    cidrs_do_not_overlap         = local.cidrs_do_not_overlap
    dns_inside_service_cidr      = local.dns_inside_service_cidr
    pod_cidr_address_capacity    = local.pod_cidr_size
    required_pod_addresses       = local.required_pod_addresses
    pod_capacity_sufficient      = local.pod_capacity_sufficient
    declared_nap_capacity        = try(var.network.capacity, null)
  }
}

output "storage_readiness" {
  description = "Story 6 effective AKS CSI/storage baseline and external backup handoff."
  value = {
    profile                     = local.effective_cluster_profile
    blob_csi_enabled            = var.storage_profile.blob_driver_enabled
    disk_csi_enabled            = var.storage_profile.disk_driver_enabled
    file_csi_enabled            = var.storage_profile.file_driver_enabled
    snapshot_controller_enabled = var.storage_profile.snapshot_controller_enabled
    backup_handoff_enabled      = var.backup_integration.enabled
    production_stateful_ready   = local.effective_cluster_profile != "stateful" || (var.storage_profile.disk_driver_enabled && var.storage_profile.snapshot_controller_enabled && var.backup_integration.enabled)
    storageclass_ownership      = "external-gitops"
  }
}

output "aks_readiness" {
  description = "Story 2 consolidated readiness contract for module consumers and release evidence."
  value = {
    encryption = {
      kms_enabled             = var.kms_encryption.enabled
      private_key_vault       = var.kms_encryption.key_vault_network_access == "Private"
    }
    private_api = {
      enabled                 = var.private_cluster.enabled
      public_fqdn_disabled    = !var.private_cluster.public_fqdn_enabled
    }
    rbac = {
      azure_rbac_enabled      = local.effective_azure_rbac_enabled
      local_accounts_disabled = local.effective_local_account_disabled
      admin_groups_configured = length(local.effective_admin_group_object_ids) > 0
    }
    audit = {
      workspace_configured    = local.log_analytics_workspace_id != null
      archive_configured      = local.audit_archive_storage_id != null
      categories              = sort(tolist(var.diagnostic_log_categories))
    }
    availability = {
      criticality             = var.availability_policy.criticality
      sla_ready               = local.production_sla_valid
      zones_ready             = !local.is_production || length(distinct(var.system_node_pool.zones)) >= 2
      node_os_ready           = local.system_os_policy_valid && local.user_pool_os_policy_valid
    }
    storage = {
      disk_csi                = var.storage_profile.disk_driver_enabled
      file_csi                = var.storage_profile.file_driver_enabled
      blob_csi                = var.storage_profile.blob_driver_enabled
      snapshot                = var.storage_profile.snapshot_controller_enabled
      backup_handoff          = var.backup_integration.enabled
    }
    upgrades = {
      requested_version       = local.effective_kubernetes_version
      approved                = local.version_is_approved
      channels_safe           = local.safe_production_upgrade_channels
      exclusions_configured   = length(var.maintenance.auto_upgrade.not_allowed) + length(var.maintenance.node_os.not_allowed) > 0
    }
    network = {
      cidrs_safe              = local.cidrs_do_not_overlap
      dns_placement_safe      = local.dns_inside_service_cidr
      pod_capacity_safe       = local.pod_capacity_sufficient
    }
    naming = local.naming_readiness
  }
}

output "normalized_cluster_contract" {
  description = "Story 9 provider-neutral/CAPI-ready output contract. Provider-specific Azure resource IDs remain nested implementation details."
  value = {
    cluster = {
      id                     = azurerm_kubernetes_cluster.this.id
      name                   = azurerm_kubernetes_cluster.this.name
      profile                = local.effective_cluster_profile
      compliance_profile     = local.effective_compliance_profile
      resource_group         = azurerm_kubernetes_cluster.this.resource_group_name
      node_resource_group    = azurerm_kubernetes_cluster.this.node_resource_group
    }
    identity = {
      control_plane = {
        resource_id  = local.control_plane_identity_id
        client_id    = local.control_plane_identity_client_id
        principal_id = local.control_plane_identity_principal_id
      }
      kubelet = {
        resource_id  = local.kubelet_identity_id
        client_id    = local.kubelet_identity_client_id
        principal_id = local.kubelet_identity_principal_id
      }
      workload_identity = {
        enabled         = true
        oidc_issuer_url = azurerm_kubernetes_cluster.this.oidc_issuer_url
      }
    }
    endpoint = {
      private_enabled = var.private_cluster.enabled
      private_fqdn    = azurerm_kubernetes_cluster.this.private_fqdn
      public_fqdn_enabled = var.private_cluster.public_fqdn_enabled
    }
    network = {
      attachment_id      = local.effective_node_subnet_id
      plugin             = "azure"
      mode               = "overlay"
      data_plane         = "cilium"
      pod_cidr           = var.network.pod_cidr
      service_cidr       = var.network.service_cidr
      dns_service_ip     = var.network.dns_service_ip
      outbound_type      = var.network.outbound_type
    }
    node_pools = {
      system = {
        architecture = var.system_node_pool.architecture
        os_sku       = var.system_node_pool.os_sku
        zones        = var.system_node_pool.zones
        max_pods     = var.system_node_pool.max_pods
      }
      users = {
        for key, pool in var.user_node_pools : key => {
          name         = pool.name
          architecture = pool.architecture
          os_type      = pool.os_type
          os_sku       = pool.os_sku
          zones        = pool.zones
          max_pods     = pool.max_pods
        }
      }
    }
    version = {
      requested = local.effective_kubernetes_version
      effective = azurerm_kubernetes_cluster.this.kubernetes_version
      approved  = local.version_is_approved
    }
    readiness = {
      security     = local.is_production ? "enforced" : "profile-dependent"
      availability = local.production_sla_valid && (!local.is_production || length(distinct(var.system_node_pool.zones)) >= 2)
      network      = local.cidrs_do_not_overlap && local.dns_inside_service_cidr && (!local.is_production || local.pod_capacity_sufficient)
      storage      = local.effective_cluster_profile != "stateful" || (var.storage_profile.disk_driver_enabled && var.storage_profile.snapshot_controller_enabled && var.backup_integration.enabled)
      upgrades     = !local.is_production || (local.version_is_approved && local.safe_production_upgrade_channels)
      naming       = local.all_module_owned_names_valid
    }
  }
}
