# Focus Tracker

**Last session:** 2026-07-29 (Full day: E2E ✅, MOC E2E attempted+blocked (AAP 2.6 licensing), OSAC-3012 closed, CodeRabbit on all 3 PRs addressed, demo plan+script created, osac-3011-demo cluster booting on edge-17)
**Workspace:** osac-workspace

---

## Active Focus Areas

### Storage — OSAC-917 v0.2
**Status:** active  
**Read first:** `artifacts/storage-status-summary.md`  
**Jira keys:** OSAC-3011, OSAC-3012, OSAC-3013, OSAC-917  
**GitHub repos:** osac-project/osac-operator, osac-project/osac-aap, osac-project/enhancement-proposals, osac-project/osac-installer  
**Tracked PRs:** osac-aap#454, osac-installer#474, osac-operator#397, enhancement-proposals#172
**Next action:** (1) Confirm `osac-3011-demo` cluster API up on edge-17 (DNS fix was applied, kubelet restarted); (2) Run `make install-osac` with test image+fork branch overrides on that cluster; (3) Run `demos_and_workflows/osac-3011-storage/record-demo.sh`. Deadline: demo Monday Aug 3. All 3 OSAC-3011 PRs need Akshay /lgtm before July 31.  
**Slack channels:** C0B6USDQ85S (wg-osac-storage), C08ESMFV85Q (wg-osac-eng)  
**Slack contacts:** anadkarn (Akshay), wgordon17 (Will), rgolan (Roy)  
**Keywords:** storage, LVMS, VAST, StorageClass, CSI, local-lvms, local-ceph, tier, backend, storage-operations-ig, OSAC-3011, OSAC-3013  

---

## Paused / Background

### Quota (OSAC-998)
**Status:** handed off — reviewer only  
**Notes:** Ownership moved to Ronnie Lazar's Metering/Billing/Quota WG. OSAC-333 needs reassignment in Jira. No action unless Ronnie asks for review.
