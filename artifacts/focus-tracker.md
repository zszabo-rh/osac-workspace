# Focus Tracker

**Last session:** 2026-08-06 (CodeRabbit re-review triggered on osac#131; confirmed no code changes needed from #97/#99 — lvms_storage role unaffected; edge-17 cluster recovery + OSAC-3234 E2E in progress)
**Workspace:** osac-workspace

---

## Active Focus Areas

### Storage — OSAC-917 v0.2
**Status:** active  
**Read first:** `artifacts/storage-status-summary.md`  
**Jira keys:** OSAC-3011, OSAC-3012, OSAC-3013, OSAC-917  
**GitHub repos:** osac-project/osac (monorepo — ALL component work now here), osac-project/osac-installer (archiving soon), osac-project/enhancement-proposals  
**Tracked PRs:** osac#131 (OSAC-3011, WAITING /lgtm Roy+Akshay; CodeRabbit re-review triggered Aug 6; VMaaS E2E flaky — needs /override from Eranco/Omer. No code changes needed from #97/#99 merges — lvms_storage unaffected), osac#141 (Roy OSAC-3271 CSI handlers, CONFLICTING)
**Next action:** (1) Wait for CodeRabbit re-review on #131; (2) Ask Eranco/Omer /override on VMaaS flake; (3) Get Roy+Akshay /lgtm; (4) OSAC-3234: recover edge-17 cluster, validate E2E, open draft PR; (5) Reply to Akshay's wg-osac-storage thread re StorageBackendStatus/ClusterStorageStatus  
**Slack channels:** C0B6USDQ85S (wg-osac-storage), C08ESMFV85Q (wg-osac-eng)  
**Slack contacts:** anadkarn (Akshay), wgordon17 (Will), rgolan (Roy), eliorerz (Elior, CI/monorepo)  
**Keywords:** storage, LVMS, VAST, StorageClass, CSI, local-lvms, local-ceph, tier, backend, storage-operations-ig, OSAC-3011, OSAC-3013  

---

## Paused / Background

### Quota (OSAC-998)
**Status:** handed off — reviewer only  
**Notes:** Ownership moved to Ronnie Lazar's Metering/Billing/Quota WG. OSAC-333 needs reassignment in Jira. No action unless Ronnie asks for review.
