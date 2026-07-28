# OSAC Storage v0.2 — Status Summary

**Last updated:** 2026-07-28 (mid-session checkpoint — 3 OSAC-3011 draft PRs opened, fresh demo cluster on edge-17, E2E validation in progress)  
**Owner:** Zoltan Szabo  
**Update this file** at the end of each working session. Read it first at the start of the next one.

---

## Active Epics (OSAC-917 children, all targeted 0.2-M2 = end of August)

| Epic | Assignee | Status | Summary |
|------|----------|--------|---------|
| OSAC-3011 | Zoltan | In Progress | Local/Dev/E2E CI Storage Setup — **implementation complete July 27** (3 PRs: osac-aap, osac-installer, osac-operator); E2E partial — StorageBackend+StorageTier verified, AAP flow blocked by snapshot issue |
| OSAC-3012 | Zoltan | New | MOC Developer Environment Storage Setup — agreed to fold minimal change into OSAC-3011; basically a no-op |
| OSAC-3013 | Will | In Progress | Backend and Tier API Integration (operator + AAP side) |
| OSAC-3014 | Will | New | Public Storage Tier API |
| OSAC-2776 | Akshay | In Progress | Storage Framework Bootstrap |

---

## OSAC-3011 Design (agreed approach)

**Agreed direction (Akshay's counter-proposal, July 23):** AAP dispatcher pattern — no proto changes, no operator routing changes.

**What gets built:**
- `local_lvms_storage` AAP role (4 actions: setup, ensure_storage_class, teardown_cluster_storage, teardown_backend)
  - Hub cluster only — CaaS guest cluster out of scope (KubeVirt workers have root disk only, workload-only concern, deferred)
  - `ensure_storage_class`: creates per-tenant labeled SC using `lvms.topolvm.io` provisioner + OSAC labels via `kubernetes.core.k8s`
- osac-installer: new `register-local-storage.yaml` post-install hook (follows `seed-cluster-versions.yaml` pattern — admin SA, `waitForFulfillment` init container, idempotent); creates `local` StorageBackend (`provider: local-lvms`, `endpoint/credentials: n/a`) + `local` StorageTier when `lvms.enabled: true`
- osac-installer: make `configure-lvms.sh` idempotent — check if `lvms-vg1` exists, skip installation (but NOT annotation) if so. Enables setting `lvms.enabled: true` on MOC safely.
- `development/values.yaml`: change `lvms.enabled: false` → `true` (safe with idempotent hook; annotation step skipped since `lvms-vg1` already exists on MOC and Ceph is the actual default SC there)
- osac-operator: remove `defaultStorageClassSentinel` (`tenant=Default` fallback) in `getTenantStorageClasses()`

**StorageTier and StorageBackend both named:** `local`

**Instance group (confirmed July 24):**  
No separate `localStorageFulfillment` IG. Once OSAC-3013 strips VAST credentials from `storage-operations-ig`, `local_lvms_storage` uses the same IG. Posted in wg-osac-storage July 24 morning.

**Dependency model:**  
OSAC-3013 operator half (PR #354 + PR #375) and AAP half must merge before OSAC-3011 PR lands. Implementation proceeds in parallel.

**LVMS verified live on MOC (July 24):** PVC bound, pod ran successfully on `lvms-vg1`, resources cleaned up. `lvms-vg1` is NOT the default SC on MOC (`ocs-external-storagecluster-ceph-rbd`/Ceph is). The MOC LVMCluster (`local-storage-vg1`) has a hardcoded device path — running `oc apply` on our `config.yaml` without the idempotency guard would create a second conflicting LVMCluster.

**Plan approved by Akshay July 24 meeting.** ✅ **Implementation complete July 27.**

**Target: working dev setup by Friday July 31. Demo: Monday August 3.**
Demo scope: hub cluster boots → StorageBackend + StorageTier auto-registered → tenant onboarded → StorageClass created via AAP → PVC bindable on hub cluster. Using LVMS (not new CSI control plane).

**CaaS guest cluster:** Out of scope for OSAC-3011. Separate ticket to be created by Akshay — second disk for agent VMs is in `setup-caas-agents.sh` scope (not cluster-tool). No action needed from Omer.

**storage.enabled vs storageFulfillment.enabled (clarified July 24):**
- `storage.enabled` = storage **controller** on/off
- `storageFulfillment.enabled` = AAP **instance group** (dummy secrets, config)
- Bug path without PR #354: controller enabled + storageFulfillment disabled → no dummy secrets → `create_tenant_storage_backend` playbook fails

---

## OSAC-3234 Design (CaaS Local Storage for Dev/CI)

**Goal (Akshay):** Developer without VAST should be able to provision a CaaS cluster AND create volumes on it using LVMS — full E2E dev flow, no external storage backend needed.

**Architectural decision: Option B — LVMS directly on guest cluster workers** (not CSI→hub→LVMS).

Option A (CSI→hub→LVMS) is a dead end: local LVMS volumes on the hub are node-local and cannot be network-mounted by guest cluster workers. The OSAC CSI driver is designed for network-addressable backends (VAST NFS/block). Using it for local LVMS would require NFS-over-LVM — a hack that adds a non-existent layer.

Option B follows the existing `local_lvms_storage` pattern cleanly:
1. The dispatcher already has `_remote_kubeconfig` support (from `admin_kubeconfig` in the event)
2. `ensure_storage_class` extended to: get guest kubeconfig → install LVMS operator on guest → apply LVMCluster (auto-discovers second disk) → create per-tenant SC on guest cluster (`topolvm.io` provisioner)
3. PVCs served from guest worker's local disk — no cross-cluster I/O, no network bridging

**What OSAC-3234 needs to implement:**

| Piece | Owner | Notes |
|-------|-------|-------|
| `AGENT_VM_EXTRA_DISK_SIZE` in `setup-caas-agents.sh` (osac-installer) | Zoltan | Add env var; when set, create second qcow2 + add `--disk` to `virt-install`. Opt-in, BM nodes unaffected. |
| `local_lvms_storage/tasks/ensure_storage_class.yaml` | Zoltan | When `_remote_kubeconfig` is set (CaaS guest cluster), install LVMS on guest + apply LVMCluster + create SC on guest. Hub path unchanged. |
| `setup-remote-cluster.sh` hookup or removal | TBD | Script exists but never called automatically. Either hook into CaaS provisioning or remove — the new role action replaces it. |

**For production CaaS (bare metal):** Not needed. Physical nodes have data disks; LVMS auto-discovers them. No agent VM injection required.

---

## OSAC-3012 Design

LVMS is already fully operational on hypershift1 (481 days, active PVCs, `/dev/sdb` backing on physical nodes). Scope: add `local` StorageBackend + StorageTier pointing to `lvms-vg1` in `development/values.yaml`. No installer hook needed (LVMS pre-installed by MOC admins). Same mechanism as OSAC-3011.

---

## OSAC-3013 Dependency

| Half | Status | Notes |
|------|--------|-------|
| Operator (PR #354, Zoltan) | MERGEABLE — needs /lgtm | Force-pushed July 27, ok-to-test needed after force push |
| Operator (PR #375, Will) | CHANGES_REQUESTED (CodeRabbit) | CodeRabbit requested per-call gRPC deadlines + unmapped enum logging; Will addressing |
| AAP side (Zoltan, minimal) | **DONE** — `zszabo-rh/osac-aap:feat/OSAC-3013-aap-tier-extra-vars` | Playbooks now accept `ansible_eda.event.storage_tier_definitions` (dynamic) and fall back to `STORAGE_TIERS` env var; all 4 storage playbooks updated |

Will's plan: still needs to land after #375 merges. Our minimal AAP fix unblocks OSAC-3011 testing without waiting for Will's full redesign.

---

## PR Tracker

| PR | Repo | State | Next action |
|----|------|-------|-------------|
| #354 | osac-operator | CHANGES_REQUESTED (Akshay Jul 28, addressed) | Fixed: nil BackendsClient vs zero-backends message. Rebased + force-pushed Jul 28. Needs /ok-to-test then /lgtm |
| #375 | osac-operator | APPROVED (CodeRabbit Jul 27) | Ready — needs /lgtm from org member; ask at storage meeting |
| **#397** | **osac-operator** | **DRAFT (Jul 28)** | OSAC-3011: remove defaultStorageClassSentinel — awaiting E2E then mark ready |
| **#454** | **osac-aap** | **DRAFT (Jul 28)** | OSAC-3011: local_lvms_storage role — awaiting E2E then mark ready |
| **#474** | **osac-installer** | **DRAFT (Jul 28)** | OSAC-3011: register-local-storage hook + configure-lvms idempotency — awaiting E2E then mark ready |
| #151 | enhancement-proposals | CHANGES_REQUESTED (Akshay updated Jul 27) | Major redesign committed. Roy + Avishay review needed. Roy asked to take out of draft. |
| #146 | enhancement-proposals | REVIEW_REQUIRED | OSAC-1710 design — no new activity |

---

## Open Questions / Decisions Needed

1. **PR #354 /lgtm + ok-to-test** — Force-pushed July 27, CI was reset. Needs an org member to post `/ok-to-test` on PR #354 to re-trigger CI, then /lgtm from Akshay or Will.
2. ~~**OSAC-3013 AAP half**~~ — **minimal fix done** (July 27): `feat/OSAC-3013-aap-tier-extra-vars` pushed. Full redesign (Will's story) still needed; our minimal version unblocks OSAC-3011 testing.
3. **OSAC-3011 E2E remaining** — StorageBackend+StorageTier registered manually on edge-17 test cluster. AAP task worker stuck in wait-for-migrations (snapshot pre-existing issue, not our code). Need either: fix the snapshot AAP migration issue, or do fresh `make install` instead of snapshot restore to complete the tenant onboarding test.
3. ~~**Omer / CaaS flavor second disk**~~ — **resolved** (2026-07-27): tracked as OSAC-3234. Architecture decided: Option B (LVMS directly on guest workers, not CSI→hub). See OSAC-3234 Design section above.
4. **PR #151 credential transit** — Option A vs Option B. Akshay discussing with Roy. Not blocking OSAC-3011.
5. ~~**OSAC-3011 plan approval**~~ — **resolved**: approved July 24 meeting.
6. ~~**CaaS KubeVirt disk scope**~~ — **resolved**: separate ticket, two CaaS flavors, Akshay to create.
7. ~~**OSAC-3011 bridge approach**~~ — **resolved**: idempotent `configure-lvms.sh`.
8. ~~**OSAC-3012 Jira description**~~ — **resolved**.

---

## Key Contacts

| Person | Role | Current focus |
|--------|------|---------------|
| Akshay Nadkarni | Storage lead | OSAC-2776, PR #151, OSAC-3011 design reviews |
| Will Gordon | VAST + Tier API | PR #375 (OSAC-3013 operator), then AAP side |
| Roy Golan | CSI driver | PR #2, PR #151 credential question |
| Rastislav Wagner | osac-ui WG lead | No storage concerns (UI is stateless) |

---

## Recurring Notes

- **Status bot** fires Tue/Thu 8AM EDT in wg-osac-storage. No need to reply every time — reply when something significant changed.
- **Storage meeting** Tuesdays 9AM ET / 3PM CEST. Next: July 28. Agenda: OSAC-3011 implementation progress, PR #354, Will/OSAC-3013 AAP side.
- **OSAC-333** (old quota EP) — stale "In Progress", ownership moved to Ronnie Lazar's WG. Needs reassignment. Not yet actioned.
- **cluster-tool on edge-17**: cluster booted (July 27). See E2E Testing section below.

---

## OSAC-3011 E2E Testing Status (July 27)

**Cluster:** edge-17, `vmaas-4-22` flavor, cluster name `osac-3011`. Accessible via `ssh edge-17` + `export KUBECONFIG=/root/.kube/osac-3011.kubeconfig`.

**Test image:** `quay.io/rh-ee-zszabo/osac-operator:osac-3011-test`  
Built from integration branch `test/OSAC-3011-integration` on `osac-project/osac-operator`:  
= `main` + PR #354 (Backend API) + PR #375 (Tier API) + OSAC-3011 sentinel removal.

**AAP fork branch:** `zszabo-rh/osac-aap:test/OSAC-3011-combined`  
= OSAC-3011 `local_lvms_storage` role + OSAC-3013 AAP minimal fix (playbooks accept event tier defs).

### What was verified ✅
1. StorageBackend `local` (provider: `local_lvms`) — registered via private API, status: `STORAGE_BACKEND_STATE_READY`
2. StorageTier `local` (backend_id linked) — registered, status: `STORAGE_TIER_STATE_ACTIVE`
3. Operator running with test image — confirmed via `oc get deploy osac-operator -o jsonpath='{.spec.template.spec.containers[0].image}'`
4. Operator detects backend registered — logs show `handleBackendReadiness` routing correctly, tries to trigger AAP jobs
5. Operator logs `MissingStorageTier` warning — correct: tier `local` has no StorageClass yet (waiting for AAP to create one)
6. Sentinel removal confirmed — no `tenant=Default` fallback in operator logs
7. LVMS: `lvms-vg1` StorageClass (default) already exists on hub from snapshot; `WaitForFirstConsumer`

### What's blocked ❌
- **AAP task worker stuck** (`osac-aap-controller-task`) in `Init:wait-for-migrations` — this is a **pre-existing snapshot issue** (was at attempt 440 when we started, not caused by our changes). Without the task worker, AAP cannot execute jobs, so `ensure_storage_class` never runs and the per-tenant StorageClass is never created.
- Downstream: tenant onboarding flow (`StorageBackendReady` → `ClusterStorageReady`) not verifiable.

### How to resume E2E
**Option A (recommended):** Fix the AAP migration wait.
```bash
ssh edge-17
export KUBECONFIG=/root/.kube/osac-3011.kubeconfig
# The init container runs: wait-for-migrations (checks something in AAP postgres)
# Check what it checks:
oc logs osac-aap-controller-task-<pod> -n osac-e2e-ci -c init-database | tail -5
# AAP postgres pod: osac-aap-postgres-15-0
# Try querying: oc exec osac-aap-postgres-15-0 -- psql ...
```

**Option B:** Destroy the cluster and do a fresh `make install` (CI approach, avoids snapshot state entirely):
```bash
python3 /usr/local/bin/cluster-tool destroy osac-3011
python3 /usr/local/bin/cluster-tool boot --flavor vmaas-4-22 --name osac-3011 --pull-secret /root/pull-secret.json
cd /tmp/osac-installer && make install VALUES_FILE=values/vmaas-ci/values.yaml \
  --set operator.image.repository=quay.io/rh-ee-zszabo/osac-operator \
  --set operator.image.tag=osac-3011-test \
  --set aap.configAsCode.projectGitUri=https://github.com/zszabo-rh/osac-aap.git \
  --set aap.configAsCode.projectGitBranch=test/OSAC-3011-combined
```

### Current cluster state (as of July 27 EOD)
- `osac-operator`: 1/1 Running, test image ✅
- `fulfillment-grpc-server`: 1/1 Running ✅
- `fulfillment-rest-gateway`: 1/1 Running ✅
- `postgres` (fulfillment): 1/1 Running ✅
- `osac-aap-controller-task`: 0/4 Init:0/2 ❌ (stuck)
- `osac-aap-controller-web`: 1/1 Running ✅
- StorageBackend `local`: registered ✅
- StorageTier `local`: registered ✅
