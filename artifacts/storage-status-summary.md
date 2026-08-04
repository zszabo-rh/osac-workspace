# OSAC Storage v0.2 — Status Summary

**Last updated:** 2026-08-05 EOD (osac#131 rebased, CodeRabbit cleared, CaaS E2E passing; OSAC-3234 implementation complete on `feat/OSAC-3234-caas-lvms`; edge-17 caas-dev cluster set up but access lost — recover or recreate tomorrow)  
**Owner:** Zoltan Szabo  
**Update this file** at the end of each working session. Read it first at the start of the next one.

---

## Active Epics (OSAC-917 children, all targeted 0.2-M2 = end of August)

| Epic | Assignee | Status | Summary |
|------|----------|--------|---------|
| OSAC-3011 | Zoltan | In Progress | Local/Dev/E2E CI Storage Setup — 3 PRs open, CodeRabbit addressed, E2E ✅, **Demo recorded** 2026-07-30. Needs Akshay /lgtm. |
| ~~OSAC-3012~~ | ~~Zoltan~~ | **CLOSED** 2026-07-29 | Covered by OSAC-3011 — LVMS fully operational on hypershift1 |
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

Option B follows the existing `lvms_storage` pattern cleanly:
1. The dispatcher already has `_remote_kubeconfig` support (from `admin_kubeconfig` in the event)
2. `ensure_storage_class` extended to: get guest kubeconfig → install LVMS operator on guest → apply LVMCluster (auto-discovers second disk) → create per-tenant SC on guest cluster (`topolvm.io` provisioner)
3. PVCs served from guest worker's local disk — no cross-cluster I/O, no network bridging

**CaaS deployment flow (confirmed from Aug 3 weekly demo, Trey West):**
- Flavor: `sno-4-22` (NOT `vmaas-4-22` — SNO is clean, no pre-baked operators)
- `cluster-tool pull sno-4-22` + `cluster-tool boot sno-4-22 <name>`
- `make install-operators` installs LVMS, CNV, MCE, AAP fresh (LVMS not pre-baked in sno flavor)
- `make install-osac` (Helm chart)
- CaaS-specific: update `clusterFulfillment` IG ConfigMap with DNS zone + AWS credentials for Route 53
- `setup-caas-agents.sh`: SSH to server, creates agent VM on hub network, boots with InfraEnv ISO, labels with CI worker resource class

**Key implication for OSAC-3234:** `sno-4-22` has NO pre-existing `lvms-vg1` (unlike `vmaas-4-22` which had it pre-baked). The full `configure-lvms.sh` LVMCluster creation path runs every time. The second disk on the agent VM (`AGENT_VM_EXTRA_DISK_SIZE`) is **genuinely required** — LVMS has no disk to manage without it.

**vmaas-4-22 vs sno-4-22:**
- `vmaas-4-22`: pre-baked with KubeVirt/CNV, LVMS already installed — used for VMaaS and OSAC-3011 demo
- `sno-4-22`: clean SNO, all operators installed fresh — used for CaaS development

**What OSAC-3234 needs to implement:**

| Piece | Owner | Notes |
|-------|-------|-------|
| `AGENT_VM_EXTRA_DISK_SIZE` in `setup-caas-agents.sh` (osac-installer) | Zoltan | Add env var; when set, create second qcow2 + add `--disk` to `virt-install`. Opt-in, BM nodes unaffected. |
| `lvms_storage/tasks/ensure_storage_class.yaml` | Zoltan | When `_remote_kubeconfig` is set (CaaS guest cluster), install LVMS on guest + apply LVMCluster + create SC on guest. Hub path unchanged. |
| `setup-remote-cluster.sh` hookup or removal | TBD | Script exists but never called automatically. Either hook into CaaS provisioning or remove — the new role action replaces it. |

**For production CaaS (bare metal):** Not needed. Physical nodes have data disks; LVMS auto-discovers them. No agent VM injection required.

---

## OSAC-3012 Design

LVMS is already fully operational on hypershift1 (481 days, active PVCs, `/dev/sdb` backing on physical nodes). Scope: add `local` StorageBackend + StorageTier pointing to `lvms-vg1` in `development/values.yaml`. No installer hook needed (LVMS pre-installed by MOC admins). Same mechanism as OSAC-3011.

---

## OSAC-3013 Dependency

| Half | Status | Notes |
|------|--------|-------|
| Operator (PR #354, Zoltan) | **MERGED** 2026-07-28 | ✅ |
| Operator (PR #375, Will) | **MERGED** 2026-07-29 | ✅ |
| AAP side (Zoltan, minimal) | **In PR #454** | Playbooks accept `ansible_eda.event.storage_tier_definitions` (event) + fall back to `STORAGE_TIERS` env var. Cherry-picked from `feat/OSAC-3013-aap-tier-extra-vars`. |
| AAP side (Will, full) | **Not started** | Will's scope: strip VAST credentials from `storage-operations-ig` pod spec; pass via extra_vars. Dependency documented in PR #454 description. Our PRs can merge without it. |

---

## PR Tracker

> **MONOREPO STATUS (as of Aug 4):** All component repos archived. Migration COMPLETE — single PR #131 covers all three components in one branch.

| PR | Repo | State | Notes |
|----|------|-------|-------|
| **osac#131** | **osac (monorepo)** | **WAITING /lgtm (Roy+Akshay must re-lgtm)** | OSAC-3011: rebased onto main (PR#98), CodeRabbit cleared (Default SC test fixture added). CaaS E2E now passing. VMaaS E2E flaky (infra issue, 3rd consecutive run). lgtm label cleared by rebase — do NOT rebase again, Tide handles it. Need /override from Eranco/Omer for VMaaS. |
| osac#99 | osac (monorepo) | **OPEN** | Will's OSAC-1992. When merged: drop STORAGE_TIERS fallback from osac#131. |
| osac#97 | osac (monorepo) | **Both lgtms, needs rebase** | OSAC-3547 EDA var rename. If merges before #131: rebase needed + rename ansible_eda.event.storage_tier_definitions → osac_job_vars.storage_tier_definitions in our code. |
| **osac#DRAFT** | **osac (monorepo)** | **NOT YET OPENED** | OSAC-3234: CaaS LVMS — branch `feat/OSAC-3234-caas-lvms` pushed. Needs test env recovery + testing before opening PR. |
| ~~#397, #454, #474~~ | archived repos | superseded by osac#131 | |

---

## Open Questions / Decisions Needed

1. **osac#131 /lgtm situation** — Roy /lgtm'd Aug 4; cleared by rebase push Aug 5. Akshay /lgtm never set. Both need to re-/lgtm on current HEAD (`8f482552`). Do NOT push or rebase — Tide merges automatically. Need /override from Eranco or Omer for VMaaS E2E flake (3 consecutive identical failures = infra issue).
2. **CaaS E2E now passing** on osac#131 — confirmed Aug 5 CI run. This is new and good.
3. **osac#97 (OSAC-3547)** — both Roy+Akshay lgtm'd Aug 4, needs rebase to merge. If it merges before #131: rebase #131 and rename `ansible_eda.event.storage_tier_definitions` → `osac_job_vars.storage_tier_definitions` in lvms_storage playbook.
4. **Will's osac#99 (OSAC-1992)** — when merged: drop STORAGE_TIERS fallback from osac#131.
5. **OSAC-3234 implementation COMPLETE** — see design section below. Branch `feat/OSAC-3234-caas-lvms` pushed. Needs test env to validate before opening draft PR.
6. **CSI driver** — Roy opened osac#141 (OSAC-3271: CSI Controller handlers via fulfillment service) Aug 4. This is the next CSI step after #94 merges. PR #94 reviewed today — Roy's own design comment on client.go:54 still unaddressed (key finding).

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

## OSAC-3011 E2E Testing Status — COMPLETE ✅ (2026-07-29)

Full E2E flow doc: `artifacts/osac-3011-e2e-flow.md`

**Cluster used:** edge-17, `vmaas-4-22` flavor, cluster `demo`, namespace `osac-e2e-ci`

### Full flow verified ✅
1. StorageBackend `local` (provider: `local_lvms`) — registered, `STORAGE_BACKEND_STATE_READY`
2. StorageTier `local` — registered, `STORAGE_TIER_STATE_ACTIVE`
3. Operator detects backend → triggers AAP job `osac-create-tenant-cluster-storage`
4. AAP runs `local_lvms_storage/tasks/ensure_storage_class.yaml` → creates `osac-shared-local` StorageClass
5. Tenant conditions: `StorageBackendReady=True`, `ClusterStorageReady=True`, `NamespaceReady=True`
6. PVC with `storageClassName: osac-shared-local` creatable (Pending = WaitForFirstConsumer, expected)

### Bugs found and fixed during E2E (all in PR #454 or #474)
- **Bug 1:** Provider name validator rejected underscores — fixed in PR #454
- **Bug 2:** Playbooks ignored operator event tier definitions — cherry-picked OSAC-3013 fix into PR #454
- **Bug 3:** Stage 2 playbooks read `tenant_name` from annotation only; Tenant CRs have no self-annotation — fixed to fall back to `metadata.name`

### MOC E2E — attempted, blocked (2026-07-29)
Fresh namespace deploy on hypershift1 hit 5 sequential blockers:
1. CRD ownership conflict (`--take-ownership` handled it, restored after)
2. Missing `fulfillment-controller-credentials` (per-namespace Phase 2 step skipped)
3. Keycloak issuer URL mismatch (external vs internal)
4. Operator OOMKilled at 128Mi limit
5. **Hard blocker:** AAP 2.6 dropped subscription manifest licensing — requires RHSM credentials. Not fixable without Red Hat portal access.

**Conclusion:** MOC fresh namespace installs are broken for anyone without a current RHSM service account. Existing namespaces (osac-ori, etc.) predate these issues. Not a storage problem — separate infra concern. OSAC-3012 closed as covered by OSAC-3011.

---

## Demo Status

**Plan:** `artifacts/demo-osac-3011.md`  
**Script:** `demos_and_workflows/osac-3011-storage/record-demo.sh`  
**Cast:** `demos_and_workflows/osac-3011-storage/osac-3011-demo.cast` — **RECORDED 2026-07-30** (8 attempts, 6 min, all scenes pass)

**Demo cluster:** edge-17, `osac-3011-demo` (vmaas-4-22 snapshot)

**Demo flow (5 scenes) — all verified working:**
1. ✅ LVMS ready, OSAC fulfillment pods at 0, no StorageBackend/Tier
2. ✅ refresh-after-snapshot.py — Phase 1-3 all pass, helm upgrade fires hook
3. ✅ StorageBackend `local` (READY) + StorageTier `local` (ACTIVE) via API
4. ✅ Create `demo` namespace + Tenant CR → conditions all True (~30s including AAP)
5. ✅ `osac-demo-local` StorageClass + PVC Pending (WaitForFirstConsumer)

**Key fixes applied on edge-17 (NOT in PRs, cluster-local only):**
- Chart template: added `private` to external-api Envoy regex
- refresh-after-snapshot.py: removed stale_ts timestamp check (already-running AAP never changes it)
- refresh-after-snapshot.py: server-side apply for large secrets
- values/vmaas-ci/values.yaml: `keycloak.issuerUrl` set to external URL
- refresh-after-snapshot.py: AAP wait timeout increased to 1200s
