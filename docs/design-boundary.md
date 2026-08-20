# Design boundary

## Owned by this module

- Optional AKS resource group, AKS cluster, fixed system pool, and manual-mode user pools
- User-assigned control-plane and kubelet identities and required role assignments
- Entra/Azure RBAC, disabled local accounts, OIDC, and Workload Identity
- Azure CNI Overlay and Cilium
- AKS-native add-ons, maintenance, upgrades, and approved diagnostics
- `cluster_profile`, compliance, autoscaling, disruption, backup, and PKI contracts

## Integrated, not created

- Existing subnet, routing/NAT/firewall, and private DNS zone
- Existing ACR (`AcrPull` assignment only)
- Existing Log Analytics and Defender workspaces
- Enterprise PKI metadata; no issuer, certificates, or trust bundle is installed
- Backup metadata consumed by a separate backup module

## Outside this module

Fleet Manager, AKS Backup resources, GitOps controllers, Karpenter `NodePool`/`AKSNodeClass`, Kyverno/Gatekeeper, PSA namespace labels, default-deny policies, StorageClasses, snapshots, PDBs, topology-spread rules, applications, and multi-cloud/CAPI management-plane components.

## Profile enforcement boundary

Stateful mode requires Azure Disk CSI, the snapshot controller, enabled backup handoff, conservative consolidation, a multi-zone fixed pool, and no Terraform-managed Spot pools. Runtime policies such as PDBs and topology spread cannot be truthfully enforced by an infrastructure-only AKS resource module; they are explicit bootstrap/application obligations.

Stateless mode permits NAP, Spot, Ephemeral OS disks, scale-to-zero, and aggressive consolidation. Exact NAP policy remains in GitOps so cluster infrastructure and workload scheduling ownership do not overlap.
