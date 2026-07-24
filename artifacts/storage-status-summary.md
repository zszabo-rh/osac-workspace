# OSAC Storage v0.2 — Status Summary

**Last updated:** 2026-07-24 (pre-meeting)  
**Owner:** Zoltan Szabo  
**Update this file** at the end of each working session. Read it first at the start of the next one.

---

## Active Epics (OSAC-917 children, all targeted 0.2-M2 = end of August)

| Epic | Assignee | Status | Summary |
|------|----------|--------|---------|
| OSAC-3011 | Zoltan | In Progress | Local/Dev/E2E CI Storage Setup — see design section below |
| OSAC-3012 | Zoltan | New | MOC Developer Environment Storage Setup — LVMS already on MOC, scope = registration only |
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

**Plan posted to Jira description (July 24).** Pending Akshay approval in 14:30 meeting.

**CaaS guest cluster:** Out of scope. KubeVirt workers have only root disk (64Gi RHCOS, filesystem mode). Workload-only concern. Deferred.

---

## OSAC-3012 Design

LVMS is already fully operational on hypershift1 (481 days, active PVCs, `/dev/sdb` backing on physical nodes). Scope: add `local` StorageBackend + StorageTier pointing to `lvms-vg1` in `development/values.yaml`. No installer hook needed (LVMS pre-installed by MOC admins). Same mechanism as OSAC-3011.

---

## OSAC-3013 Dependency

| Half | Status | Notes |
|------|--------|-------|
| Operator (PR #354, Zoltan) | MERGEABLE — needs /lgtm | Force-pushed July 24, conflicts resolved |
| Operator (PR #375, Will) | CHANGES_REQUESTED (CodeRabbit) | Will addressed CodeRabbit; needs /lgtm |
| AAP side (Will) | Not started | Starts after PR #375 merges. Reads backend/tier from extra_vars instead of IG env vars |

Will's plan (status reply July 24): "Land #375, then kick off the osac-aap story consuming tier/backend extra_vars keys."

---

## PR Tracker

| PR | Repo | State | Next action |
|----|------|-------|-------------|
| #354 | osac-operator | MERGEABLE, APPROVED (CodeRabbit) | Needs human /lgtm from Akshay or Will |
| #375 | osac-operator | CHANGES_REQUESTED (CodeRabbit) | Will addressing; needs /lgtm after |
| #151 | enhancement-proposals | CHANGES_REQUESTED (10 comments) | Akshay addressing CodeRabbit. Credential transit gap needs design decision (Option A/B). Avishay design division question addressed. |
| #137 | enhancement-proposals | Open | OSAC-1710 ComputeInstance StorageTier Selection PRD — Carlo updated July 24 |
| #146 | enhancement-proposals | Open (draft) | OSAC-1710 design — Carlo updated July 24; ready for review |
| #2 | osac-csi-driver | Open | Roy. Self-approval; CodeRabbit to address |

---

## Open Questions / Decisions Needed

1. **OSAC-3011 plan approval** — pending Akshay in 14:30 meeting July 24.
2. **PR #354 /lgtm** — APPROVED+MERGEABLE since July 15, waiting for human sign-off from Akshay or Will.
3. **PR #151 credential transit** — Option A (fix the claim, creds transit in-flight) vs Option B (server-side proxy). Akshay discussing with Roy. Review comments drafted but not yet posted.
4. ~~**CaaS KubeVirt disk**~~ — **resolved**: out of scope, workload-only concern, deferred.
5. ~~**OSAC-3011 bridge approach**~~ — **resolved**: no bridge; idempotent `configure-lvms.sh` is the clean solution.
6. ~~**OSAC-3012 Jira description**~~ — **resolved**: comment posted July 23.

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
- **Storage meeting** Tuesdays 9AM ET / 3PM CEST. Next: July 28. Agenda: OSAC-3011 approval outcome, PR #354, IG/OSAC-3013 dependency.
- **OSAC-333** (old quota EP) — stale "In Progress", ownership moved to Ronnie Lazar's WG. Needs reassignment. Not yet actioned.
- **cluster-tool on edge-17**: deferred to Monday. Reinstall edge-17 with fresh RHEL 9 over the weekend first (removes resource contention with existing OCP SNO). Prerequisites confirmed: KVM loaded, Python 3.9, 315GB disk, 62GB RAM (fresh install removes the 32GB OCP overhead).
