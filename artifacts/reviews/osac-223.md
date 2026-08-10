# Review: osac#223 — OSAC-2872: Volume Controllers

## PR Info
- URL: https://github.com/osac-project/osac/pull/223
- Jira: OSAC-2872 (Storage Control Plane)
- Author: akshaynadkarni
- Created: 2026-08-09
- State: Draft (not yet tested on cluster)
- Stacks on: #201 (Volume API + CRD, data model)
- Base: main <- feat/OSAC-2872-volume-api-crd
- CI: Not yet run (draft)

## Round 1 — 2026-08-10

### Context
- Commits reviewed: 804cfc0..126d2dc (11 commits)
- Files changed: 57 (+14k lines, mostly generated proto)
- Other reviewers: CodeRabbit (2 rounds, feedback addressed)
- PR #201 findings: all addressed (enum access mode + protocol, Create validation, PVCRef removal guard, Phase↔State documented)

### What it does
Adds three controllers for Volume lifecycle (PR 2 of 3):
1. **Reconciler** (fulfillment-service): watches Volume events, creates/patches/deletes Volume CRs on hub cluster, maps proto enums to CRD typed strings
2. **Resource controller** (osac-operator): receives Volume CRs, calls VendorProvisioner interface (nil for now — vendor CSI integration in PR #3)
3. **Feedback controller** (osac-operator): syncs CR status back to fulfillment-service via Bridge pattern, maps CRD phases to proto states

### Positive observations
- All PR #201 findings addressed (enum access mode + protocol, Create validation, PVCRef removal guard)
- Phase↔State mapping documented in feedback controller comments
- Clean three-controller architecture with proper separation of concerns
- Good use of feedback.Bridge — follows existing pattern exactly
- VendorProvisioner interface well-designed for test/dev with MockVendorProvisioner
- Thorough test coverage across all three controllers
- Proper management-state annotation check
- StorageProtocol moved to shared storage_common_type.proto (clean refactoring)

### Findings
| # | Severity | Category | File:Line | Finding | Status |
|---|----------|----------|-----------|---------|--------|
| 1 | Minor | naming | volume_names.go (v1alpha1):33 | VolumeFinalizer has `-finalizer` suffix, inconsistent with all other resource finalizers | OPEN |
| 2 | Minor | dead-code | volume_names.go (v1alpha1):37-39 | VolumeCleanupFinalizer defined but unused — orphan risk if PR #3 doesn't implement | OPEN |
| 3 | Minor | defensive | volume_reconciler_function.go:389 | protoAccessModeToCRD silently defaults UNSPECIFIED to ReadWriteOnce | OPEN |
| 4 | Nitpick | consistency | volume_controller.go:~273 | handleDelete uses r.mgr.GetLocalManager().GetClient() instead of r.Client | OPEN |
| 5 | Question | deployment | cmd/main.go:1011 | No separate OSAC_ENABLE_VOLUME_CONTROLLER feature flag (bundled under Storage) | OPEN |

### Draft Comments
1. [volume_names.go:33] `VolumeFinalizer = "osac.openshift.io/volume-finalizer"` has a `-finalizer` suffix. All other resources use bare names: `osac.openshift.io/computeinstance`, `osac.openshift.io/subnet`, etc. The feedback finalizer (`volume-feedback`) is consistent. Should this be `osac.openshift.io/volume`?

2. [volume_names.go:37-39] `VolumeCleanupFinalizer` is defined with the comment "added to ClusterOrder when volumes are created, blocking cluster deletion until volumes are processed." But no controller in this PR adds it to ClusterOrders. If PR #3 doesn't implement this, cluster deletion won't be blocked by active volumes — orphaned vendor volumes. Also: this cross-resource finalizer pattern (Volume controller adding a finalizer to ClusterOrder CRs) is new — no other resource does this. Worth documenting the lifecycle contract, and adding a TODO(PR-3) or issue reference.

3. [volume_reconciler_function.go:389] `default: return VolumeAccessModeReadWriteOnce` — silently converts UNSPECIFIED to a real value. Server validation rejects UNSPECIFIED at the API layer, so this shouldn't happen in practice. But defensive logging would catch bugs if validation is bypassed (e.g., reconciler processing existing records after schema migration).

4. [volume_controller.go:~273] `handleDelete` uses `r.mgr.GetLocalManager().GetClient().Update(ctx, vol)` while everywhere else uses `r.Client`. They're the same underlying client, but just use `r.Client` for consistency.

5. [cmd/main.go:1011] Volume controllers start under `ctrlFlags.Storage` without their own `OSAC_ENABLE_VOLUME_CONTROLLER` toggle. Every other resource type has an independent flag. If you need storage backends but not volumes (or vice versa), you can't toggle them independently. Intentional?

### Evaluated and dropped
- **Unknown phase handling in syncVolumePhase**: Logs "will ignore it" and doesn't return error, leaving remote state stale. Architecturally valid concern but ALL 9 existing feedback controllers (ClusterOrder, ComputeInstance, ExternalIP, ExternalIPAttachment, ExternalIPPool, NATGateway, SecurityGroup, Subnet, VirtualNetwork) follow the exact same pattern. Not a Volume-specific gap — deserves a separate horizontal fix ticket, not a finding on this PR.

### Recommendation
APPROVE (for draft) — solid implementation following established patterns. No correctness bugs. Findings are naming consistency and defensive coding.
