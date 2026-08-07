# Focus Tracker

**Last session:** 2026-08-08 AM (OSAC-3234 PR #199: opened draft, addressed all CodeRabbit + user review comments, re-triggered CI — all checks green except `lgtm` label needed)
**Workspace:** osac-workspace

---

## Active Focus Areas

### Storage — OSAC-917 v0.2
**Status:** active  
**Read first:** `artifacts/storage-status-summary.md`  
**Jira keys:** OSAC-3234, OSAC-3013, OSAC-3702, OSAC-917  
**GitHub repos:** osac-project/osac (monorepo — ALL component work now here)  
**Tracked PRs:**
- osac#199 (OSAC-3234 CaaS LVMS — OPEN, APPROVED, MERGEABLE, all CI green, needs `lgtm` label; 4 commits on `feat/OSAC-3234-caas-lvms`, pushed to `zszabo-rh/osac` fork)
- osac#141 (Roy OSAC-3271 CSI, BEHIND, zszabo APPROVED — needs Roy rebase; CodeRabbit CHANGES_REQUESTED is stale/false-alarm per review)
- osac#198 (Omer OSAC-3712 — reviewed, LGTM with 2 nitpicks; fixes `lvms_storage_config_namespace` fallback)

**Next action:** Get `lgtm` label on PR #199 from a reviewer (Akshay/Elior suggested by CodeRabbit). Edge-17 E2E: CaaS LVMS install job 1038 was running when session ended — check if LVMS installed on guest cluster; hub Tenant storage path blocked by `tenant_name` issue (pre-existing, unrelated to PR).

**Slack channels:** C0B6USDQ85S (wg-osac-storage), C08ESMFV85Q (wg-osac-eng)  
**Slack contacts:** anadkarn (Akshay), wgordon17 (Will), rgolan (Roy), eliorerz (Elior, CI/monorepo)  
**Keywords:** storage, LVMS, VAST, StorageClass, CSI, local-lvms, local-ceph, tier, backend, storage-operations-ig, OSAC-3011, OSAC-3013  

---

## Paused / Background

### Quota (OSAC-998)
**Status:** handed off — reviewer only  
**Notes:** Ownership moved to Ronnie Lazar's Metering/Billing/Quota WG. OSAC-333 needs reassignment in Jira. No action unless Ronnie asks for review.
