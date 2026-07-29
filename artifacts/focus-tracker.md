# Focus Tracker

**Last session:** 2026-07-29 (E2E complete on edge-17 ✅ — StorageClass created, all tenant conditions True; 3 bugs found and fixed in PRs; checkpoint taken mid-session, MOC E2E and edge-17 clean install pending)
**Workspace:** osac-workspace

---

## Active Focus Areas

### Storage — OSAC-917 v0.2
**Status:** active  
**Read first:** `artifacts/storage-status-summary.md`  
**Jira keys:** OSAC-3011, OSAC-3012, OSAC-3013, OSAC-917  
**GitHub repos:** osac-project/osac-operator, osac-project/osac-aap, osac-project/enhancement-proposals, osac-project/osac-installer  
**Tracked PRs:** osac-aap#454, osac-installer#474, osac-operator#397, enhancement-proposals#172, enhancement-proposals#146
**Next action:** MOC E2E — `make install-osac INSTALLER_NAMESPACE=osac-zszabo VALUES_FILE=values/development/values.yaml` with test image + fork branch overrides. Then edge-17 clean install (needs clarity on whether reprovisioning RHEL or using a no-OSAC cluster-tool flavor). All 3 OSAC-3011 PRs ready, need Akshay /lgtm before July 31.  
**Slack channels:** C0B6USDQ85S (wg-osac-storage), C08ESMFV85Q (wg-osac-eng)  
**Slack contacts:** anadkarn (Akshay), wgordon17 (Will), rgolan (Roy)  
**Keywords:** storage, LVMS, VAST, StorageClass, CSI, local-lvms, local-ceph, tier, backend, storage-operations-ig, OSAC-3011, OSAC-3013  

---

## Paused / Background

### Quota (OSAC-998)
**Status:** handed off — reviewer only  
**Notes:** Ownership moved to Ronnie Lazar's Metering/Billing/Quota WG. OSAC-333 needs reassignment in Jira. No action unless Ronnie asks for review.
