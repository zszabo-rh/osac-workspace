# Focus Tracker

**Last session:** 2026-08-06 (OSAC-3011 osac#131 MERGED ✅; osac-test-infra#326 opened+merged fixing VMaaS CI; OSAC-3234 branch rebased on main; edge-17 SNAT fix attempted, ClusterOrder still progressing)
**Workspace:** osac-workspace

---

## Active Focus Areas

### Storage — OSAC-917 v0.2
**Status:** active  
**Read first:** `artifacts/storage-status-summary.md`  
**Jira keys:** OSAC-3011, OSAC-3012, OSAC-3013, OSAC-917  
**GitHub repos:** osac-project/osac (monorepo — ALL component work now here), osac-project/osac-installer (archiving soon), osac-project/enhancement-proposals  
**Tracked PRs:** osac#131 (OSAC-3011, **MERGED Aug 6** ✅ by Tide), osac-test-infra#326 (VMaaS CI fixes, **MERGED Aug 6** ✅), osac#141 (Roy OSAC-3271 CSI handlers, CONFLICTING — still open), osac#DRAFT (OSAC-3234 CaaS LVMS — branch `feat/OSAC-3234-caas-lvms` rebased on main, NOT yet draft PR — needs edge-17 E2E validation first)
**Next action:** (1) OSAC-3234: open draft PR after edge-17 E2E validates end-to-end flow; (2) edge-17 SNAT fix — verify if ClusterOrder recovered; (3) Reply to Akshay re StorageBackendStatus/ClusterStorageStatus (findings ready, drafted reply); (4) Akshay's nit on osac-test-infra#326 (add print() to storage wait fixture) — defer until next push needed  
**Slack channels:** C0B6USDQ85S (wg-osac-storage), C08ESMFV85Q (wg-osac-eng)  
**Slack contacts:** anadkarn (Akshay), wgordon17 (Will), rgolan (Roy), eliorerz (Elior, CI/monorepo)  
**Keywords:** storage, LVMS, VAST, StorageClass, CSI, local-lvms, local-ceph, tier, backend, storage-operations-ig, OSAC-3011, OSAC-3013  

---

## Paused / Background

### Quota (OSAC-998)
**Status:** handed off — reviewer only  
**Notes:** Ownership moved to Ronnie Lazar's Metering/Billing/Quota WG. OSAC-333 needs reassignment in Jira. No action unless Ronnie asks for review.
