# Environment tfvars reference

The development and production `terraform.tfvars.example` files intentionally contain values only. This README is the option catalog and operating guide for both templates.

## Core choices

| Input | Supported values / instructions |
|---|---|
| `kubernetes_version` | `null` for the Azure regional default, or an approved version string available in the target region. |
| `cluster_profile` | `stateless` or `stateful`. Stateful adds storage, snapshot, backup, zone, disruption, and Spot guardrails. |
| `compliance_profile` | `standard` or `fips`. FIPS requires the security contract, pool FIPS, and host encryption. |
| `resource_group.create` | `true` to create the group; `false` to reuse it. Supply `location` only when creating. |
| `sku_tier` | `Free`, `Standard`, or `Premium`. |
| `support_plan` | `KubernetesOfficial` or `AKSLongTermSupport`; long-term support requires `Premium`. |
| `automatic_upgrade_channel` | `none`, `patch`, `stable`, `rapid`, or `node-image`. |
| `node_os_upgrade_channel` | `None`, `Unmanaged`, `SecurityPatch`, or `NodeImage`. The `node-image` cluster channel requires `NodeImage`. |

## Autoscaling and disruption

```hcl
autoscaling = {
  mode = "nap" # or "manual"
}
```

- `nap` enables AKS Node Auto-Provisioning. `user_node_pools` must be empty. GitOps must apply an approved `NodePool` and `AKSNodeClass` when the platform default of `None` is used.
- `manual` enables Cluster Autoscaler and creates the pools in `user_node_pools`.
- Advanced `nap_default_node_pools` values are `None` or `Auto`; omit it to use `None`.
- `disruption_profile.consolidation` accepts `aggressive` or `conservative`. Stateful requires `conservative`.
- `max_unavailable` is an integer of zero or greater. Use zero or one for conservative stateful disruption.

Cluster Autoscaler `expander` accepts `least-waste`, `most-pods`, `priority`, or `random`. Duration values use forms such as `10s`, `3m`, and `1h`. `max_unready_percentage` is 0-100 and `scale_down_utilization_threshold` is 0-1. Other count fields are non-negative. Boolean autoscaler fields accept `true` or `false`.

## Maintenance

Both maintenance objects accept `Daily`, `Weekly`, `AbsoluteMonthly`, or `RelativeMonthly`. Use Monday through Sunday where applicable, `HH:mm` start time, signed `+/-HH:mm` UTC offset, and AKS-supported integer interval/duration values. Frequency-specific Azure requirements still apply.

## Identity and networking

| Input | Supported values / instructions |
|---|---|
| `admin_group_object_ids` | One or more Microsoft Entra group object IDs. |
| `azure_rbac_enabled` | `true` or `false`; platform baseline is `true`. |
| `local_account_disabled` | `true` or `false`; platform baseline is `true`. |
| `pod_cidr`, `service_cidr` | Valid, non-overlapping CIDRs. |
| `dns_service_ip` | Valid IPv4 address inside the service CIDR. |
| `outbound_type` | `loadBalancer`, `managedNATGateway`, `userAssignedNATGateway`, or `userDefinedRouting`. |
| `load_balancer_sku` | `standard` for this platform contract; NAP requires it. |
| `network_mode` | `null` or a platform-approved Azure CNI mode supported by AzureRM/AKS. |
| `private_cluster.enabled` | `true` or `false`. |
| `private_dns_zone_id` | `System`, `None`, or an existing private DNS zone resource ID for private clusters. |
| `public_fqdn_enabled` | `true` or `false` for private clusters. |
| `api_server_authorized_ips` | Public API CIDR allowlist; use an empty list for a private-only API. |

Azure CNI Overlay and Cilium are enforced and are not selectable inputs.

## Security

| Input | Supported values / instructions |
|---|---|
| `fips_required` | `true` or `false`; must be true with `compliance_profile = "fips"`. |
| `psa_enforce_level` | `restricted`, `baseline`, or `privileged`. |
| `default_deny_network_policy` | `true` or `false`; bootstrap/GitOps owns enforcement. |

The module installs neither Kyverno nor Gatekeeper. Service mesh is optional and disabled by default.

## Node pools

System and Manual user pools require `architecture = "amd64"` or `"arm64"`. The VM SKU must match that architecture and be approved and available in-region. Do not add the reserved `kubernetes.io/arch` label; Kubernetes supplies it.

| Pool field | Supported values / instructions |
|---|---|
| `name` | Lowercase alphanumeric AKS pool name, at most 12 characters for user pools. |
| `vm_size` | Approved regional SKU matching architecture, quota, encryption, FIPS, and disk requirements. |
| `min_count`, `max_count` | System minimum is at least 1; user minimum may be 0; maximum must be at least minimum. |
| `node_count` | Fixed system-pool count used in NAP mode. |
| `zones` | Empty list or available zones such as `1`, `2`, `3`; stateful requires at least two system zones. |
| `os_type` | User pools: `Linux` or `Windows`; Windows is not supported with NAP. |
| `os_sku` | System: `AzureLinux` or `Ubuntu`. User: those plus `Windows2019` or `Windows2022`, subject to AKS support. |
| `os_disk_type` | `Ephemeral` or `Managed`; stateless prefers Ephemeral. |
| `os_disk_size_gb` | Positive size supported by the VM SKU and disk type. |
| `max_pods` | AKS-supported integer compatible with the network design. |
| `max_surge` | Positive integer string or percentage such as `33%`. |
| `only_critical_addons` | `true` or `false`; true is recommended for the system pool. |
| `priority` | `Regular` or `Spot`; stateful rejects Terraform-managed Spot pools. |
| `eviction_policy` | `Delete` or `Deallocate`; use `Delete` for Regular pools. |
| `spot_max_price` | `-1` or a positive maximum hourly Spot price. |
| `node_labels`, `node_taints` | Custom workload metadata; never use reserved label prefixes. |
| `host_encryption_enabled`, `fips_enabled`, `ultra_ssd_enabled` | `true` or `false`; validate regional/SKU support. FIPS compliance requires the first two. |
| `temporary_rotation_name` | Valid lowercase temporary AKS pool name used during rotation. |

## Add-ons and storage

All `*_enabled` add-on and storage fields accept `true` or `false`.

- Key Vault rotation requires Key Vault CSI; its interval uses a duration such as `2m` or `1h`.
- Container Insights requires `log_analytics_workspace_id`; Defender requires `defender_log_analytics_id`.
- Image Cleaner interval is a positive number of hours.
- Istio is disabled by default. When enabled, provide one or two AKS-supported revisions and independently choose internal/external gateways.
- Stateful requires Azure Disk CSI and the snapshot controller. Blob and File CSI remain selectable.

## External integrations, diagnostics, and governance

Use `null` for a disabled existing-resource integration or provide the complete resource ID:

- `acr_id`: existing registry; the module creates only `AcrPull`.
- `log_analytics_workspace_id`: required by Container Insights and diagnostics.
- `defender_log_analytics_id`: required when Defender is enabled.
- `backup_integration.enabled`: `true` or `false`; stateful requires true, but backup resources remain separate.
- `pki_integration.enabled`: `true` or `false`; when true, provide both the trusted CA bundle secret reference and issuer URL. No PKI components are installed here.

Approved diagnostic categories are `kube-apiserver`, `kube-audit`, `kube-audit-admin`, `kube-controller-manager`, `kube-scheduler`, `cluster-autoscaler`, `guard`, `cloud-controller-manager`, `csi-azuredisk-controller`, `csi-azurefile-controller`, and `csi-snapshot-controller`. Select any subset.

Required tags are `ApplicationId`, `CostCenter`, `Environment`, `Owner`, `ManagedBy`, `EsatId`, `Platform`, and `DataClassification`.

## Configure and deploy

1. Copy the appropriate `terraform.tfvars.example` to `terraform.tfvars`.
2. Replace every placeholder ID, name, CIDR, tag, region, version, SKU, workspace, ACR, DNS, backup, and PKI value.
3. Select the cluster/compliance profiles, autoscaling, PSA, architecture, egress, pools, storage, add-ons, and diagnostics using this reference.
4. For NAP, prepare GitOps `NodePool` and `AKSNodeClass` policy. For Manual, populate `user_node_pools` using the object contract in `variables.tf`.
5. Validate availability, quota, zones, FIPS/encryption support, CIDRs, permissions, and private connectivity.
6. Run `terraform init`, `terraform fmt -check -recursive`, `terraform validate`, and `terraform plan`.
7. Review replacements, identities, RBAC, routing, add-ons, diagnostics, and profile guardrails before applying.
