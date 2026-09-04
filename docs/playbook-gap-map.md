# KaaS playbook gap map

This map compares the KaaS playbook `26.06` draft with this AKS module. The playbook is the implementation authority where it defines an AKS-applicable platform guardrail. Environment values remain explicit in the development and production compositions.

| Playbook area | Previous module state | 26.08 disposition |
|---|---|---|
| One reusable Terraform module | Already one root module with concern-based files | Retained; no child-module expansion |
| KaaS AKS naming | Caller supplied an unconstrained cluster name; identities used `id-*`; node RG used `nrg-*` | Adopted derived `kaas-<org>-<env>-<region>-aks`, purpose-specific UAMI names, and Azure `MC_...` node RG convention |
| Approved org/environment/region segments | Not modeled | Added validated naming segments for sandbox/dev/stage/prod/dr and VA/AZ government regions |
| Node pool names | Lowercase, 12-character validation already present | Retained; examples use playbook-compatible `syspool1`/application naming guidance while AKS default pool remains `system` because it is an in-place compatibility boundary |
| Five governance tags | Eight legacy flat tags required | Replaced with mandatory JSON `ECS_CSF_TAG`, `ECS_HPOO_TAG`, `KAAS_TAG`, `KAAS_EXT_TAG`, and `KAAS_INFRA_TAG`; validates JSON, 256-character limits, required fields, and profile/environment alignment |
| Explicit environment composition | Dev/prod tfvars already explicit | Retained and aligned names/tags to NonProd and Prod patterns; sandbox/stage/DR remain documented compositions, not extra examples in this sprint |
| Existing network boundary | Existing subnet/private DNS and explicit egress already supported | Retained; Azure CNI Overlay + Cilium remain mandatory |
| Identity and least-privilege RBAC | Separate control-plane/kubelet UAMIs; subnet Network Contributor, identity-scoped Managed Identity Operator, registry-scoped AcrPull | Retained and renamed to playbook convention; no broader RG/subscription grants added |
| Security and auth | Entra/Azure RBAC, disabled local accounts, OIDC and Workload Identity | Retained as module guardrails |
| Capacity and node behavior | Manual Cluster Autoscaler or NAP, profiles, ARM64/FIPS, zones, rotation, Spot controls | Retained; NAP Kubernetes objects stay GitOps-owned |
| Add-ons and diagnostics | Optional Istio, Azure Policy, Prometheus, Container Insights, Defender, Key Vault CSI; category-filtered diagnostics | Retained; existing workspaces are integrated rather than created |
| Stateful/stateless | Profile validations already covered CSI, snapshot, backup handoff, zones, Spot and disruption | Retained |
| CAPI/CAPZ readiness | Generic outputs and explicit contracts; no CAPI resources | Retained as an interface/ownership goal only. Provider-neutral CAPI types and CAPZ resources are intentionally deferred |
| Fleet, Backup, GitOps | External boundaries documented | Retained. The playbook places platform services and GitOps in separate lifecycle layers |
| Module publishing structure | README, changelog, examples and native Terraform tests present; not playbook's basic/complete/Terratest layout | Partially adopted. Dev/prod examples are preserved by sprint direction; native tests are retained. CI, Terratest, rendered draw.io, LICENSE, publishing and approvals are repository/release concerns |
| Branching, commits and approvals | Not implemented by Terraform | Documented as repository governance; outside deployable module behavior |
| Namespace, app onboarding, image standards | Not implemented | Intentionally external: application/GitOps and container supply-chain responsibilities |
| Subscription topology and DR | Module is subscription-neutral | Explicit caller/provider responsibility; separate state per environment and prod/DR composition are deployment-layer concerns |

## Unresolved decisions

1. Confirm whether `fin` is an approved maintaining-org code. The playbook uses both `fs` and `fin` in different sections; the module temporarily accepts both to avoid rejecting a documented topology.
2. Confirm whether the fixed AKS default pool should be renamed from `system` to `syspool1`. Changing it forces cluster replacement, so this release documents the variance instead of silently introducing a destructive lifecycle change.
3. Confirm the enterprise-approved Azure Government private DNS zone suffix. The playbook examples are inconsistent with current example placeholders, so the module continues to require an explicit zone ID.
4. Confirm whether the five-tag rule applies to the AKS-managed node resource group. Azure creates that group; this module tags all directly managed taggable resources but cannot guarantee inheritance without external Azure Policy.
