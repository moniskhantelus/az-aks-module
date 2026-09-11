# AKS Terraform Module — End-to-End Architecture

## 1. Purpose

This module provisions and governs an Azure Kubernetes Service cluster as a reusable KaaS platform component. It encodes the infrastructure controls needed to produce a predictable AKS cluster while keeping enterprise services and day-two workload composition outside the module boundary.

The architecture follows four principles:

1. **Fail closed for production.** Production-specific security, availability, lifecycle, networking, and storage requirements are Terraform preconditions rather than documentation-only recommendations.
2. **Reuse enterprise services.** Existing network, DNS, Key Vault, Log Analytics, ACR, PKI, and backup platforms are referenced or handed off rather than duplicated.
3. **Separate foundation from workload composition.** AKS infrastructure is created here; StorageClasses, GitOps workloads, policy bundles, PDBs, application backup schedules, and runtime admission configuration remain external.
4. **Expose a normalized contract.** Outputs provide a stable cluster/identity/endpoint/network/node/version/readiness facade suitable for composition and future CAPI/CAPZ integration.

## 2. End-to-end component flow

```text
Onboarding / composition inputs
        |
        v
+----------------------------+
| KaaS AKS Terraform Module  |
|----------------------------|
| Naming + governance        |
| Normalized input contract  |
| Production guardrails      |
| Identity selection/reuse   |
| AKS cluster                |
| System/user pools          |
| Network profile            |
| CSI/storage profile        |
| KMS / diagnostics hooks    |
| Maintenance governance     |
| Readiness calculations     |
+----------------------------+
   |       |       |       |
   |       |       |       +--> Existing monitoring/SIEM/archive
   |       |       +----------> Existing Key Vault/KMS/PKI
   |       +------------------> Existing subnet/DNS/egress
   +--------------------------> Existing ACR / external backup / GitOps
        |
        v
Normalized cluster contract
        |
        +--> Platform composition
        +--> CI/release evidence
        +--> GitOps/bootstrap
        +--> Future CAPI/CAPZ adapter
```

## 3. Ownership boundary

| Capability | AKS module owns | External owner / handoff |
|---|---|---|
| AKS cluster lifecycle | Resource, supported version/channel configuration, maintenance windows | Release approval and supported-version discovery |
| Resource naming | Names created/derived by this module | Names of pre-existing resources supplied by callers |
| Resource group | Create or reuse according to `resource_group.create` | Organizational placement/policy |
| Control-plane/kubelet identity | Create or reuse, wire into AKS, required role assignments when enabled | Entra governance/PIM/Conditional Access |
| Network | AKS network profile, subnet attachment, CIDR/DNS/capacity validation | VNet/subnet creation, IPAM, routes, firewall, private DNS lifecycle |
| API security | Private API production requirement, Azure RBAC, disabled local accounts | Enterprise DNS and access workflow |
| KMS | AKS etcd KMS integration and production readiness | Key Vault/key lifecycle and approval |
| Monitoring/audit | Diagnostic setting to supplied destinations | Workspace/SIEM/archive retention and alerting |
| Node pools | Fixed system pool and manual user pools; NAP contract | NAP `NodePool`/`AKSNodeClass` via GitOps |
| Storage | AKS CSI drivers and snapshot-controller readiness | StorageClasses, PVCs, workload storage policy |
| Backup | Readiness and integration output | Backup vault/policy/schedule/restore orchestration |
| PKI | Typed integration handoff | Enterprise PKI lifecycle |
| Policy/GitOps | AKS add-on toggles and security contract | Namespace PSA, default-deny policy, admission content, workloads |
| CI/release | Repository quality jobs supplied | CI runners, approvals, registry, publishing controls |

## 4. Input architecture

### 4.1 Normalized input facade

`module_interface` is the additive grouped facade for new composition systems. It groups values that were historically top-level:

```hcl
module_interface = {
  cluster = {
    kubernetes_version = "1.34"
    sku_tier           = "Standard"
    support_plan       = "KubernetesOfficial"
    profile            = "stateful"
    compliance_profile = "standard"
  }
  access = {
    tenant_id                        = "..."
    admin_group_object_ids           = ["..."]
    mandatory_admin_group_object_ids = ["..."]
    azure_rbac_enabled               = true
    local_account_disabled           = true
  }
  network_attachment = {
    node_subnet_id = "/subscriptions/.../subnets/snet-aks"
  }
}
```

When `module_interface` is set, its values take precedence. Existing top-level inputs remain supported as a migration bridge, avoiding an immediate breaking change.

### 4.2 Policy objects

The remaining inputs are already grouped by concern: `private_cluster`, `kms_encryption`, `network`, `system_node_pool`, `user_node_pools`, `autoscaling`, `disruption_profile`, `availability_policy`, `platform_security`, `maintenance`, `addons`, `storage_profile`, `integrations`, `backup_integration`, `pki_integration`, and `managed_identities`.

## 5. Story 1 — production security architecture

Production is detected from `naming.environment == "prod"`. The AKS resource lifecycle then requires:

- private API enabled;
- public FQDN disabled;
- no public authorized-IP list;
- Azure RBAC enabled;
- local AKS accounts disabled;
- at least one mandatory platform admin group and retention of all mandatory groups;
- KMS-backed etcd encryption;
- private Key Vault network access;
- supplied Log Analytics workspace;
- supplied archival storage account;
- `kube-audit` and `kube-audit-admin` diagnostic categories.

The module creates no SIEM, Key Vault, archival account, Conditional Access policy, or PIM workflow. SSH-disable readiness remains explicitly external when the approved provider/API does not expose the AKS control.

## 6. Story 3 — availability and node OS architecture

`availability_policy.criticality` accepts `tier-1`, `tier-2`, or `tier-3`. Production rejects the Free AKS tier. Production system pools must contain at least two distinct valid Azure zones from `1`, `2`, and `3`.

AzureLinux is the production default. A production system or user pool using Ubuntu or Windows must have a matching entry in `availability_policy.node_os_exceptions` containing the selected OS SKU, an approval reference, and a justification. This keeps the exception auditable without placing the approval workflow inside Terraform.

## 7. Story 4 — upgrade and maintenance architecture

The module separates approval discovery from enforcement:

- an external release process supplies `approved_kubernetes_versions`;
- production must specify an explicit `kubernetes_version` in that set;
- production cluster channels are restricted to `patch` or `stable`;
- production node OS channels are restricted to `NodeImage` or `SecurityPatch`;
- `effective_kubernetes_version` exposes the version resolved on the AKS resource;
- both upgrade windows support typed `not_allowed` exclusions.

Each exclusion contains a governance name, RFC3339 start/end values, reason, and approval reference. Terraform sends only `start` and `end` to AKS while retaining the governance metadata in `upgrade_readiness`.

## 8. Story 5 — network safety architecture

The module keeps IPAM ownership external but validates the composition it receives.

It converts the IPv4 pod CIDR, service CIDR, and DNS IP to numeric ranges and checks:

1. pod CIDR and service CIDR do not overlap;
2. DNS service IP is a usable address inside the service CIDR;
3. production pod CIDR contains enough addresses for declared maximum workload capacity.

For manual autoscaling, required pod addresses are calculated from each pool's `max_count * max_pods`. For production NAP, the caller must supply `network.capacity.max_nodes` and `network.capacity.max_pods_per_node`, because the GitOps-owned NAP pool topology is intentionally outside Terraform.

## 9. Story 6 — storage architecture

A `stateful` cluster requires Azure Disk CSI, the snapshot controller, external backup handoff, multi-zone system capacity, conservative disruption, and no Terraform-managed Spot pools. File and Blob CSI remain selectable because they are workload-specific rather than universally mandatory.

`storage_readiness` exposes all CSI switches, snapshot readiness, backup handoff, and the explicit `external-gitops` StorageClass ownership boundary.

## 10. Story 7 — naming architecture

All module-generated names are centralized in `locals.tf`:

- AKS cluster name;
- node resource group name;
- control-plane managed identity name;
- kubelet managed identity name;
- diagnostic-setting name.

`naming` segments are restricted to the KaaS enumerations. `naming_readiness` additionally evaluates resource-specific character and length rules for names the module creates or derives. Existing caller-owned resource names are consumed as supplied and are not renamed.

## 11. Story 8 — repository/release architecture

The repository includes root Terraform files, typed variables/outputs, development and production examples, tests, changelog, internal-use licensing notice, architecture documentation, TFLint configuration, a local quality-gate script, and GitLab CI jobs for:

- formatting and Terraform validation;
- lint;
- documentation check;
- configuration security scan;
- Terraform tests;
- tagged-release artifact/changelog checks.

The enterprise CI platform still owns runner configuration, approvals, credentials, artifact registry, and publishing.

## 12. Story 9 — normalized output architecture

`normalized_cluster_contract` is the provider-neutral facade. It contains:

- `cluster`: identity-neutral cluster metadata and profiles;
- `identity`: control-plane, kubelet, and workload-identity information;
- `endpoint`: private endpoint posture and FQDN;
- `network`: attachment and Kubernetes network contract;
- `node_pools`: system and user-pool normalized facts;
- `version`: requested/effective/approved state;
- `readiness`: availability, network, storage, upgrade, security, and naming readiness.

Azure-specific resource IDs are retained only where required for composition. A future CAPI/CAPZ adapter can map this normalized contract without changing the AKS module's internal resource implementation.

## 13. Deployment sequence

```text
1. Onboarding determines environment, criticality and workload profile.
2. Enterprise teams provide existing subnet/DNS/KMS/logging/ACR IDs.
3. Release governance supplies approved Kubernetes versions/freezes.
4. Terraform evaluates variable validation and derived locals.
5. AKS lifecycle preconditions reject unsafe production composition.
6. Identities are created or reused; optional RBAC assignments are established.
7. AKS is created with private API, identity, network, storage, add-ons and lifecycle settings.
8. Optional user pools are created when autoscaling mode is manual.
9. Diagnostics and existing-resource integrations are connected.
10. Readiness and normalized contracts are emitted.
11. GitOps/bootstrap consumes the cluster contract for external day-two capabilities.
12. CI quality gates and release evidence validate the module before publication.
```

## 14. Mutable versus foundational controls

Foundation controls include identity model, network architecture, API posture, workload profile, compliance model, and major cluster lifecycle choices. Changes to these are reviewed for replacement/disruption risk.

Day-two mutable controls include approved RBAC membership upstream, diagnostic categories, approved upgrade versions/windows, maintenance exclusions, tags, selected add-ons, and other settings Azure supports updating in place. Terraform plan remains the authoritative indicator of whether a proposed change is in-place or replacement.
