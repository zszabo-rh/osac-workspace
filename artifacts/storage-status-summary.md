# OSAC Storage v0.2 — Status Summary

**Last updated:** 2026-07-28 (EOD — CodeRabbit comments addressed, CI fixes pushed, helm upgrade completed on edge-17, E2E blocked by AAP project pointing to wrong branch)  
**Owner:** Zoltan Szabo  
**Update this file** at the end of each working session. Read it first at the start of the next one.

---

## Active Epics (OSAC-917 children, all targeted 0.2-M2 = end of August)

| Epic | Assignee | Status | Summary |
|------|----------|--------|---------|
| OSAC-3011 | Zoltan | In Progress | Local/Dev/E2E CI Storage Setup — 3 PRs open (draft), CodeRabbit addressed, CI lint+helm fixed; E2E on edge-17 cluster `demo`: helm deployed, bootstrap done, AAP job 132 failed — root cause: AAP project points to upstream commit (no `local_lvms_storage` role) |
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
| ~~#354~~ | ~~osac-operator~~ | **MERGED** (2026-07-28 17:01 UTC) | ✅ |
| ~~#375~~ | ~~osac-operator~~ | **MERGED** (2026-07-29 01:19 UTC) | ✅ |
| **#397** | **osac-operator** | **DRAFT** | OSAC-3011: unused `allTenantReconcileRequests` removed (lint fix pushed Jul 28). Awaiting E2E then mark ready |
| **#454** | **osac-aap** | **DRAFT** | OSAC-3011: teardown robustness fix pushed Jul 28. Awaiting E2E then mark ready |
| **#474** | **osac-installer** | **DRAFT** | OSAC-3011: lvms values/schema, activeDeadlineSeconds 300→900, pipefail fix, securityContext hardening pushed Jul 28. Awaiting E2E then mark ready |
| #151 | enhancement-proposals | CHANGES_REQUESTED (Akshay updated Jul 27) | Major redesign committed. Roy + Avishay review needed. Roy asked to take out of draft. |
| #146 | enhancement-proposals | REVIEW_REQUIRED | OSAC-1710 design — no new activity |

---

## Open Questions / Decisions Needed

1. **PR #354 /lgtm + ok-to-test** — Force-pushed July 27, CI was reset. Needs an org member to post `/ok-to-test` on PR #354 to re-trigger CI, then /lgtm from Akshay or Will.
2. ~~**OSAC-3013 AAP half**~~ — **minimal fix done** (July 27): `feat/OSAC-3013-aap-tier-extra-vars` pushed. Full redesign (Will's story) still needed; our minimal version unblocks OSAC-3011 testing.
3. **OSAC-3011 E2E remaining** — Helm deployed, bootstrap done, operator polls AAP correctly. AAP job 132 (provision `shared` tenant) failed in ~30s. Root cause: AAP project points to upstream commit (`26399b50f9e63077eb6b80083328197eed4b880c`) which has no `local_lvms_storage` role. Fix: patch AAP project via API to use `zszabo-rh/osac-aap:test/OSAC-3011-combined`, clear tenant `clusterStorageJobs`, let operator retrigger. SSH to edge-17 was unreliable at EOD (lab network).
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

## OSAC-3011 E2E Testing Status (July 28 EOD)

**Cluster:** edge-17, `vmaas-4-22` flavor, cluster name `demo`.
```bash
ssh edge-17 && export KUBECONFIG=/root/.kube/demo.kubeconfig
```
**Namespace:** `osac-e2e-ci`

**Dependencies merged:**
- osac-operator#354 — merged 2026-07-28 17:01 UTC ✅
- osac-operator#375 — merged 2026-07-29 01:19 UTC ✅

**Note:** Test image `quay.io/rh-ee-zszabo/osac-operator:osac-3011-test` was built from `test/OSAC-3011-integration` (main + #354 + #375 + sentinel removal). Since both PRs are now on main, the test image is still valid — the integration branch equals upstream main + OSAC-3011 sentinel removal.

### Verified ✅
- StorageBackend `local` (provider: `local_lvms`) — registered, `STORAGE_BACKEND_STATE_READY`
- StorageTier `local` — registered, `STORAGE_TIER_STATE_ACTIVE`
- Operator (test image) — polls AAP correctly, finds template `osac-create-tenant-cluster-storage` (ID 49)
- Helm upgrade — deployed (revision 4), all pods Running
- AAP bootstrap — complete; job template ID 49 confirmed to exist

### Blocked ❌ — AAP project branch mismatch
AAP job 132 (provision `shared` tenant) launched and **failed in ~30 seconds**. Root cause: AAP project points to upstream osac-aap commit (`26399b50f9e63077eb6b80083328197eed4b880c` from `vmaas-ci/values.yaml`) which has **no `local_lvms_storage` role**. The role only exists on our fork branch.

### Next steps to complete E2E
1. **Patch AAP project via port-forward** (from edge-17 host):
```bash
export KUBECONFIG=/root/.kube/demo.kubeconfig
kubectl port-forward -n osac-e2e-ci svc/osac-aap-controller-service 8053:80 &
TOKEN=$(oc get secret -n osac-e2e-ci osac-aap-api-token -o jsonpath='{.data.token}' | base64 -d)
# Find project ID:
curl -s -H "Authorization: Bearer $TOKEN" http://localhost:8053/api/controller/v2/projects/ | python3 -c 'import sys,json; [print(p["id"],p["name"],p.get("scm_url","")) for p in json.load(sys.stdin).get("results",[])]'
# Patch to fork branch (replace <ID>):
curl -s -X PATCH -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"scm_url":"https://github.com/zszabo-rh/osac-aap","scm_branch":"test/OSAC-3011-combined"}' \
  http://localhost:8053/api/controller/v2/projects/<ID>/
curl -s -X POST -H "Authorization: Bearer $TOKEN" http://localhost:8053/api/controller/v2/projects/<ID>/update/
```
2. Clear failed job from tenant status:
```bash
oc patch tenant -n osac-e2e-ci shared --type=json \
  -p '[{"op":"replace","path":"/status/clusterStorageJobs","value":[]}]' --subresource=status
```
3. Watch operator trigger new AAP job → `osac-shared-local` StorageClass appears
4. Create test PVC → verify Bound
