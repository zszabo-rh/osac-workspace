# OSAC-23 Storage Controller — E2E Test Summary

**Date:** 2026-06-12
**Tested by:** Zoltan Szabo
**Branch:** `feat/OSAC-23-storage-controller` (osac-operator), `feat/OSAC-1145-split-storage-playbooks` (osac-aap)

## Test Environment

- **Cluster:** edge-17 SNO (10.1.178.26), OpenShift 4.18
- **VAST:** 10.46.83.88, accessed via SSH tunnel from edge-17
- **Operator image:** `quay.io/rh-ee-zszabo/osac-operator:osac-23`
- **AAP:** 2.5 gateway, project pointed to osac-aap fork branch
- **Controllers enabled:** tenant, storage, compute-instance (cluster + networking disabled)
- **Storage tiers:** single `default` tier, VAST as sole provider

## Test Results

### Controller Behavior (10/10 pass)

| # | Test | Result |
|---|------|--------|
| 1 | **Phase decoupling** — Phase=Ready independent of storage conditions | PASS |
| 2 | **Upgrade path** — existing tenants get finalizer + conditions without re-provisioning | PASS |
| 3 | **Management-state** — `unmanaged` annotation skips storage reconciliation | PASS |
| 4 | **New tenant lifecycle** — namespace → Phase=Ready → Stage 1 trigger → StorageBackendReady=True | PASS |
| 5 | **Two-controller conflict** — tenant + storage controllers update same CR without 409 errors | PASS |
| 6 | **Hub Secret deletion recovery** — controller detects, sets False, triggers re-provision | PASS |
| 7 | **AAP job failure handling** — sets StorageBackendReady=False, waits for external trigger | PASS |
| 8 | **Controller restart mid-job** — resumes polling existing job, no duplicate launched | PASS |
| 9 | **Full tenant deletion** — class cleanup (job 801) → backend teardown (job 802) → finalizer removed | PASS |
| 10 | **Stage 2 SC creation** — AAP creates `vast-nfs-{tenant}-default` StorageClasses with correct labels, PVC binds | PASS |

### ComputeInstance Integration (pass)

| # | Test | Result |
|---|------|--------|
| 11 | **CI reads tenant storage** — `tenant_storage_classes: [{"name":"vast-nfs-osac-default","tier":"default"}]` injected into AAP extra_vars | PASS |
| 12 | **VM with VAST storage** — VM created, root disk PVC uses `vast-nfs-osac-default` StorageClass | PASS (NFS mount blocked by SSH tunnel topology — edge-17 specific, not an issue on routable networks) |

### Playbook Idempotency (4/4 pass)

| Playbook | Re-run with existing state | Re-run with nothing to do |
|----------|--------------------------|--------------------------|
| `osac-create-tenant-storage-backend` | PASS | n/a |
| `osac-create-tenant-storage-class` | PASS | n/a |
| `osac-delete-tenant-storage-class` | PASS | PASS |
| `osac-delete-tenant-storage-backend` | PASS | PASS |

## Findings

### 1. Stale job status in `status.jobs` (cosmetic)

When the controller detects the hub Secret early (before polling the AAP job to completion), the job record stays in `Running`/`Pending` state even though the AAP job succeeded. Conditions are correct — only the job history is stale.

**Impact:** cosmetic. **Fix:** poll the job to terminal state before short-circuiting.

### 2. Hub Secret loss requires manual VAST cleanup

If the hub Secret is deleted but the VAST VMS manager still exists, re-provisioning fails: "Manager already exists but password is unknown." The playbook correctly rolls back and reports the error.

**Impact:** operational edge case. **Fix:** document as operational procedure — delete the VMS manager in VAST before re-running.

### 3. AAP project reverts on config-as-code sync

The AAP config-as-code reconciliation resets the project SCM URL/branch to upstream on every operator restart. Requires manual re-pointing to the fork branch after each restart.

**Impact:** dev/test only — production will use upstream with merged playbooks. **Fix:** merge osac-aap PR before operator PR.

### 4. SC label removal not detected by watch

Removing `osac.openshift.io/tenant` label from a StorageClass does not trigger reconciliation because the SC watch predicate filters on that label. A manual trigger (label change on Tenant) is needed.

**Impact:** low — labels are managed by AAP, not manually. **Fix:** consider adding a delete event handler for SCs that previously matched.

### 5. NFS mount via SSH tunnel (edge-17 only)

VAST CSI provisions volumes successfully via the management API tunnel, but NFS data plane mounts fail because the CSI driver uses VIP addresses (11.0.0.x) for NFS, and SSH tunnels can't properly proxy NFS protocol (source IP verification, portmapper).

**Impact:** edge-17 only. Not applicable on hypershift1 or production where VAST VIPs are L3-routable.
