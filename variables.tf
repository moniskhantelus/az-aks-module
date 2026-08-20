variable "name" {
  description = "AKS cluster name."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9_-]{1,61}[A-Za-z0-9]$", var.name))
    error_message = "name must contain 3-63 valid AKS name characters."
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

variable "tenant_id" {
  description = "Microsoft Entra tenant ID."
  type        = string
}

variable "node_subnet_id" {
  description = "Existing subnet ID used by AKS nodes."
  type        = string
}

variable "kubernetes_version" {
  description = "Approved Kubernetes version. The caller may explicitly pass null to use the Azure default."
  type        = string
  nullable    = true
}

variable "sku_tier" {
  description = "AKS SKU tier."
  type        = string

  validation {
    condition     = contains(["Free", "Standard", "Premium"], var.sku_tier)
    error_message = "sku_tier must be Free, Standard, or Premium."
  }
}

variable "support_plan" {
  description = "AKS support plan."
  type        = string

  validation {
    condition     = contains(["KubernetesOfficial", "AKSLongTermSupport"], var.support_plan)
    error_message = "support_plan must be KubernetesOfficial or AKSLongTermSupport."
  }
}

variable "admin_group_object_ids" {
  description = "Microsoft Entra group object IDs that administer Kubernetes through Azure RBAC."
  type        = list(string)

  validation {
    condition     = length(var.admin_group_object_ids) > 0
    error_message = "At least one administrator group object ID is required."
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
  description = "Workload durability profile. Stateless favors elastic capacity; stateful enforces storage, backup, conservative-disruption, and zone guardrails."
  type        = string

  validation {
    condition     = contains(["stateless", "stateful"], var.cluster_profile)
    error_message = "cluster_profile must be stateless or stateful."
  }
}

variable "compliance_profile" {
  description = "Compliance baseline. fips requires FIPS-enabled, host-encrypted Terraform-managed Linux pools."
  type        = string

  validation {
    condition     = contains(["standard", "fips"], var.compliance_profile)
    error_message = "compliance_profile must be standard or fips."
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
  description = "Private API settings."
  type = object({
    enabled                   = bool
    private_dns_zone_id       = string
    public_fqdn_enabled       = bool
    api_server_authorized_ips = list(string)
  })
}

variable "network" {
  description = "AKS network profile. Azure CNI Overlay and Cilium are enforced."
  type = object({
    pod_cidr          = string
    service_cidr      = string
    dns_service_ip    = string
    outbound_type     = string
    load_balancer_sku = string
    network_mode      = string
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
    })
    node_os = object({
      frequency   = string
      interval    = number
      duration    = number
      day_of_week = string
      start_time  = string
      utc_offset  = string
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
    acr_id                     = string
    log_analytics_workspace_id = string
    defender_log_analytics_id  = string
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
  description = "Enterprise tags."
  type        = map(string)

  validation {
    condition = alltrue([
      for key in ["ApplicationId", "CostCenter", "Environment", "Owner", "ManagedBy", "EsatId", "Platform", "DataClassification"] :
      contains(keys(var.tags), key)
    ])
    error_message = "tags must include ApplicationId, CostCenter, Environment, Owner, ManagedBy, EsatId, Platform, and DataClassification."
  }
}
