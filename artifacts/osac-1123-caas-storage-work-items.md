# OSAC-1123: CaaS Tenant Storage Setup — Work Items

**Epic:** OSAC-1123 (CaaS Tenant Storage Setup)
**Parent Feature:** OSAC-1191 (CaaS — Provision and Manage OpenShift Clusters)
**Fix Version:** 0.1 (reprioritized from 0.2 on June 1)
**Author:** Zoltan Szabo
**Date:** 2026-06-02

---

## Context

CaaS storage differs from VMaaS in one critical way: **Phase 2 timing**.

```
VMaaS:
  Phase 1 (backend setup)     → at tenant onboarding
  Phase 2 (CSI + SC on hub)   → immediately after Phase 1 (hub already exists)
  Trigger: Tenant controller

CaaS:
  Phase 1 (backend setup)     → at tenant onboarding (SAME)
  Phase 2 (CSI + SC on guest) → AFTER cluster is provisioned (NEW timing)
  Trigger: ClusterOrder controller (NOT Tenant controller)
```

Phase 1 is shared — the Tenant controller handles it identically for both VMaaS and CaaS. The only new work is Phase 2 integration into the cluster lifecycle.

### Architectural Constraint (Roy Golan, June 1)

Split CSI (OSAC controller plugin on tenant, vendor node plugin on tenant) **won't work** — CSI identifier mismatch means volume publish fails. CaaS must use vendor-native CSI on the guest cluster, same as VMaaS. This means:
- Full vendor CSI operator installed on every tenant cluster
- StorageClasses created on guest cluster
- CSI credentials (Secret) placed on guest cluster

---

## Prerequisites (from VMaaS / Phase B work)

These OSAC-56 tasks establish the shared two-phase model that CaaS depends on:

| Ticket | Summary | Status | Blocks CaaS? |
|--------|---------|--------|---------------|
| OSAC-1145 | Split AAP playbooks into 4 lifecycle actions | New | **Yes** — defines ensure-tenant-storage as separate playbook |
| OSAC-1143 | Hub Secret readiness gate | New | Partially — Phase 1 completion signal |
| OSAC-1144 | Trigger ensure-tenant-storage for VMaaS Phase 2 | New | Pattern reference only |

---

## Proposed Work Items

### WI-1: Extend storage_provider role for guest cluster targeting
**Repo:** osac-aap
**Depends on:** OSAC-1145 (playbook split)

The `storage_provider` role already has a `provisioning_target` parameter with reserved `hcp_data_plane` value. Implement it:

- `vast_storage/ensure_storage_class.yaml`: accept `kubeconfig` parameter to target guest cluster instead of hub
- Install VAST CSI operator on guest cluster via OLM (currently only runs on hub)
- Create StorageClasses and CSI Secret on guest cluster using the provided kubeconfig
- Short-circuit check: verify SC existence on guest cluster (not hub)
- Reuse hub Secret (from Phase 1) for VAST credentials — no additional backend setup needed

**Acceptance criteria:**
- `storage_provider_provisioning_target: hcp_data_plane` works with a guest kubeconfig
- SCs created on guest cluster with correct tenant/tier labels
- CSI operator installed and healthy on guest cluster
- Idempotent: re-running with existing SCs is a no-op

### WI-2: Create CaaS storage provisioning playbook
**Repo:** osac-aap
**Depends on:** WI-1

- `playbook_osac_ensure_cluster_storage.yml`
- Reads guest cluster kubeconfig from extra_vars (injected by operator)
- Reads tenant storage tier config from hub Secret (same as VMaaS)
- Calls `storage_provider` with `action: ensure_storage_class` and `provisioning_target: hcp_data_plane`
- Does NOT run Phase 1 (setup) — that's already done at tenant onboarding

**Acceptance criteria:**
- Playbook runs successfully against a guest cluster
- StorageClasses visible on guest cluster
- CSI driver pods running on guest cluster

### WI-3: Create CaaS storage cleanup playbook
**Repo:** osac-aap
**Depends on:** WI-1

- `playbook_osac_cleanup_cluster_storage.yml`
- Removes SCs, VolumeSnapshotClasses, CSI Secret from guest cluster
- Does NOT tear down backend (tenant still exists) — only cluster-scoped resources
- Optionally uninstalls CSI operator

**Acceptance criteria:**
- All tenant-labeled SCs removed from guest cluster
- CSI Secret removed
- Backend resources (VAST views, quotas) untouched

### WI-4: AAP config-as-code for CaaS storage job templates
**Repo:** osac-aap
**Depends on:** WI-2, WI-3

- Add to `config_as_code/controller.yml`:
  - `osac-ensure-cluster-storage` job template → WI-2 playbook
  - `osac-cleanup-cluster-storage` job template → WI-3 playbook
- Instance group: reuse `storage-operations-ig` from VMaaS config

**Acceptance criteria:**
- Job templates created by config-as-code sync
- Templates can be launched manually with correct extra_vars

### WI-5: ClusterOrder controller — trigger Phase 2 after cluster Ready
**Repo:** osac-operator
**Depends on:** WI-4

Extend `ClusterOrderReconciler.handleUpdate()`:

1. After `hostedClusterIsReady()` returns true, check if storage provisioning is needed
2. Look up Tenant CR from ClusterOrder's `osac.openshift.io/tenant` annotation
3. Check hub Secret exists (Phase 1 complete)
4. If storage not yet provisioned: trigger `osac-ensure-cluster-storage` AAP job
5. Pass guest kubeconfig as extra_var (retrieved from HostedCluster admin-kubeconfig Secret)
6. Poll job status using existing `RunProvisioningLifecycle` pattern
7. Only transition ClusterOrder to Phase `Ready` after storage job succeeds

**New condition:** `StorageReady` on ClusterOrderStatus

**Changes:**
- `api/v1alpha1/clusterorder_types.go`: add `ClusterOrderConditionStorageReady` condition type
- `internal/controller/clusterorder_controller.go`: add `handleStorageProvisioning()` after HC ready check
- `cmd/main.go`: add `ensureClusterStorageTemplate` env var (default: `osac-ensure-cluster-storage`)

**Acceptance criteria:**
- ClusterOrder stays in `Progressing` until storage setup completes
- `StorageReady` condition reflects actual state
- ClusterOrder reaches `Ready` only after HC ready AND storage ready
- If storage fails, ClusterOrder goes to `Failed` with clear message

### WI-6: ClusterOrder controller — storage cleanup on deletion
**Repo:** osac-operator
**Depends on:** WI-4

Extend `ClusterOrderReconciler.handleDelete()`:

1. Before namespace deletion, trigger `osac-cleanup-cluster-storage` AAP job
2. Wait for cleanup completion
3. Only proceed with existing deletion flow after storage cleanup
4. Handle edge case: cluster already destroyed (guest kubeconfig invalid) — skip gracefully

**Changes:**
- `internal/controller/clusterorder_controller.go`: add `handleStorageDeprovisioning()` in deletion path
- Reuse existing `TriggerDeprovision` pattern from Tenant controller

**Acceptance criteria:**
- Storage resources cleaned from guest cluster before cluster deletion
- Finalizer not removed until storage cleanup succeeds or is skipped
- Graceful handling of unreachable guest cluster

### WI-7: Pass guest kubeconfig to AAP extra_vars
**Repo:** osac-operator
**Depends on:** WI-5

The `extractExtraVars()` function in `aap_provider.go` currently serializes the CR and optional `tenant_storage_classes`. Extend it to include the guest kubeconfig for CaaS storage jobs:

- Retrieve kubeconfig from HostedCluster's admin-kubeconfig Secret
- Inject as `guest_kubeconfig` extra_var (base64-encoded)
- Only inject for cluster storage templates (not for other job types)

Alternative: Use AAP credential type with kubeconfig, mounted as file in execution environment. This is more secure than extra_vars.

**Decision needed:** extra_var vs AAP credential type. Discuss at storage meeting.

### WI-8: Unit tests for ClusterOrder storage integration
**Repo:** osac-operator
**Depends on:** WI-5, WI-6

- Test: ClusterOrder stays Progressing when HC ready but storage not provisioned
- Test: ClusterOrder reaches Ready after both HC and storage ready
- Test: StorageReady condition set correctly on success/failure
- Test: Deletion triggers storage cleanup before finalizer removal
- Test: Missing Tenant annotation → skip storage provisioning (non-storage cluster)

### WI-9: E2E test for CaaS storage provisioning
**Repo:** osac-test-infra
**Depends on:** All above

- Create ClusterOrder for a tenant with storage tiers configured
- Verify cluster creation includes storage provisioning step
- Verify StorageClasses exist on guest cluster
- Verify PVC creation works on guest cluster
- Verify cleanup on cluster deletion

---

## Dependency Graph

```
OSAC-1145 (AAP playbook split) ─────────────┐
                                             ▼
                                     WI-1 (extend storage_provider)
                                        │         │
                                        ▼         ▼
                                WI-2 (ensure     WI-3 (cleanup
                                 playbook)        playbook)
                                        │         │
                                        ▼         ▼
                                     WI-4 (config-as-code)
                                        │         │
                            ┌───────────┘         │
                            ▼                     ▼
                    WI-5 (CO Phase 2)     WI-6 (CO cleanup)
                            │                     │
                            ├─────────────────────┤
                            ▼                     │
                    WI-7 (kubeconfig)              │
                            │                     │
                            ▼                     ▼
                    WI-8 (unit tests) ◄───────────┘
                            │
                            ▼
                    WI-9 (E2E test)
```

## Open Questions for Storage Meeting

1. **Kubeconfig delivery:** extra_var (simple) vs AAP credential type (more secure)? If credential type, we need a custom credential that mounts the kubeconfig file.

2. **CSI operator lifecycle:** Who manages the CSI operator on the guest cluster? Options:
   - AAP installs via OLM during Phase 2 (current VAST pattern)
   - ACM Policy pushes CSI operator to all managed clusters
   - Pre-baked in cluster template (post_install hook)

3. **Scope of v0.1:** Akshay moved CaaS to v0.1 but the dependency on VMaaS Phase B work (OSAC-1145) remains. Should we do a CaaS-specific minimal path that doesn't require the full 4-action model?

4. **Non-VAST backends:** For dev/test with Ceph/LVM, is manual SC creation on guest cluster acceptable for v0.1? Or do we need a generic "install SC from hub config" path?

5. **Cluster template integration:** Should storage be a built-in step in the cluster template (post_install.yaml) or a separate controller-triggered job? The template approach is simpler but couples storage to cluster provisioning.

6. **Multiple clusters per tenant:** A tenant can have multiple CaaS clusters. Each needs its own Phase 2 run. The Tenant controller handles Phase 1 once; the ClusterOrder controller handles Phase 2 per-cluster. Is this the right separation?
