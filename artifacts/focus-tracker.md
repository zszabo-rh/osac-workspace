# Focus Tracker

**Last session:** 2026-08-18 (Reviewed all 4 Volume PRs that replaced #223 — #342 tier-resolution MERGED, #341 remove-pvcRef MERGED, #339 reconciler + #340 controllers OPEN; posted findings on #339 (transient-error→permanent FAILED regression) and #340 (orphan vendor volume on nil-provisioner delete, tied to Roy fail-closed point); built full LVMS-CSI options analysis doc (artifacts/lvms-csi/, HTML+PDF+docx, 7 diagrams) — dev-only premise → B vs C, avoid A; prepared WG speech; reviewed CSP admin storage UI for Elay (quota-on-association OK, protocol mutual-exclusion good, autocomplete nit); PR #286 CI failures confirmed pre-existing metering-adapter infra, not the PR)
**Workspace:** osac-workspace

---

## Active Focus Areas

### Storage — OSAC-917 v0.2
**Status:** active  
**Read first:** `artifacts/storage-status-summary.md`  
**Jira keys:** OSAC-3234, OSAC-3013, OSAC-3702, OSAC-917  
**GitHub repos:** osac-project/osac (monorepo — ALL component work now here)  
**Tracked PRs:**
- osac#199 (OSAC-3234 CaaS LVMS — MERGED Aug 13 ✅)
- osac#201 (Volume API/CRD/DB — MERGED Aug 11 ✅)
- osac#223 (Volume controllers — CLOSED Aug 14, split into #339/#340/#341/#342)
- osac#286 (OSAC-3985 tier guard — OPEN; CI failures pre-existing metering infra; waiting Friday sync /lgtm — will NOT ping, synced weekly)
- osac#327 (OSAC-4041 bot PR — MERGED ✅)
- osac#339 (OSAC-3276 Volume reconciler, fulfillment — OPEN; posted transient-error→FAILED finding, unaddressed)
- osac#340 (OSAC-3282/3283 Volume + feedback controllers, operator — OPEN; posted orphan-on-nil-provisioner-delete finding)
- osac#341 (OSAC-3274 remove pvcRef/pvRef — MERGED ✅)
- osac#342 (OSAC-3277 tier resolution at Volume create — MERGED ✅; closed the Backend-empty gap we flagged on #223)
- osac#188 (Roy OSAC-3289 vendor CSI controllers Helm chart — OPEN 11+ days; storage WG should review)
- osac#257 (Carlo OSAC-3632 per-disk StorageClass — OPEN DRAFT)

**Next action:** Deliver LVMS-CSI options at WG (speech ready; doc in artifacts/lvms-csi/). Speak-up opportunities analyzed for WG agenda (OSAC-984 node-local incompatibility, quota placement, DeleteOnTermination-vs-ReclaimPolicy). Confirm B1-vs-B2 realization with Roy if B chosen. Send Elay the CSP-UI feedback draft (quota-on-association confirm, protocol-vs-backend-capability model Q, autocomplete nit). Review Roy's #188. Resume K8s storage training Lesson 5.

**Slack channels:** C0B6USDQ85S (wg-osac-storage), C08ESMFV85Q (wg-osac-eng)  
**Slack contacts:** anadkarn (Akshay), wgordon17 (Will), rgolan (Roy), eliorerz (Elior, CI/monorepo)  
**Keywords:** storage, LVMS, VAST, StorageClass, CSI, local-lvms, local-ceph, tier, backend, storage-operations-ig, OSAC-3011, OSAC-3013  

---

## Paused / Background

### Quota (OSAC-998)
**Status:** handed off — reviewer only  
**Notes:** Ownership moved to Ronnie Lazar's Metering/Billing/Quota WG. OSAC-333 needs reassignment in Jira. No action unless Ronnie asks for review.
