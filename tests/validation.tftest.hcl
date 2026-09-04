mock_provider "azurerm" {}

variables {
  naming = {
    platform     = "kaas"
    maintain_org = "cdp"
    environment  = "dev"
    region_code  = "va"
  }
  resource_group = {
    create   = true
    name     = "rg-validation-dev"
    location = "eastus2"
  }
  tenant_id          = "00000000-0000-0000-0000-000000000000"
  node_subnet_id     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet-platform/subnets/snet-aks"
  kubernetes_version = null
  sku_tier           = "Standard"
  support_plan       = "KubernetesOfficial"

  admin_group_object_ids = [
    "00000000-0000-0000-0000-000000000001"
  ]

  cluster_profile         = "stateless"
  compliance_profile      = "standard"
  kms_encryption          = { enabled = false }
  manage_role_assignments = true
  autoscaling             = { mode = "nap" }
  disruption_profile      = { consolidation = "aggressive", max_unavailable = 2 }
  private_cluster = {
    enabled                   = true
    private_dns_zone_id       = "System"
    public_fqdn_enabled       = false
    api_server_authorized_ips = []
  }
  network = {
    pod_cidr          = "10.244.0.0/16"
    service_cidr      = "10.0.0.0/20"
    dns_service_ip    = "10.0.0.10"
    outbound_type     = "loadBalancer"
    load_balancer_sku = "standard"
    network_mode      = null
  }
  system_node_pool = {
    architecture            = "amd64"
    vm_size                 = "Standard_D2s_v5"
    min_count               = 1
    max_count               = 3
    node_count              = 1
    zones                   = []
    os_sku                  = "AzureLinux"
    os_disk_type            = "Ephemeral"
    os_disk_size_gb         = 60
    max_pods                = 110
    max_surge               = "1"
    only_critical_addons    = true
    node_labels             = {}
    host_encryption_enabled = false
    fips_enabled            = false
    temporary_rotation_name = "systemtmp"
  }
  user_node_pools = {}
  auto_scaler_profile = {
    balance_similar_node_groups      = true, expander = "least-waste", max_graceful_termination_sec = 600
    max_node_provisioning_time       = "15m", max_unready_nodes = 3, max_unready_percentage = 45
    new_pod_scale_up_delay           = "0s", scale_down_delay_after_add = "10m", scale_down_delay_after_delete = "10s"
    scale_down_delay_after_failure   = "3m", scan_interval = "10s", scale_down_unneeded = "10m", scale_down_unready = "20m"
    scale_down_utilization_threshold = 0.5, empty_bulk_delete_max = 10
    skip_nodes_with_local_storage    = true, skip_nodes_with_system_pods = true
  }
  maintenance = {
    auto_upgrade = { frequency = "Weekly", interval = 1, duration = 4, day_of_week = "Sunday", start_time = "02:00", utc_offset = "+00:00" }
    node_os      = { frequency = "Weekly", interval = 1, duration = 4, day_of_week = "Sunday", start_time = "06:00", utc_offset = "+00:00" }
  }
  automatic_upgrade_channel = "patch"
  node_os_upgrade_channel   = "NodeImage"
  addons = {
    azure_policy_enabled           = true, key_vault_csi_enabled = true, key_vault_secret_rotation = true
    key_vault_rotation_interval    = "2m", managed_prometheus_enabled = false, container_insights_enabled = false
    keda_enabled                   = true, vertical_pod_autoscaler_enabled = false, image_cleaner_enabled = true
    image_cleaner_interval_hours   = 48, istio_enabled = false, istio_revisions = []
    istio_internal_gateway_enabled = false, istio_external_gateway_enabled = false, defender_enabled = false
  }
  storage_profile = {
    blob_driver_enabled = false, disk_driver_enabled = true, file_driver_enabled = true, snapshot_controller_enabled = true
  }
  integrations              = { acr_id = null, log_analytics_workspace_id = null, defender_log_analytics_id = null }
  backup_integration        = { enabled = false }
  pki_integration           = { enabled = false, trusted_ca_bundle_secret_id = "", issuer_url = "" }
  diagnostic_log_categories = ["kube-apiserver", "kube-audit"]

  tags = {
    ECS_CSF_TAG    = jsonencode({ SIS_RESP_ORG = "ENT-STRATA-KAAS-EIC-AZ", SIS_CONTACT_BEMS_ID = "0000000", SIS_ASSET_OWNER_BEMS_ID = "0000000", SIS_ENVIRONMENT_ID = "DEVELOPMENT", SIS_ASE_ID = "strata-k8s-azure", LAPIC_ADMIN_ACCOUNT = "platform@example.com" })
    ECS_HPOO_TAG   = jsonencode({ HPOO_CAGASSIGNMENTGROUP = "ENT-STRATA-KAAS-EIC-AZ", HPOO_REQUESTORBEMSID = "0000000", HPOO_SISRESPONSIBLEMANAGER = "0000000", HPOO_SISVENDORSUPPORT = "BOEING" })
    KAAS_TAG       = jsonencode({ mo = "cdp", esats_id = "3678542", namespace = "cdp-platform", env = "dev", finops_uuid = "REPLACE", classification = "internal", deploy_type = "terraform", tier = "tier-3", sla = "none" })
    KAAS_EXT_TAG   = jsonencode({ dl = "platform@example.com" })
    KAAS_INFRA_TAG = jsonencode({ persistence = "stateless", storage_type = "none", ingress = "internal", network_policy = "enabled" })
  }
}

run "valid_module_contract" {
  command = plan

  assert {
    condition     = azurerm_kubernetes_cluster.this.network_profile[0].network_data_plane == "cilium"
    error_message = "Cilium must be the enforced network data plane."
  }

  assert {
    condition     = azurerm_kubernetes_cluster.this.oidc_issuer_enabled
    error_message = "OIDC must be enabled."
  }

  assert {
    condition     = azurerm_kubernetes_cluster.this.workload_identity_enabled
    error_message = "Workload Identity must be enabled."
  }

  assert {
    condition     = azurerm_role_assignment.control_plane_kubelet_identity_operator[0].role_definition_name == "Managed Identity Operator"
    error_message = "The control-plane identity must be able to assign the custom kubelet identity."
  }
}

run "existing_resource_group_contract" {
  command = plan

  variables {
    resource_group = {
      create = false
      name   = "rg-validation-existing"
    }
  }

  assert {
    condition     = length(azurerm_resource_group.this) == 0
    error_message = "The module must not create a resource group when create is false."
  }

  assert {
    condition     = length(data.azurerm_resource_group.existing) == 1
    error_message = "The module must look up the supplied resource group when create is false."
  }
}

run "valid_production_security_baseline" {
  command = plan

  variables {
    naming = {
      platform     = "kaas"
      maintain_org = "cdp"
      environment  = "prod"
      region_code  = "va"
    }
    admin_group_object_ids           = ["00000000-0000-0000-0000-000000000001"]
    mandatory_admin_group_object_ids = ["00000000-0000-0000-0000-000000000001"]
    kms_encryption = {
      enabled                  = true
      key_vault_key_id         = "https://kv-platform-prod.vault.azure.net/keys/aks-etcd-encryption/00000000000000000000000000000000"
      key_vault_resource_id    = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-security/providers/Microsoft.KeyVault/vaults/kv-platform-prod"
      key_vault_network_access = "Private"
    }
    integrations = {
      acr_id                           = null
      log_analytics_workspace_id       = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-monitor/providers/Microsoft.OperationalInsights/workspaces/law-prod"
      defender_log_analytics_id        = null
      audit_archive_storage_account_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-monitor/providers/Microsoft.Storage/storageAccounts/stauditprod"
    }
    diagnostic_log_categories = ["kube-apiserver", "kube-audit", "kube-audit-admin"]
    tags = {
      ECS_CSF_TAG    = jsonencode({ SIS_RESP_ORG = "ENT-STRATA-KAAS-EIC-AZ", SIS_CONTACT_BEMS_ID = "0000000", SIS_ASSET_OWNER_BEMS_ID = "0000000", SIS_ENVIRONMENT_ID = "PRODUCTION", SIS_ASE_ID = "strata-k8s-azure", LAPIC_ADMIN_ACCOUNT = "platform@example.com" })
      ECS_HPOO_TAG   = jsonencode({ HPOO_CAGASSIGNMENTGROUP = "ENT-STRATA-KAAS-EIC-AZ", HPOO_REQUESTORBEMSID = "0000000", HPOO_SISRESPONSIBLEMANAGER = "0000000", HPOO_SISVENDORSUPPORT = "BOEING" })
      KAAS_TAG       = jsonencode({ mo = "cdp", esats_id = "3678542", namespace = "cdp-platform", env = "prod", finops_uuid = "REPLACE", classification = "confidential", deploy_type = "terraform", tier = "tier-1", sla = "99.9" })
      KAAS_EXT_TAG   = jsonencode({ dl = "platform@example.com" })
      KAAS_INFRA_TAG = jsonencode({ persistence = "stateless", storage_type = "none", ingress = "internal", network_policy = "enabled" })
    }
  }

  assert {
    condition     = azurerm_kubernetes_cluster.this.private_cluster_enabled
    error_message = "Production must use a private API endpoint."
  }

  assert {
    condition     = azurerm_kubernetes_cluster.this.key_management_service[0].key_vault_network_access == "Private"
    error_message = "Production KMS must use private Key Vault access."
  }

  assert {
    condition     = azurerm_monitor_diagnostic_setting.this[0].storage_account_id != null
    error_message = "Production audit logs must have an archival destination."
  }
}

run "reject_production_public_api" {
  command = plan

  variables {
    naming = {
      platform     = "kaas"
      maintain_org = "cdp"
      environment  = "prod"
      region_code  = "va"
    }
    private_cluster = {
      enabled                   = false
      private_dns_zone_id       = "System"
      public_fqdn_enabled       = false
      api_server_authorized_ips = []
    }
  }

  expect_failures = [azurerm_kubernetes_cluster.this]
}

run "reject_production_missing_security_contract" {
  command = plan

  variables {
    naming = {
      platform     = "kaas"
      maintain_org = "cdp"
      environment  = "prod"
      region_code  = "va"
    }
  }

  expect_failures = [azurerm_kubernetes_cluster.this]
}
