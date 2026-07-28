# OSAC Storage v0.2 — Status Summary

**Last updated:** 2026-07-27 (end of day)  
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

**Plan approved by Akshay July 24 meeting.** Implementation starts Monday July 28.

**Target: working dev setup by Friday July 31. Demo: Monday August 3.**
Demo scope: hub cluster boots → StorageBackend + StorageTier auto-registered → tenant onboarded → StorageClass created via AAP → PVC bindable on hub cluster. Using LVMS (not new CSI control plane).

**CaaS guest cluster:** Out of scope for OSAC-3011. Separate ticket to be created by Akshay — two cluster-tool CaaS flavors: one without storage (general use), one with storage (storage team / E2E). Zoltan to contact Omer (cluster-tool owner) Monday to ask about second disk configuration in CaaS flavor.

**storage.enabled vs storageFulfillment.enabled (clarified July 24):**
- `storage.enabled` = storage **controller** on/off
- `storageFulfillment.enabled` = AAP **instance group** (dummy secrets, config)
- Bug path without PR #354: controller enabled + storageFulfillment disabled → no dummy secrets → `create_tenant_storage_backend` playbook fails

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
| #354 | osac-operator | APPROVED (CodeRabbit), BLOCKED | Force-pushed July 27 — CI re-triggered, ok-to-test needed from org member |
| #375 | osac-operator | CHANGES_REQUESTED (CodeRabbit Jul 25) | Will needs to address: gRPC per-call deadlines + unmapped enum logging |
| #151 | enhancement-proposals | CHANGES_REQUESTED (10 comments) | Akshay addressing CodeRabbit. Credential transit gap needs design decision (Option A/B). Avishay design division question addressed. |
| ~~#137~~ | enhancement-proposals | **MERGED** | OSAC-1710 ComputeInstance StorageTier Selection PRD |
| #146 | enhancement-proposals | REVIEW_REQUIRED | OSAC-1710 design — Carlo; needs review |
| ~~#2~~ | osac-csi-driver | **MERGED** | Roy's CSI PoC — merged Jul 21 |

---

## Open Questions / Decisions Needed

1. **PR #354 /lgtm + ok-to-test** — Force-pushed July 27, CI was reset. Needs an org member to post `/ok-to-test` on PR #354 to re-trigger CI, then /lgtm from Akshay or Will.
2. ~~**OSAC-3013 AAP half**~~ — **minimal fix done** (July 27): `feat/OSAC-3013-aap-tier-extra-vars` pushed. Full redesign (Will's story) still needed; our minimal version unblocks OSAC-3011 testing.
3. **OSAC-3011 E2E remaining** — StorageBackend+StorageTier registered manually on edge-17 test cluster. AAP task worker stuck in wait-for-migrations (snapshot pre-existing issue, not our code). Need either: fix the snapshot AAP migration issue, or do fresh `make install` instead of snapshot restore to complete the tenant onboarding test.
3. ~~**Omer / CaaS flavor second disk**~~ — **resolved** (2026-07-27): no Omer contact needed. cluster-tool only manages the SNO hub VM; agent VMs are owned by `setup-caas-agents.sh` in osac-installer. Hub LVMS is already compatible (`caas-ci/vmaas-ci` values have `lvms.enabled: true`; hub SNO flavor has a second disk embedded in the snapshot). Future full-E2E-LVMS ticket will need: (1) `AGENT_VM_EXTRA_DISK_SIZE` in `setup-caas-agents.sh`, (2) hook `setup-remote-cluster.sh` into CaaS post-provisioning flow, (3) CSI driver or separate path to serve PVCs from guest-cluster LVMS. Out of scope for OSAC-3011.
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
- **cluster-tool on edge-17**: deferred to Monday. Reinstall edge-17 with fresh RHEL 9 over the weekend first (removes resource contention with existing OCP SNO). Prerequisites confirmed: KVM loaded, Python 3.9, 315GB disk, 62GB RAM (fresh install removes the 32GB OCP overhead).
