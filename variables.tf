variable "naming" {
  description = "KaaS naming segments. Names are derived as <platform>-<maintain-org>-<env>-<region>-aks and corresponding resource suffixes."
  type = object({
    platform     = string
    maintain_org = string
    environment  = string
    region_code  = string
  })

  validation {
    condition = (
      var.naming.platform == "kaas" &&
      contains(["iao", "hr", "cs", "fs", "cdp", "ops", "fin"], var.naming.maintain_org) &&
      contains(["sandbox", "dev", "stage", "prod", "dr"], var.naming.environment) &&
      contains(["va", "az"], var.naming.region_code)
    )
    error_message = "naming must use platform kaas, an approved maintaining org/environment, and region code va or az."
  }
}

variable "resource_group" {
  description = "Resource group ownership settings. Create the group for platform-owned deployments or reuse an existing group by name. Location is required only when creating the group."
  type = object({
    create   = bool
    name     = string
    location = optional(string)
  })

  validation {
    condition     = trimspace(var.resource_group.name) != ""
    error_message = "resource_group.name must not be empty."
  }

  validation {
    condition     = !var.resource_group.create || try(trimspace(var.resource_group.location) != "", false)
    error_message = "resource_group.location must be provided when resource_group.create is true."
  }
}

# variable "location" {
#   description = "Azure region in which regional AKS resources are deployed."
#   type        = string
# }

variable "tenant_id" {
  description = "Legacy Microsoft Entra tenant ID. Prefer module_interface.access.tenant_id for new integrations."
  type        = string
  nullable    = true
  default     = null
}

variable "node_subnet_id" {
  description = "Legacy existing subnet ID used by AKS nodes. Prefer module_interface.network_attachment.node_subnet_id for new integrations."
  type        = string
  nullable    = true
  default     = null
}

variable "kubernetes_version" {
  description = "Approved Kubernetes version. The caller may explicitly pass null to use the Azure default."
  type        = string
  nullable    = true
}

variable "sku_tier" {
  description = "Legacy AKS SKU tier. Prefer module_interface.cluster.sku_tier for new integrations."
  type        = string
  nullable    = true
  default     = null

  validation {
    condition     = var.sku_tier == null || contains(["Free", "Standard", "Premium"], var.sku_tier)
    error_message = "sku_tier must be Free, Standard, Premium, or null when module_interface is used."
  }
}

variable "support_plan" {
  description = "Legacy AKS support plan. Prefer module_interface.cluster.support_plan for new integrations."
  type        = string
  nullable    = true
  default     = null

  validation {
    condition     = var.support_plan == null || contains(["KubernetesOfficial", "AKSLongTermSupport"], var.support_plan)
    error_message = "support_plan must be KubernetesOfficial, AKSLongTermSupport, or null when module_interface is used."
  }
}

variable "admin_group_object_ids" {
  description = "Legacy Microsoft Entra administrator groups. Prefer module_interface.access.admin_group_object_ids for new integrations."
  type        = list(string)
  default     = []
}

variable "mandatory_admin_group_object_ids" {
  description = "Platform-owned Microsoft Entra administrator groups that must be retained in production."
  type        = set(string)
  default     = []

  validation {
    condition = alltrue([
      for id in var.mandatory_admin_group_object_ids :
      can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", id))
    ])
    error_message = "mandatory_admin_group_object_ids must contain valid Microsoft Entra object IDs."
  }
}

variable "azure_rbac_enabled" {
  description = "Enable Azure RBAC for Kubernetes authorization."
  type        = bool
  default     = true
}

variable "local_account_disabled" {
  description = "Disable AKS local administrator accounts."
  type        = bool
  default     = true
}

variable "cluster_profile" {
  description = "Legacy workload durability profile. Prefer module_interface.cluster.profile for new integrations."
  type        = string
  nullable    = true
  default     = null

  validation {
    condition     = var.cluster_profile == null || contains(["stateless", "stateful"], var.cluster_profile)
    error_message = "cluster_profile must be stateless, stateful, or null when module_interface is used."
  }
}

variable "compliance_profile" {
  description = "Legacy compliance baseline. Prefer module_interface.cluster.compliance_profile for new integrations."
  type        = string
  nullable    = true
  default     = null

  validation {
    condition     = var.compliance_profile == null || contains(["standard", "fips"], var.compliance_profile)
    error_message = "compliance_profile must be standard, fips, or null when module_interface is used."
  }
}

variable "module_interface" {
  description = "Normalized, composition/CAPI-ready input contract. When set, these grouped values take precedence over equivalent legacy top-level inputs."
  type = object({
    cluster = object({
      kubernetes_version  = optional(string)
      sku_tier            = string
      support_plan        = string
      profile             = string
      compliance_profile  = string
    })
    access = object({
      tenant_id                        = string
      admin_group_object_ids           = list(string)
      mandatory_admin_group_object_ids = optional(set(string), [])
      azure_rbac_enabled               = optional(bool, true)
      local_account_disabled           = optional(bool, true)
    })
    network_attachment = object({
      node_subnet_id = string
    })
  })
  default = null

  validation {
    condition = var.module_interface == null || try((
      contains(["Free", "Standard", "Premium"], var.module_interface.cluster.sku_tier) &&
      contains(["KubernetesOfficial", "AKSLongTermSupport"], var.module_interface.cluster.support_plan) &&
      contains(["stateless", "stateful"], var.module_interface.cluster.profile) &&
      contains(["standard", "fips"], var.module_interface.cluster.compliance_profile) &&
      length(var.module_interface.access.admin_group_object_ids) > 0 &&
      trimspace(var.module_interface.access.tenant_id) != "" &&
      trimspace(var.module_interface.network_attachment.node_subnet_id) != ""
    ), false)
    error_message = "module_interface must provide a valid cluster, access, and network_attachment contract."
  }
}

variable "availability_policy" {
  description = "Production availability and node OS governance. Non-AzureLinux production pools require an approved exception keyed by system or user-pool map key."
  type = object({
    criticality = string
    node_os_exceptions = optional(map(object({
      os_sku             = string
      approval_reference = string
      justification      = string
    })), {})
  })
  default = {
    criticality = "tier-3"
  }

  validation {
    condition     = contains(["tier-1", "tier-2", "tier-3"], var.availability_policy.criticality)
    error_message = "availability_policy.criticality must be tier-1, tier-2, or tier-3."
  }

  validation {
    condition = alltrue([
      for exception in values(var.availability_policy.node_os_exceptions) :
      trimspace(exception.os_sku) != "" && trimspace(exception.approval_reference) != "" && trimspace(exception.justification) != ""
    ])
    error_message = "Every node OS exception requires os_sku, approval_reference, and justification."
  }
}

variable "approved_kubernetes_versions" {
  description = "Externally approved Kubernetes versions accepted by this module. Production requires a non-empty set and an explicit kubernetes_version from the set."
  type        = set(string)
  default     = []

  validation {
    condition = alltrue([
      for version in var.approved_kubernetes_versions : can(regex("^[0-9]+\\.[0-9]+(\\.[0-9]+)?$", version))
    ])
    error_message = "approved_kubernetes_versions entries must use major.minor or major.minor.patch format."
  }
}

variable "platform_security" {
  description = "Platform security contract. FIPS is enforced on Terraform-managed Linux pools; PSA and default-deny are handed to the documented GitOps/bootstrap layer."
  type = object({
    fips_required               = optional(bool, false)
    psa_enforce_level           = optional(string, "restricted")
    default_deny_network_policy = optional(bool, true)
  })
  default = {}

  validation {
    condition     = contains(["privileged", "baseline", "restricted"], var.platform_security.psa_enforce_level)
    error_message = "platform_security.psa_enforce_level must be privileged, baseline, or restricted."
  }
}


variable "autoscaling" {
  description = "Platform capacity contract. nap maps to AKS Node Auto-Provisioning; manual uses explicit AKS pools and Cluster Autoscaler."
  type = object({
    mode                   = string
    nap_default_node_pools = optional(string, "None")
  })

  validation {
    condition     = contains(["manual", "nap"], var.autoscaling.mode)
    error_message = "autoscaling.mode must be manual or nap."
  }

  validation {
    condition     = contains(["Auto", "None"], var.autoscaling.nap_default_node_pools)
    error_message = "autoscaling.nap_default_node_pools must be Auto or None."
  }
}

variable "disruption_profile" {
  description = "Workload disruption handoff used by NAP/GitOps and workload policy. Stateful clusters require conservative consolidation."
  type = object({
    consolidation   = string
    max_unavailable = number
  })

  validation {
    condition     = contains(["aggressive", "conservative"], var.disruption_profile.consolidation)
    error_message = "disruption_profile.consolidation must be aggressive or conservative."
  }

  validation {
    condition     = var.disruption_profile.max_unavailable >= 0
    error_message = "disruption_profile.max_unavailable must be zero or greater."
  }
}

variable "private_cluster" {
  description = "Private API and API Server VNet Integration settings."

  type = object({
    enabled                             = bool
    private_dns_zone_id                 = string
    public_fqdn_enabled                 = bool
    api_server_authorized_ips           = list(string)
    api_server_vnet_integration_enabled = optional(bool, false)
    api_server_subnet_id                = optional(string)
  })

  validation {
    condition = (
      !var.private_cluster.api_server_vnet_integration_enabled ||
      try(trimspace(var.private_cluster.api_server_subnet_id), "") != ""
    )

    error_message = "API Server VNet Integration requires private_cluster.api_server_subnet_id."
  }
}

variable "kms_encryption" {
  description = "AKS etcd KMS encryption configuration."

  type = object({
    enabled                  = bool
    key_vault_key_id         = optional(string)
    key_vault_resource_id    = optional(string)
    key_vault_network_access = optional(string, "Private")
  })

  validation {
    condition = (
      !var.kms_encryption.enabled ||
      (
        var.kms_encryption.key_vault_key_id != null &&
        var.kms_encryption.key_vault_resource_id != null
      )
    )

    error_message = "Enabled KMS encryption requires key_vault_key_id and key_vault_resource_id."
  }

  validation {
    condition = (
      var.kms_encryption.key_vault_network_access == "Private"
    )

    error_message = "KMS Key Vault network access must be Private."
  }
}

variable "network" {
  description = "AKS network profile. Azure CNI Overlay and Cilium are enforced."
  type = object({
    pod_cidr          = string
    service_cidr      = string
    dns_service_ip    = string
    outbound_type     = string
    load_balancer_sku = string
    capacity = optional(object({
      max_nodes         = number
      max_pods_per_node = number
    }))
  })

  validation {
    condition = contains(
      ["loadBalancer", "managedNATGateway", "userAssignedNATGateway", "userDefinedRouting"],
      var.network.outbound_type
    )
    error_message = "Unsupported outbound_type."
  }

  validation {
    condition     = var.network.load_balancer_sku == "standard"
    error_message = "network.load_balancer_sku must be standard for this platform module."
  }

  validation {
    condition     = can(cidrhost(var.network.pod_cidr, 1)) && can(cidrhost(var.network.service_cidr, 1))
    error_message = "pod_cidr and service_cidr must be valid CIDRs."
  }

  validation {
    condition     = can(cidrhost("${var.network.dns_service_ip}/32", 0))
    error_message = "dns_service_ip must be a valid IPv4 address."
  }

  validation {
    condition = try(var.network.capacity, null) == null || (
      var.network.capacity.max_nodes > 0 &&
      var.network.capacity.max_pods_per_node > 0 &&
      var.network.capacity.max_pods_per_node <= 250
    )
    error_message = "network.capacity requires max_nodes > 0 and max_pods_per_node between 1 and 250."
  }
}

variable "system_node_pool" {
  description = "AKS default system node pool."
  type = object({
    architecture            = string
    vm_size                 = string
    min_count               = number
    max_count               = number
    node_count              = number
    zones                   = list(string)
    os_sku                  = string
    os_disk_type            = string
    os_disk_size_gb         = number
    max_pods                = number
    max_surge               = string
    only_critical_addons    = bool
    node_labels             = map(string)
    host_encryption_enabled = bool
    fips_enabled            = bool
    temporary_rotation_name = string
  })

  validation {
    condition = (
      var.system_node_pool.min_count >= 1 &&
      var.system_node_pool.max_count >= var.system_node_pool.min_count
    )
    error_message = "System pool requires min_count >= 1 and max_count >= min_count."
  }

  validation {
    condition     = contains(["amd64", "arm64"], var.system_node_pool.architecture)
    error_message = "system_node_pool.architecture must be amd64 or arm64."
  }

  validation {
    condition     = contains(["AzureLinux", "Ubuntu"], var.system_node_pool.os_sku)
    error_message = "system_node_pool.os_sku must be AzureLinux or Ubuntu."
  }

  validation {
    condition     = contains(["Ephemeral", "Managed"], var.system_node_pool.os_disk_type)
    error_message = "system_node_pool.os_disk_type must be Ephemeral or Managed."
  }

  validation {
    condition     = alltrue([for zone in var.system_node_pool.zones : contains(["1", "2", "3"], zone)]) && length(distinct(var.system_node_pool.zones)) == length(var.system_node_pool.zones)
    error_message = "system_node_pool.zones may contain distinct Azure zones 1, 2, and 3 only."
  }
}

variable "user_node_pools" {
  description = "Additional user node pools."
  type = map(object({
    name                    = string
    architecture            = string
    vm_size                 = string
    min_count               = number
    max_count               = number
    zones                   = list(string)
    os_type                 = string
    os_sku                  = string
    os_disk_type            = string
    os_disk_size_gb         = number
    max_pods                = number
    max_surge               = string
    priority                = string
    eviction_policy         = string
    spot_max_price          = number
    node_labels             = map(string)
    node_taints             = list(string)
    host_encryption_enabled = bool
    fips_enabled            = bool
    ultra_ssd_enabled       = bool
    temporary_rotation_name = string
  }))

  validation {
    condition = alltrue([
      for pool in values(var.user_node_pools) :
      pool.min_count >= 0 && pool.max_count >= pool.min_count
    ])
    error_message = "Each user pool requires min_count >= 0 and max_count >= min_count."
  }

  validation {
    condition = alltrue([
      for pool in values(var.user_node_pools) :
      contains(["Linux", "Windows"], pool.os_type)
    ])
    error_message = "Each user pool os_type must be Linux or Windows."
  }

  validation {
    condition = alltrue([
      for pool in values(var.user_node_pools) :
      contains(["AzureLinux", "Ubuntu", "Windows2019", "Windows2022"], pool.os_sku)
    ])
    error_message = "Each user pool os_sku must be AzureLinux, Ubuntu, Windows2019, or Windows2022."
  }

  validation {
    condition = alltrue([
      for pool in values(var.user_node_pools) :
      contains(["Ephemeral", "Managed"], pool.os_disk_type)
    ])
    error_message = "Each user pool os_disk_type must be Ephemeral or Managed."
  }

  validation {
    condition = alltrue([
      for pool in values(var.user_node_pools) :
      contains(["Delete", "Deallocate"], pool.eviction_policy)
    ])
    error_message = "Each user pool eviction_policy must be Delete or Deallocate."
  }

  validation {
    condition = alltrue([
      for pool in values(var.user_node_pools) :
      contains(["amd64", "arm64"], pool.architecture)
    ])
    error_message = "Each user pool architecture must be amd64 or arm64."
  }

  validation {
    condition = alltrue([
      for pool in values(var.user_node_pools) :
      can(regex("^[a-z][a-z0-9]{0,11}$", pool.name))
    ])
    error_message = "User pool names must begin with a lowercase letter and be at most 12 lowercase alphanumeric characters."
  }

  validation {
    condition = alltrue([
      for pool in values(var.user_node_pools) :
      contains(["Regular", "Spot"], pool.priority)
    ])
    error_message = "priority must be Regular or Spot."
  }

  validation {
    condition = alltrue([
      for pool in values(var.user_node_pools) :
      alltrue([for zone in pool.zones : contains(["1", "2", "3"], zone)]) && length(distinct(pool.zones)) == length(pool.zones)
    ])
    error_message = "User pool zones may contain distinct Azure zones 1, 2, and 3 only."
  }
}

variable "auto_scaler_profile" {
  description = "Optional cluster-autoscaler tuning."
  type = object({
    balance_similar_node_groups      = bool
    expander                         = string
    max_graceful_termination_sec     = number
    max_node_provisioning_time       = string
    max_unready_nodes                = number
    max_unready_percentage           = number
    new_pod_scale_up_delay           = string
    scale_down_delay_after_add       = string
    scale_down_delay_after_delete    = string
    scale_down_delay_after_failure   = string
    scan_interval                    = string
    scale_down_unneeded              = string
    scale_down_unready               = string
    scale_down_utilization_threshold = number
    empty_bulk_delete_max            = number
    skip_nodes_with_local_storage    = bool
    skip_nodes_with_system_pods      = bool
  })

  validation {
    condition     = contains(["least-waste", "most-pods", "priority", "random"], var.auto_scaler_profile.expander)
    error_message = "auto_scaler_profile.expander must be least-waste, most-pods, priority, or random."
  }

  validation {
    condition     = var.auto_scaler_profile.max_unready_percentage >= 0 && var.auto_scaler_profile.max_unready_percentage <= 100
    error_message = "auto_scaler_profile.max_unready_percentage must be between 0 and 100."
  }

  validation {
    condition     = var.auto_scaler_profile.scale_down_utilization_threshold >= 0 && var.auto_scaler_profile.scale_down_utilization_threshold <= 1
    error_message = "auto_scaler_profile.scale_down_utilization_threshold must be between 0 and 1."
  }
}

variable "maintenance" {
  description = "AKS and node OS maintenance windows in UTC."
  type = object({
    auto_upgrade = object({
      frequency   = string
      interval    = number
      duration    = number
      day_of_week = string
      start_time  = string
      utc_offset  = string
      not_allowed = optional(list(object({
        name               = string
        start              = string
        end                = string
        reason             = string
        approval_reference = string
      })), [])
    })
    node_os = object({
      frequency   = string
      interval    = number
      duration    = number
      day_of_week = string
      start_time  = string
      utc_offset  = string
      not_allowed = optional(list(object({
        name               = string
        start              = string
        end                = string
        reason             = string
        approval_reference = string
      })), [])
    })
  })

  validation {
    condition = alltrue([
      for frequency in [var.maintenance.auto_upgrade.frequency, var.maintenance.node_os.frequency] :
      contains(["Daily", "Weekly", "AbsoluteMonthly", "RelativeMonthly"], frequency)
    ])
    error_message = "Maintenance frequency must be Daily, Weekly, AbsoluteMonthly, or RelativeMonthly."
  }

  validation {
    condition = alltrue([
      for day in [var.maintenance.auto_upgrade.day_of_week, var.maintenance.node_os.day_of_week] :
      contains(["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], day)
    ])
    error_message = "Maintenance day_of_week must be Monday through Sunday."
  }

  validation {
    condition = alltrue(flatten([
      for exclusions in [var.maintenance.auto_upgrade.not_allowed, var.maintenance.node_os.not_allowed] : [
        for exclusion in exclusions :
        trimspace(exclusion.name) != "" &&
        can(timecmp(exclusion.start, exclusion.end)) &&
        timecmp(exclusion.start, exclusion.end) < 0 &&
        trimspace(exclusion.reason) != "" &&
        trimspace(exclusion.approval_reference) != ""
      ]
    ]))
    error_message = "Maintenance exclusions require name, RFC3339 start/end with start before end, reason, and approval_reference."
  }
}

variable "automatic_upgrade_channel" {
  description = "Automatic cluster upgrade channel."
  type        = string

  validation {
    condition     = contains(["none", "patch", "stable", "rapid", "node-image"], var.automatic_upgrade_channel)
    error_message = "Unsupported automatic_upgrade_channel."
  }
}

variable "node_os_upgrade_channel" {
  description = "Node OS image upgrade channel."
  type        = string

  validation {
    condition     = contains(["None", "Unmanaged", "SecurityPatch", "NodeImage"], var.node_os_upgrade_channel)
    error_message = "Unsupported node_os_upgrade_channel."
  }
}

variable "addons" {
  description = "AKS-native optional add-ons."
  type = object({
    azure_policy_enabled            = bool
    key_vault_csi_enabled           = bool
    key_vault_secret_rotation       = bool
    key_vault_rotation_interval     = string
    managed_prometheus_enabled      = bool
    container_insights_enabled      = bool
    keda_enabled                    = bool
    vertical_pod_autoscaler_enabled = bool
    image_cleaner_enabled           = bool
    image_cleaner_interval_hours    = number
    istio_enabled                   = optional(bool, false)
    istio_revisions                 = optional(list(string), [])
    istio_internal_gateway_enabled  = optional(bool, false)
    istio_external_gateway_enabled  = optional(bool, false)
    defender_enabled                = bool
  })

  validation {
    condition = (
      !var.addons.istio_enabled ||
      (length(var.addons.istio_revisions) >= 1 && length(var.addons.istio_revisions) <= 2)
    )
    error_message = "Istio requires one or two supported control-plane revisions."
  }
}

variable "storage_profile" {
  description = "AKS-managed CSI driver settings."
  type = object({
    blob_driver_enabled         = bool
    disk_driver_enabled         = bool
    file_driver_enabled         = bool
    snapshot_controller_enabled = bool
  })
}

variable "integrations" {
  description = "Existing resources integrated by resource ID."
  type = object({
    acr_id                           = optional(string)
    log_analytics_workspace_id       = optional(string)
    defender_log_analytics_id        = optional(string)
    audit_archive_storage_account_id = optional(string)
  })

  validation {
    condition = (
      !var.addons.container_insights_enabled ||
      try(var.integrations.log_analytics_workspace_id, null) != null
    )
    error_message = "Container Insights requires integrations.log_analytics_workspace_id."
  }

  validation {
    condition = (
      !var.addons.defender_enabled ||
      try(var.integrations.defender_log_analytics_id, null) != null
    )
    error_message = "Microsoft Defender requires integrations.defender_log_analytics_id."
  }
}

variable "backup_integration" {
  description = "Contract for a separate AKS Backup module. This module does not install or configure backup."
  type = object({
    enabled = bool
  })
}

variable "pki_integration" {
  description = "Placeholder contract for enterprise PKI consumers; no certificates, issuers, or trust bundles are installed by this module."
  type = object({
    enabled                     = bool
    trusted_ca_bundle_secret_id = string
    issuer_url                  = string
  })

  validation {
    condition = !var.pki_integration.enabled || (
      trimspace(var.pki_integration.trusted_ca_bundle_secret_id) != "" &&
      trimspace(var.pki_integration.issuer_url) != ""
    )
    error_message = "Enabled PKI integration requires a trusted CA bundle secret ID and issuer URL."
  }
}

variable "diagnostic_log_categories" {
  description = "AKS control-plane log categories sent to Log Analytics."
  type        = set(string)

  validation {
    condition = length(setsubtract(var.diagnostic_log_categories, toset([
      "cloud-controller-manager",
      "cluster-autoscaler",
      "csi-azuredisk-controller",
      "csi-azurefile-controller",
      "csi-snapshot-controller",
      "guard",
      "kube-apiserver",
      "kube-audit",
      "kube-audit-admin",
      "kube-controller-manager",
      "kube-scheduler"
    ]))) == 0
    error_message = "diagnostic_log_categories contains a category outside the approved AKS control-plane list."
  }
}

variable "tags" {
  description = "Playbook governance tags. Values are compact JSON strings and each must be no more than 256 characters."
  type        = map(string)

  validation {
    condition = alltrue([
      for key in ["ECS_CSF_TAG", "ECS_HPOO_TAG", "KAAS_TAG", "KAAS_EXT_TAG", "KAAS_INFRA_TAG"] :
      contains(keys(var.tags), key)
    ])
    error_message = "tags must include all five playbook tag groups."
  }

  validation {
    condition = alltrue([
      for key in ["ECS_CSF_TAG", "ECS_HPOO_TAG", "KAAS_TAG", "KAAS_EXT_TAG", "KAAS_INFRA_TAG"] :
      length(try(var.tags[key], "")) <= 256 && can(jsondecode(try(var.tags[key], "")))
    ])
    error_message = "Each mandatory playbook tag must contain valid JSON no longer than 256 characters."
  }

  validation {
    condition = alltrue([
      for key in ["mo", "esats_id", "namespace", "env", "finops_uuid", "classification", "deploy_type", "tier", "sla"] :
      contains(keys(try(jsondecode(var.tags["KAAS_TAG"]), {})), key)
      ]) && alltrue([
      for key in ["persistence", "storage_type", "ingress", "network_policy"] :
      contains(keys(try(jsondecode(var.tags["KAAS_INFRA_TAG"]), {})), key)
    ]) && contains(keys(try(jsondecode(var.tags["KAAS_EXT_TAG"]), {})), "dl")
    error_message = "KAAS_TAG, KAAS_EXT_TAG, and KAAS_INFRA_TAG must include the playbook-mandatory fields."
  }
}
variable "manage_role_assignments" {
  description = "Whether this module creates Azure RBAC role assignments required by AKS."
  type        = bool
}

variable "managed_identities" {
  description = "Controls whether this module creates the AKS control-plane and kubelet user-assigned identities or reuses existing identities."
  type = object({
    create                    = optional(bool, true)
    control_plane_identity_id = optional(string)
    kubelet_identity_id       = optional(string)
  })
  default = {}

  validation {
    condition = try(var.managed_identities.create, true) || (
      try(trimspace(var.managed_identities.control_plane_identity_id) != "", false) &&
      try(trimspace(var.managed_identities.kubelet_identity_id) != "", false)
    )
    error_message = "When managed_identities.create is false, control_plane_identity_id and kubelet_identity_id must both be supplied."
  }

  validation {
    condition = try(var.managed_identities.create, true) || alltrue([
      for id in [
        try(var.managed_identities.control_plane_identity_id, ""),
        try(var.managed_identities.kubelet_identity_id, "")
      ] : can(regex("(?i)^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\\.ManagedIdentity/userAssignedIdentities/[^/]+$", id))
    ])
    error_message = "Existing managed identity IDs must be complete Azure user-assigned identity resource IDs."
  }
}
