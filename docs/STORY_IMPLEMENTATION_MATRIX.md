# AKS Stories 1–9 Implementation Matrix

This matrix records the final implementation location and closure evidence for the nine AKS stories. The module owns the AKS Terraform contract; enterprise services such as shared networking, DNS, Key Vault lifecycle, SIEM, GitOps, CI approval/publishing, backup infrastructure, PKI, and application policy remain externally owned where documented.

| Story | Implemented capability | Primary code/evidence |
|---|---|---|
| 1 | Production security, KMS readiness, private API, Azure RBAC, mandatory admin groups, audit routing/archive readiness, fail-closed production preconditions | `main.tf`, `diagnostics.tf`, `outputs.tf`, `tests/validation.tftest.hcl` |
| 2 | Consolidated readiness output and release/quality evidence | `output.aks_readiness`, examples, `.gitlab-ci.yml`, `scripts/quality-gates.sh` |
| 3 | Production SLA tier guardrail, >=2 valid zones, AzureLinux-by-default with typed OS exception metadata | `availability_policy`, `locals.tf`, `main.tf`, story tests |
| 4 | Approved Kubernetes version set, safe production channels, effective version output, typed maintenance exclusions | `approved_kubernetes_versions`, `maintenance.not_allowed`, `upgrade_readiness`, story tests |
| 5 | Pod/service CIDR overlap detection, DNS placement validation, pod-address capacity calculation | `locals.tf`, network preconditions, `network_readiness`, story tests |
| 6 | Stateful Disk CSI + snapshot + backup-handoff enforcement and effective CSI readiness | `storage_profile`, stateful preconditions, `storage_readiness`, story tests |
| 7 | Centralized derived names plus Azure/KaaS format and length readiness | `locals.tf`, `naming_readiness`, story tests |
| 8 | Required repository artifacts, examples, architecture docs, testing, lint/security/release pipeline | `.gitlab-ci.yml`, `.tflint.hcl`, `LICENSE`, docs, tests |
| 9 | Explicit responsibility boundaries, additive grouped input contract, normalized provider-neutral outputs | `module_interface`, `normalized_cluster_contract`, architecture docs, contract test |

## Completion principle

A story is considered implemented when the module contains the enforcement logic or explicit external handoff required by the acceptance criteria, exposes the effective state where requested, and includes automated positive/negative coverage appropriate to the control. External enterprise capabilities are not falsely created inside this AKS module.
