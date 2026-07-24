# OSAC Storage v0.2 — Status Summary

**Last updated:** 2026-07-24  
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
  - Hub cluster only — no guest cluster interaction (CaaS guest cluster scope deferred)
  - `ensure_storage_class`: creates per-tenant labeled SC using `lvms.topolvm.io` provisioner + OSAC labels via `kubernetes.core.k8s`
- `local_ceph_storage` AAP role — same shape for MOC/Ceph (OSAC-3012)
- osac-installer post-install hook: creates `local` StorageBackend (`provider: local-lvms`, `endpoint/credentials: n/a`) + `local` StorageTier via API when `lvms.enabled: true`
- osac-operator: remove `defaultStorageClassSentinel` (tenant=Default fallback) — only operator change

**StorageTier and StorageBackend both named:** `local`

**Instance group decision (July 24, confirmed):**  
No separate `localStorageFulfillment` IG. Once OSAC-3013 strips VAST credentials from `storage-operations-ig`, the `local_lvms_storage` role uses the same IG. Agreed by Akshay, Will, and Zoltan.

**Dependency model (July 24):**  
Will's PRs (#354, #375, then AAP half) must merge *before* OSAC-3011 PR merges — not before implementation starts. Implementation and testing proceed in parallel. If OSAC-3013 AAP half isn't ready by the time testing is needed, a WA will be decided then (not pre-committed). No bridge approach baked into the plan.

**CaaS scope decision (July 24):** Hub cluster only. KubeVirt guest cluster worker VMs on MOC have only root disk — LVMS needs a separate raw block device. Deferred.

**Note:** OSAC-3011 plan not yet approved. Implementation starts after approval.

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

1. **CaaS KubeVirt disk for OSAC-3011** — is provisioning extra raw block PVCs per worker VM in scope? Pending Akshay's response in DMs. (KubeVirt workers confirmed: only root disk, 64Gi filesystem mode, no raw block device available.)
2. ~~**OSAC-3011 bridge approach**~~ — **resolved**: use `storageFulfillment.enabled: true` with `VAST_ENDPOINT/USERNAME/PASSWORD: n/a` in CI values files. OSAC-3013 AAP half not started yet; bridge needed until it lands.
3. **PR #151 credential transit** — Option A (fix the claim, creds transit in-flight) vs Option B (server-side proxy). Akshay discussing with Roy. Review comments drafted (Finding 2 + 4) — not yet posted.
4. ~~**OSAC-3012 Jira description**~~ — **resolved**: comment posted July 23 confirming LVMS already on MOC. Description update still pending in Jira but low priority.

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

- **Status bot** fires Tue/Thu 8AM EDT in wg-osac-storage. Next: Tuesday July 28. Post if something significant changed.
- **Storage meeting** Tuesdays 9AM ET / 3PM CEST. Next: July 28. Agenda: OSAC-3011 progress, IG/OSAC-3013 dependency.
- **OSAC-333** (old quota EP) — 23+ days stale "In Progress", ownership moved to Ronnie Lazar's WG. Needs reassignment. Not yet actioned.
