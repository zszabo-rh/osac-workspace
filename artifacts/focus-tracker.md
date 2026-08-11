# Focus Tracker

**Last session:** 2026-08-11 (OSAC-3234 E2E complete — 2 bugs fixed, happy path + failure mode verified, PR #199 ready for review; reviewed PRs #201/#223 (Akshay Volume API+controllers); demo narration reviewed; edge-17 LOST to lab migration)
**Workspace:** osac-workspace

---

## Active Focus Areas

### Storage — OSAC-917 v0.2
**Status:** active  
**Read first:** `artifacts/storage-status-summary.md`  
**Jira keys:** OSAC-3234, OSAC-3013, OSAC-3702, OSAC-917  
**GitHub repos:** osac-project/osac (monorepo — ALL component work now here)  
**Tracked PRs:**
- osac#199 (OSAC-3234 CaaS LVMS — OPEN, APPROVED, READY FOR REVIEW, CI green, 6 commits; needs `lgtm` label to merge)
- osac#201 (Akshay OSAC-2872 Volume API/CRD — OPEN, reviewed with 7 findings; see storage-status-summary)
- osac#223 (Akshay OSAC-2872 Volume controllers — OPEN DRAFT, reviewed with 8 findings; see storage-status-summary)
- osac#141 (Roy OSAC-3271 CSI — BEHIND, needs Roy rebase)

**Next action:** Get `lgtm` on PR #199 (ping Akshay/Elior). When new server available, replicate CaaS env — see memory `project-caas-replication-guide.md`. Share PR #201/#223 review findings with Akshay.

**Slack channels:** C0B6USDQ85S (wg-osac-storage), C08ESMFV85Q (wg-osac-eng)  
**Slack contacts:** anadkarn (Akshay), wgordon17 (Will), rgolan (Roy), eliorerz (Elior, CI/monorepo)  
**Keywords:** storage, LVMS, VAST, StorageClass, CSI, local-lvms, local-ceph, tier, backend, storage-operations-ig, OSAC-3011, OSAC-3013  

---

## Paused / Background

### Quota (OSAC-998)
**Status:** handed off — reviewer only  
**Notes:** Ownership moved to Ronnie Lazar's Metering/Billing/Quota WG. OSAC-333 needs reassignment in Jira. No action unless Ronnie asks for review.
