# AKS Terraform Module — Detailed End-to-End Code Walkthrough

## 1. Repository entry points

The root directory is one Terraform module. Files split concerns only; they are evaluated as a single configuration.

| File | Responsibility |
|---|---|
| `versions.tf` | Terraform and AzureRM provider constraints |
| `variables.tf` | Public input contract and input-level validation |
| `locals.tf` | Effective normalized inputs, derived names, readiness calculations, CIDR math |
| `resource_group.tf` | Create or reuse AKS resource group |
| `identities.tf` | Create/reuse control-plane and kubelet identities and related RBAC |
| `iam.tf` | Additional integration role assignments |
| `main.tf` | AKS cluster, profiles, add-ons, lifecycle preconditions |
| `node_pools.tf` | Terraform-managed user node pools for manual mode |
| `diagnostics.tf` | AKS diagnostic routing |
| `outputs.tf` | Raw integration outputs plus normalized/readiness contracts |
| `tests/*.tftest.hcl` | Mock-provider positive/negative contract tests |

## 2. Input resolution

Historically the module accepted several foundational values as top-level variables. To avoid a breaking migration while satisfying a normalized composition interface, `module_interface` was added.

`locals.tf` calculates `effective_*` values. If `module_interface` is null, legacy values are used. If it is supplied, the grouped values take precedence. All AKS resource references use the effective values for tenant, subnet, Kubernetes version, SKU tier, support plan, cluster profile, compliance profile, administrator groups, Azure RBAC, and local-account posture.

This allows existing consumers to continue working while CAPI/composition consumers move to a stable object contract.

## 3. Naming flow

`naming` is restricted to approved KaaS segments. `locals.tf` derives the AKS cluster name, managed identity names, node resource-group name, and diagnostic setting name.

`local.naming_readiness` evaluates Azure/KaaS character and length constraints. The AKS lifecycle requires `local.all_module_owned_names_valid`, so bad module-generated names fail before deployment. Existing externally supplied resource names are intentionally not rewritten.

## 4. Resource group flow

`resource_group.create` controls ownership. When true, `azurerm_resource_group.this` is created and becomes the effective resource group. When false, the module reads the existing group. `local.resource_group_name` and `local.location` hide that distinction from the rest of the module.

The node resource group remains AKS-managed but its requested name is derived centrally.

## 5. Managed identity flow

`managed_identities.create` decides whether the module creates the control-plane and kubelet user-assigned identities or looks up caller-supplied IDs.

The effective identity ID/client/principal values are normalized in `locals.tf`. AKS uses the control-plane identity in its `identity` block and the supplied kubelet identity in `kubelet_identity`.

When `manage_role_assignments` is enabled, Terraform creates the scoped permissions required for network operations, kubelet identity assignment, optional API-server subnet integration, KMS integration, and ACR pull. Existing identity lifecycle and enterprise access governance remain external.

## 6. AKS cluster resource

`main.tf` creates `azurerm_kubernetes_cluster.this`.

### Core lifecycle

The resource receives the effective Kubernetes version, SKU tier, support plan, resource group, node resource group, and identity contract.

### Authentication and authorization

Local accounts are controlled through the effective contract. Kubernetes authorization uses the Microsoft Entra/Azure RBAC block with the effective tenant and administrator groups. OIDC issuer and Workload Identity are always enabled as platform invariants.

### API endpoint

`private_cluster` controls private API, private DNS zone selection, public FQDN behavior, public authorized-IP ranges for non-private cases, and optional API Server VNet Integration.

Production preconditions require a private endpoint, disabled public FQDN, and no public authorized-IP ranges.

## 7. System node pool

The `default_node_pool` block maps `system_node_pool` into AKS. It controls VM SKU, subnet, counts, zones, OS SKU, disk type/size, max pods, critical-add-on scheduling, labels, host encryption, FIPS, temporary rotation name, and surge behavior.

With manual autoscaling, min/max counts are passed to Cluster Autoscaler. With NAP, the fixed system pool remains while NAP capacity is externally composed through GitOps.

Production requires at least two distinct valid zones and AzureLinux unless an approved OS exception is present.

## 8. User node pools

`node_pools.tf` creates user pools only when `autoscaling.mode == "manual"`. Each pool has explicit architecture, OS, disk, pod, priority, Spot, label/taint, host-encryption, FIPS, UltraSSD, and upgrade settings.

NAP mode rejects Terraform-managed user pools to prevent two controllers from owning worker capacity simultaneously.

Stateful mode rejects Terraform-managed Spot pools.

## 9. Autoscaling and disruption

`autoscaling.mode` is either `manual` or `nap`.

- `manual` enables the AKS Cluster Autoscaler contract and Terraform user pools.
- `nap` maps to AKS Node Auto-Provisioning and exposes whether GitOps must reconcile NAP `NodePool` and `AKSNodeClass` resources.

`disruption_profile` is a platform handoff. Stateful requires conservative consolidation; stateless may use aggressive consolidation.

## 10. Availability and OS policy

`availability_policy` contains criticality and a map of approved node OS exceptions.

For production:

- Free SKU is rejected;
- at least two system zones are mandatory;
- AzureLinux is the default for all Terraform-managed pools;
- Ubuntu/Windows requires matching exception metadata.

The exception metadata is not sent to Azure. It is governance evidence exposed through `availability_readiness`.

## 11. Network implementation

The AKS network profile is fixed to Azure CNI Overlay with Cilium for both data plane and network policy. Callers choose pod CIDR, service CIDR, DNS service IP, outbound type, and Standard load balancer.

`locals.tf` converts IPv4 addresses into integers:

```text
A.B.C.D -> A*16777216 + B*65536 + C*256 + D
```

Prefix lengths determine range size with `2^(32-prefix)`. From these values the module derives pod/service range starts and ends and proves that the ranges do not overlap.

The DNS IP must be greater than the service-network address and less than the service broadcast/end address.

### Pod capacity

Manual-mode capacity is:

```text
system.max_count * system.max_pods
+ sum(user_pool.max_count * user_pool.max_pods)
```

NAP worker limits are outside Terraform, so production NAP callers must explicitly declare `network.capacity.max_nodes` and `network.capacity.max_pods_per_node`. The module multiplies them and ensures the pod CIDR has at least that many addresses.

The resulting facts are emitted through `network_readiness`.

## 12. Upgrade/version governance

`approved_kubernetes_versions` is populated by the external release process. Production requires an explicit requested version and membership in that set.

Safe production cluster channels are `patch` and `stable`. Safe production node OS channels are `NodeImage` and `SecurityPatch`.

The regular auto-upgrade and node-OS maintenance windows are passed directly to AKS.

Each window also accepts typed `not_allowed` entries with name, start, end, reason, and approval reference. Azure receives only start/end because those are provider fields; governance metadata remains available in outputs and source review.

`effective_kubernetes_version` reads the effective version from the AKS resource, while `upgrade_readiness` exposes requested, effective, approved versions, channels, and exclusions.

## 13. Storage and CSI

The AKS `storage_profile` explicitly controls Blob, Disk, File CSI drivers and snapshot controller.

Stateful guardrails require Disk CSI, snapshot controller, and the external backup handoff. The module does not create StorageClasses, PVCs, backup vaults, backup schedules, or restore workflows.

`storage_readiness` makes this separation visible to consumers.

## 14. KMS and secrets

`kms_encryption` optionally configures the AKS key-management-service block. Production requires it enabled and requires private Key Vault network access.

Key Vault identity/permissions are scoped in the identity layer when role assignment management is enabled. Key creation, rotation, recovery, network endpoint lifecycle, and security approval remain external.

The AKS Key Vault Secrets Store CSI add-on is independently controlled by `addons.key_vault_csi_enabled` and its rotation settings.

## 15. Monitoring and audit

Container Insights, managed Prometheus, Defender, and diagnostic control-plane logging are separately selectable.

`diagnostics.tf` creates one diagnostic setting when either Log Analytics or archive storage is supplied. Only approved AKS categories are accepted.

Production requires a Log Analytics workspace, an archival storage destination, and the mandatory audit categories.

The module routes logs but does not own SIEM parsing, retention, alerting, or archive lifecycle.

## 16. Optional AKS add-ons

The module can enable Azure Policy add-on, Key Vault CSI, KEDA, VPA, Image Cleaner, managed Prometheus, Container Insights, Defender, and AKS-managed Istio.

Enabling an AKS add-on does not move enterprise configuration ownership into this module. For example, policy initiatives/admission content and GitOps workload definitions remain external.

## 17. Stateful/stateless behavior

`cluster_profile` is a policy signal rather than a second module.

Stateful requires:

- Disk CSI;
- snapshot controller;
- external backup handoff;
- multi-zone system pool;
- conservative disruption;
- no Terraform-managed Spot pool.

Stateless is NAP-friendly, may use more aggressive disruption, and does not require backup handoff.

## 18. FIPS/compliance behavior

`compliance_profile == "fips"` requires the platform FIPS contract plus FIPS and host encryption on the fixed system pool. In manual mode, every Terraform-managed Linux user pool must also meet those requirements.

PSA and default-deny values are exposed as the security contract but enforced through the external bootstrap/GitOps layer, keeping admission-policy ownership separate from infrastructure provisioning.

## 19. Terraform lifecycle preconditions

The AKS resource lifecycle is the main fail-closed enforcement point. It verifies:

- governance-tag alignment;
- valid effective normalized contract;
- production security controls;
- Premium/LTS compatibility;
- production SLA tier, zones and node OS policy;
- approved version and safe upgrade channels;
- network non-overlap, DNS placement and pod capacity;
- autoscaling/NAP ownership constraints;
- FIPS requirements;
- stateful storage/backup/zone/disruption/Spot constraints;
- module-owned naming readiness.

This design keeps interdependent validations close to the resource they protect and produces clear plan-time failures.

## 20. Outputs and consumer contracts

Raw outputs remain available for existing integrations, including cluster ID/name, resource group, identities, FQDN, OIDC issuer, node pools, backup handoff and connect command.

Story-specific readiness outputs provide targeted evidence:

- `production_security_readiness`;
- `availability_readiness`;
- `upgrade_readiness`;
- `network_readiness`;
- `storage_readiness`;
- `naming_readiness`.

`aks_readiness` consolidates these topics for release/adoption evidence.

`normalized_cluster_contract` is the preferred composition facade for future integrations. It groups cluster, identity, endpoint, network, node-pool, version and readiness facts without forcing consumers to understand the layout of every AzureRM resource.

## 21. Tests

`tests/validation.tftest.hcl` retains the original baseline tests and Story 1 security tests.

`tests/stories_1_9.tftest.hcl` adds focused coverage for:

- consolidated readiness;
- Free-production rejection;
- single-zone-production rejection;
- OS exception enforcement and approved exception path;
- unapproved version and unsafe upgrade channel rejection;
- typed maintenance exclusions;
- CIDR overlap, DNS placement and capacity rejection;
- stateful storage/backup failures;
- compliant/noncompliant naming;
- normalized-interface precedence and output contract.

Mock AzureRM provider usage keeps contract tests focused on Terraform behavior rather than requiring real Azure resources.

## 22. CI and release flow

`.gitlab-ci.yml` provides stages for validation, lint, security, test, and release evidence. `scripts/quality-gates.sh` gives developers a local equivalent for Terraform formatting/validation/tests with optional TFLint and Trivy when installed.

State files, plan files, `.terraform` directories, and real `terraform.tfvars` are ignored and excluded from the release package.

## 23. Migration to the normalized interface

Existing consumers can continue to use top-level `tenant_id`, `node_subnet_id`, `sku_tier`, `support_plan`, `cluster_profile`, `compliance_profile`, and access inputs.

New consumers should populate `module_interface`. During migration, do not set contradictory legacy and grouped values; the grouped contract intentionally wins. After downstream consumers adopt the normalized contract, a future major module version can remove the legacy compatibility fields through a controlled deprecation process.

## 24. Operational verification after apply

After a real deployment, validate the Terraform outputs and Azure/Kubernetes runtime state. Typical evidence includes `az aks show`, `kubectl get nodes -L topology.kubernetes.io/zone`, `kubectl get csidrivers`, diagnostic setting inspection, private DNS resolution, and a controlled test PVC for stateful readiness. Runtime application and enterprise-service evidence remains owned by the corresponding platform layer.
