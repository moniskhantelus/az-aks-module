# Changelog

## 3.0.0

- Kept tfvars examples values-only and placed the complete option catalog, constraints, and operating instructions in `examples/README.md` and in both environment folders for self-contained use.
- Added validation for documented networking, OS, disk, eviction, autoscaler, and maintenance selections.
- Normalized selectable autoscaling values to lowercase `manual` and `nap`, with the platform NAP default hidden behind the simple mode contract.
- Added required, validated `amd64`/`arm64` architecture selection to system and user node-pool contracts.
- Added first-class `stateless` and `stateful` cluster profiles with enforceable storage, backup, zone, Spot, and disruption rules.
- Replaced the Azure-facing capacity input with a clean `Manual`/`NAP` autoscaling contract while preserving both implementations.
- Added validated compliance, PSA, PKI placeholder, backup handoff, and diagnostic-category contracts.
- Expanded outputs for external backup, PKI, profile policy, and admission-controller neutrality.
- Updated both complete environment compositions and reviewer/PRD/Blueprint mapping.

## 2.2.2

- Granted the control-plane identity `Managed Identity Operator` on the custom kubelet identity.
- Made AKS cluster creation depend on that role assignment to prevent `CustomKubeletIdentityMissingPermissionError`.

## 2.2.1

- Removed environment-specific defaults from the module input contract.
- Made node pool compute, OS disk, autoscaler, maintenance, networking, add-on, integration, diagnostic, storage, and governance choices caller-owned.
- Added complete autoscaler values to both environment templates.
- Made every ARM user-pool field explicit while preserving the Blueprint-required Ephemeral OS disk policy.
- Set development system and ARM pools to explicit 60 GB Ephemeral disks; production retains its explicit 128 GB Ephemeral disk profile.
- Documented the explicit-input rule and retained only PRD/Blueprint platform guardrails.

## 2.1.0

- Kept the implementation as one lean Terraform module with logical root files.
- Reduced examples to exactly `development` and `production`.
- Added complete, sectioned tfvars examples and implementation READMEs.
- Added the FIPS/PSA/default-deny platform security contract and FIPS preconditions.
- Expanded governance requirements to include ESAT, platform, and data classification.
- Added resource-specific Log Analytics diagnostics and expanded production categories.

## 1.2.0

- Replaced the flat `location` and `resource_group_name` module inputs with a typed `resource_group` object.
- Added optional module ownership of the AKS resource group with tags.
- Added existing-resource-group lookup and effective name/location locals for enterprise reuse.
- Updated all AKS and identity resources to use the effective resource group values.
- Added resource group ID, location, and ownership outputs.
- Updated development and production examples for create and reuse modes.
- Clarified that shared networking remains externally owned.

## 1.1.0

- Added AKS Node Auto-Provisioning as the default capacity model.
- Added `node_provisioning_profile`.
- Disabled Cluster Autoscaler configuration in NAP mode.
- Prevented Terraform-managed user pools in NAP mode.
- Added NAP outputs, validations, documentation, and GitOps examples.
- Retained Manual mode for exception profiles.
