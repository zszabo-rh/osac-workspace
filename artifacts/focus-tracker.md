# Focus Tracker

**Last session:** 2026-08-11 (OSAC-3886 analysis+bot handoff; PR #256 merge queue debug; fixer-bot GitHub App installed on forks; PR #201 Round 2 review → APPROVE; PR #199 all review feedback addressed — 4 fix commits pushed)
**Workspace:** osac-workspace

---

## Active Focus Areas

### Storage — OSAC-917 v0.2
**Status:** active  
**Read first:** `artifacts/storage-status-summary.md`  
**Jira keys:** OSAC-3234, OSAC-3013, OSAC-3702, OSAC-917  
**GitHub repos:** osac-project/osac (monorepo — ALL component work now here)  
**Tracked PRs:**
- osac#199 (OSAC-3234 CaaS LVMS — OPEN, APPROVED, all review feedback addressed, 10 commits; needs `lgtm` label to merge)
- osac#201 (Akshay OSAC-2872 Volume API/CRD — OPEN, Round 2 review APPROVE; one minor open: archived_volumes test missing)
- osac#223 (Akshay OSAC-2872 Volume controllers — OPEN DRAFT, CONFLICTING; needs Akshay rebase after #201 merges)
- osac#141 (Roy OSAC-3271 CSI — MERGED Aug 7 ✅)
- osac#256 (OSAC-3886 bot fix — OPEN, all checks pass, auto-merge enabled, merge queue processing)

**Next action:** Post PR #201 review comment (archived_volumes one-liner) + approve. Ping Akshay for `lgtm` on PR #199. Monitor PR #256 merge.

**Slack channels:** C0B6USDQ85S (wg-osac-storage), C08ESMFV85Q (wg-osac-eng)  
**Slack contacts:** anadkarn (Akshay), wgordon17 (Will), rgolan (Roy), eliorerz (Elior, CI/monorepo)  
**Keywords:** storage, LVMS, VAST, StorageClass, CSI, local-lvms, local-ceph, tier, backend, storage-operations-ig, OSAC-3011, OSAC-3013  

---

## Paused / Background

### Quota (OSAC-998)
**Status:** handed off — reviewer only  
**Notes:** Ownership moved to Ronnie Lazar's Metering/Billing/Quota WG. OSAC-333 needs reassignment in Jira. No action unless Ronnie asks for review.
