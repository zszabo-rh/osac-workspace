# Focus Tracker

**Last session:** 2026-07-28 (CodeRabbit fixes pushed to all 3 OSAC-3011 PRs, CI lint/helm failures fixed, helm upgrade completed on edge-17, E2E blocked by AAP project branch mismatch)  
**Workspace:** osac-workspace

---

## Active Focus Areas

### Storage — OSAC-917 v0.2
**Status:** active  
**Read first:** `artifacts/storage-status-summary.md`  
**Jira keys:** OSAC-3011, OSAC-3012, OSAC-3013, OSAC-917  
**GitHub repos:** osac-project/osac-operator, osac-project/osac-aap, osac-project/enhancement-proposals, osac-project/osac-installer  
**Tracked PRs:** osac-aap#454, osac-installer#474, osac-operator#397, enhancement-proposals#151, enhancement-proposals#146
**Next action:** Patch AAP project on edge-17 to `zszabo-rh/osac-aap:test/OSAC-3011-combined` (steps in storage-status-summary.md E2E section) → clear tenant `clusterStorageJobs` → verify StorageClass created → mark 3 OSAC-3011 draft PRs ready for review  
**Slack channels:** C0B6USDQ85S (wg-osac-storage), C08ESMFV85Q (wg-osac-eng)  
**Slack contacts:** anadkarn (Akshay), wgordon17 (Will), rgolan (Roy)  
**Keywords:** storage, LVMS, VAST, StorageClass, CSI, local-lvms, local-ceph, tier, backend, storage-operations-ig, OSAC-3011, OSAC-3013  

---

## Paused / Background

### Quota (OSAC-998)
**Status:** handed off — reviewer only  
**Notes:** Ownership moved to Ronnie Lazar's Metering/Billing/Quota WG. OSAC-333 needs reassignment in Jira. No action unless Ronnie asks for review.
