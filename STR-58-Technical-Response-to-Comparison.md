# STR-58 Technical Response to Reported Deployment Failures

## Purpose

This document responds only to the failures reported during testing of STR-58. It distinguishes confirmed module issues from EIC permission constraints and records the remediation now described for the latest STR-58 implementation.

## Executive summary

The reported test exposed three conditions:

1. `network_mode = "overlay"` was passed to a Windows-specific provider field and failed Terraform validation.
2. Creation of the `Network Contributor` role assignment failed with HTTP 403 because the EIC deployment service principal does not have `Microsoft.Authorization/roleAssignments/write` on the NIS-owned subnet.
3. Creation of the `Managed Identity Operator` role assignment failed with HTTP 403 because the same permission is not granted even on the newly created kubelet identity.

The two 403 responses are EIC authorization-model blockers, not failures of the AKS cluster specification. The AKS cluster resource was never reached in either apply attempt, so those test results do not demonstrate that the cluster configuration is invalid.

STR-58 has now been updated, according to the current implementation description, with a switch that turns off Terraform-managed IAM. With IAM management disabled, the restricted EIC path must use pre-created role assignments as deployment prerequisites. The reported IAM failures are therefore addressed by selecting the external-IAM mode and completing the required PlatformOps/NIS preparation before deployment.

## Response matrix

| Reported issue or claim | What occurred | STR-58 response and context | Recommended disposition | Evidence |
|---|---|---|---|---|
| `network_mode = "overlay"` failed validation | Terraform reported that `network_profile.network_mode` accepts `bridge` or `transparent`, not `overlay`. | This is a valid interface issue. `network_mode` is not the control for Azure CNI Overlay. Overlay is already selected through `network_plugin_mode = "overlay"`. | **Change** — remove `network_mode` from the module input and the AKS resource mapping. Until removed, callers must not pass `overlay` to it. | `STR-58-TEST-RESULTS.md`, lines 11–19 and 79–83. The attached ZIP still maps `var.network.network_mode` in `main.tf`, line 115, and declares it in `variables.tf`, line 178. |
| `Network Contributor` role assignment returned 403 | Terraform attempted to assign Network Contributor on the AKS subnet. The deployment SP lacks `Microsoft.Authorization/roleAssignments/write` on the NIS-owned networking resource group. | The report explicitly classifies this as an EIC-specific constraint rather than an STR-58 AKS code defect. The newly added IAM-management switch is the appropriate module-level response: in EIC, disable creation of this role assignment and require it to exist before the AKS deployment. | **External prerequisite** — set the IAM switch off for EIC and have PlatformOps/NIS pre-assign Network Contributor to the control-plane identity at the required subnet scope. | `STR-58-TEST-RESULTS.md`, lines 25–42 and 79–83. |
| `Managed Identity Operator` role assignment returned 403 | Terraform attempted to assign Managed Identity Operator over the kubelet identity. The deployment SP lacks role-assignment write permission even on a resource it created. | This is the same permission-boundary issue. Disabling Terraform-managed IAM prevents STR-58 from attempting an operation the EIC deployment identity is not authorized to perform. | **External prerequisite** — set the IAM switch off for EIC and pre-assign Managed Identity Operator to the control-plane identity at the kubelet-identity scope. | `STR-58-TEST-RESULTS.md`, lines 46–60 and 105–112. |
| Optional AcrPull role assignment | If STR-58 manages AcrPull when an ACR ID is provided, that operation also requires `roleAssignments/write` at the ACR scope. | The IAM switch must consistently govern **all** module-created role assignments, not only the two that failed during the recorded test. | **Clarify / Verify** — confirm the switch disables subnet Network Contributor, kubelet Managed Identity Operator, and optional AcrPull assignments. Pre-assign AcrPull externally when required in EIC. | The attached ZIP contains `azurerm_role_assignment.acr_pull` in `identities.tf`, lines 31–37. |
| “STR-58 cannot deploy in EIC” | The tested apply could not proceed beyond IAM creation. A cluster-targeted attempt still pulled in role assignments because the cluster explicitly depended on them. | The accurate conclusion is narrower: **the tested configuration could not deploy in EIC while Terraform-managed IAM was enabled**. It is not evidence that the AKS cluster resource is invalid because Terraform never attempted that resource. The external-IAM switch is intended to remove this hard gate. | **Clarify and retest** — describe the prior result as an IAM prerequisite failure. Run a new end-to-end test with IAM disabled and the required assignments already present. | `STR-58-TEST-RESULTS.md`, lines 64–73, 87–101, and 105–114. |
| AKS `depends_on` role assignments | The cluster had an explicit dependency on the two failed IAM resources; `-target` could not bypass the chain. | When IAM management is disabled, the dependency model must not continue to require disabled or nonexistent role-assignment instances. If resources use `count`, dependencies should reference the conditionally created collections safely or be replaced with a design that produces no IAM dependency in external mode. | **Change / Verify** — prove with `terraform plan` that IAM-off mode creates no role assignments and that the cluster is eligible to proceed. | `STR-58-TEST-RESULTS.md`, lines 97–101. The attached ZIP has unconditional dependencies in `main.tf`, lines 192–195. |
| Broad tag drift suppression | The lifecycle block now ignores tags along with `default_node_pool[0].upgrade_settings` and `default_node_pool[0].temporary_name_for_rotation`. | `ignore_changes = [tags]` was requested by Naveen. It should be recorded as an architect/reviewer-requested implementation choice, not characterized as an accidental STR-58 flaw. The choice prevents Terraform from reconciling any later cluster-tag changes, which is broader than ignoring only volatile platform-generated tags. | **Keep / Clarify** — retain the three approved ignores while that remains the requirement. Document the decision and its drift trade-off. If governance later requires Terraform to reconcile business tags, change to surgical tag-key ignores. | Naveen attribution and the three requested lifecycle entries were supplied with this response request. The attached ZIP does not yet contain an `ignore_changes` block, so the updated source must be attached or committed for verification. |
| Managed-identity creation | The test successfully created the control-plane and kubelet managed identities before IAM failed. | The identity resources themselves did not fail. The permission issue was role-assignment creation. Identity ownership may remain internal if that is the approved boundary, provided EIC IAM is externalized and identity details are available early enough for the prerequisite workflow. | **Keep / Clarify** — retain internal identity creation if approved, but document how PlatformOps receives identity principal IDs before cluster deployment. If pre-assignment timing makes that impractical, support pre-created identities as inputs. | `STR-58-TEST-RESULTS.md`, lines 64–73 and 87–93. |

## Required behavior of the IAM switch

For the switch to resolve the EIC failures completely, IAM-off mode must satisfy all of the following:

- No `azurerm_role_assignment` resource is planned by STR-58.
- Network Contributor on the AKS subnet is documented and validated as an external prerequisite.
- Managed Identity Operator on the kubelet identity is documented and validated as an external prerequisite.
- AcrPull is externally assigned when ACR integration is enabled.
- The AKS cluster has no active dependency on Terraform-managed IAM resources when the switch is off.
- The module provides clear plan-time messaging or documentation identifying the missing external responsibilities.

A typical implementation pattern is to apply the same condition to every role assignment:

```hcl
count = var.manage_role_assignments ? 1 : 0
```

The exact expression may differ for optional assignments, but the governing behavior should be consistent. For example, AcrPull would need to account for both the IAM switch and whether an ACR ID is present.

## Lifecycle decision

The requested lifecycle behavior should be documented as:

```hcl
lifecycle {
  ignore_changes = [
    default_node_pool[0].upgrade_settings,
    default_node_pool[0].temporary_name_for_rotation,
    tags
  ]
}
```

This is an intentional, reviewer-requested drift-management policy:

- `upgrade_settings` is ignored to avoid reconciliation of values adjusted during AKS upgrade operations.
- `temporary_name_for_rotation` is ignored to avoid unnecessary rotation-related diffs.
- the complete `tags` map is ignored because Naveen requested that behavior.

The trade-off is that Terraform will not correct or apply subsequent changes to any cluster tags. If future requirements distinguish governed business tags from volatile deployment metadata, a more surgical approach—ignoring only the volatile tag keys—would provide stronger configuration enforcement.

## Attachment verification note

The attached `boeing-aks-production-module-lean-v3.0.0.zip` appears to predate the changes described above:

- `identities.tf` lines 15–37 contain unconditional Network Contributor, Managed Identity Operator, and AcrPull role assignments.
- `main.tf` lines 192–195 unconditionally depend on the first two assignments.
- no `manage_role_assignments` declaration or reference is present in the archive.
- no `ignore_changes` block is present in the archive.
- `main.tf` line 115 still maps `network_mode`, and `variables.tf` line 178 still declares it.

Accordingly, the IAM switch and lifecycle remediation should be treated as **reported changes in the latest source**, not as verified contents of this ZIP. A refreshed archive or committed branch should be used for final validation.

## Retest plan and acceptance evidence

1. Obtain the updated source containing the IAM switch and the three lifecycle ignores.
2. Remove `network_mode` from the variable contract and AKS resource mapping.
3. Run formatting and validation checks.
4. Run a plan with IAM management disabled and confirm that it contains zero role-assignment creates.
5. Confirm the externally assigned Network Contributor, Managed Identity Operator, and any required AcrPull permissions.
6. Apply the module and verify that Terraform reaches `azurerm_kubernetes_cluster.this`.
7. Verify cluster provisioning, node pools, diagnostics, addons, and outputs.
8. Run a second plan and confirm that the approved lifecycle fields do not create drift while other governed configuration remains visible.

## Conclusion

The reported failures support two separate conclusions. First, `network_mode` is a genuine input-mapping issue and should be removed. Second, the two 403 errors result from EIC's restricted role-assignment model. They blocked Terraform before it attempted AKS creation and therefore do not prove that the STR-58 AKS specification is invalid.

The newly described IAM switch is the correct response to the EIC permission boundary, provided it disables every role assignment and removes the active dependency gate in IAM-off mode. The three lifecycle ignores are intentional implementation choices, with the broad tag ignore specifically requested by Naveen. Once the updated source is available, STR-58 should be retested end to end with external IAM prerequisites in place.
