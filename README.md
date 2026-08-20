# Boeing AKS Production Terraform Module

One lean AKS module with two policy-driven workload profiles. Root `.tf` files are one module; filenames only separate concerns.

## Required environment composition

Environment-specific values have no hidden defaults. Callers explicitly provide VM sizes, counts, disks, CIDRs, egress, maintenance, add-ons, integrations, diagnostics, storage, governance, autoscaling, disruption, PKI, and backup handoffs. The development and production tfvars examples are complete compositions.

The tfvars templates intentionally contain values rather than an embedded manual. See the [environment tfvars reference](examples/README.md) for every supported choice, dependency, constraint, and deployment instruction.

Blueprint/PRD platform invariants stay in the module: user-assigned control-plane and kubelet identities, OIDC and Workload Identity, Azure RBAC, disabled local accounts, Azure CNI Overlay with Cilium, and existing-ACR-only `AcrPull`. Service mesh is optional and examples keep it disabled. The module installs neither Kyverno nor Gatekeeper.

## Cluster profiles

| Contract | `stateless` | `stateful` |
|---|---|---|
| Capacity | NAP-friendly; manual retained | NAP or manual with controlled policy |
| Spot | Supported | Rejected for Terraform-managed pools |
| OS disk | Ephemeral preferred | Workload-dependent; persistent data stays on CSI volumes |
| Consolidation | Aggressive | Conservative required |
| Azure Disk CSI | Optional | Required |
| Snapshot controller | Optional | Required |
| External backup hook | Optional | Required |
| Zones | Recommended | Two or more system-pool zones required |

`cluster_profile` expresses workload intent without creating two AKS modules. Stateful applications must still supply PodDisruptionBudgets, topology spread, StorageClasses, restore tests, and workload-aware drain policy through the application/bootstrap layers.

## Autoscaling contract

```hcl
autoscaling = {
  mode = "nap" # or "manual"
}
```

`nap` maps internally to AKS Node Auto-Provisioning and rejects Terraform-managed user pools. GitOps owns `NodePool` and `AKSNodeClass` capacity, architecture, Spot/on-demand, consolidation, and disruption policy. `manual` retains explicit user pools and Cluster Autoscaler tuning. The advanced `nap_default_node_pools` field defaults to the platform value `None`.

Each Terraform-managed node pool also requires an explicit architecture:

```hcl
architecture = "amd64" # or "arm64"
```

The module validates the choice and does not write the reserved `kubernetes.io/arch` node label. Kubernetes supplies that label automatically. The selected `vm_size` must be an approved, regionally available SKU that matches the architecture.

## External integration boundaries

- Fleet Management remains a future companion module.
- Backup remains a companion module. `backup_integration` exposes cluster/resource-group IDs, control-plane and kubelet identities, and CSI/snapshot readiness.
- PKI is not implemented here. `pki_integration` records the enterprise trust-bundle secret and issuer handoff.
- ACR must already exist; this module only grants `AcrPull` to the kubelet identity.
- Load Balancer, managed/user-assigned NAT Gateway, and UDR outbound modes remain configurable.
- PKI components, admission engines, default-deny policies, PSA namespace labels, GitOps, and application resources stay outside this module.

## Compliance and diagnostics

The selectable policy values are explicit:

```hcl
platform_security = {
  psa_enforce_level = "restricted" # restricted, baseline, or privileged
}

compliance_profile = "standard" # standard or fips
```

FIPS requires the FIPS security contract plus FIPS and host encryption on every Terraform-managed Linux pool. Diagnostic logs accept only the approved AKS control-plane and CSI categories declared in `variables.tf`.

## Reviewer / PRD / Blueprint mapping

| Feedback | Implementation and ownership | Alignment |
|---|---|---|
| Fleet excluded | Future separate Fleet module | Blueprint module boundary |
| Backup excluded | Separate module; complete `backup_integration` output | Azure Backup composition boundary |
| Stateful/stateless | First-class `cluster_profile` with storage, backup, zone, Spot, and disruption checks | Workload durability contract |
| Service mesh optional | AKS Istio add-on only when explicitly enabled; examples disable it | Blueprint 3 §5 |
| Identity | User-assigned control-plane/kubelet identities, OIDC, Workload Identity, Azure RBAC, local accounts disabled | Blueprint 2a |
| Networking | Azure CNI Overlay + Cilium enforced; outbound mode explicit | Blueprint 3 §4.1 and transit boundary |
| ACR | Existing registry ID only; `AcrPull` only | Integration boundary |
| FIPS and PSA | Validated compliance profile and PSA enumeration | Critical compliance/security gaps |
| PKI | Typed placeholder contract, no installation | Enterprise PKI gap without scope expansion |
| Diagnostics | Approved category allowlist | Compliance gap |
| Admission engine | Neutral; installs neither Kyverno nor Gatekeeper | Avoids policy-engine conflict |
| Autoscaling / blast radius | `manual` or `nap`; GitOps disruption handoff | NAP and scaling-boundary gaps |
| Fleet/cloud-agnostic facade/CAPI | Explicitly out of this Azure provider module | Future architecture work, not falsely claimed |

## Validation

```bash
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
terraform test
```

Provider-backed plans for both examples are required before release.
