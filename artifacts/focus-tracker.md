# Focus Tracker

**Last session:** 2026-07-30 mid-day checkpoint (PRs rebased+CodeRabbit addressed; demo cluster infrastructure debugging all day; vanilla OSAC up but fulfillment API routing broken — last blocker before recording)
**Workspace:** osac-workspace

---

## Active Focus Areas

### Storage — OSAC-917 v0.2
**Status:** active  
**Read first:** `artifacts/storage-status-summary.md`  
**Jira keys:** OSAC-3011, OSAC-3012, OSAC-3013, OSAC-917  
**GitHub repos:** osac-project/osac-operator, osac-project/osac-aap, osac-project/enhancement-proposals, osac-project/osac-installer  
**Tracked PRs:** osac-aap#454, osac-installer#474, osac-operator#397, enhancement-proposals#172, osac-workspace#173
**Next action:** (1) Fix Envoy ingress proxy 404 on `/api/private/v1/*` paths — all other OSAC pods 1/1, this is the last blocker; (2) Once API works, patch test values + run `upgrade_osac()` equivalent to fire register-local-storage hook; (3) Record demo. Deadline: demo Monday Aug 3. All 3 OSAC-3011 PRs need Akshay /lgtm before July 31.  
**Slack channels:** C0B6USDQ85S (wg-osac-storage), C08ESMFV85Q (wg-osac-eng)  
**Slack contacts:** anadkarn (Akshay), wgordon17 (Will), rgolan (Roy)  
**Keywords:** storage, LVMS, VAST, StorageClass, CSI, local-lvms, local-ceph, tier, backend, storage-operations-ig, OSAC-3011, OSAC-3013  

---

## Paused / Background

### Quota (OSAC-998)
**Status:** handed off — reviewer only  
**Notes:** Ownership moved to Ronnie Lazar's Metering/Billing/Quota WG. OSAC-333 needs reassignment in Jira. No action unless Ronnie asks for review.
