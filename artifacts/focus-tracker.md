# Focus Tracker

**Last session:** 2026-08-05 (OSAC-3234 implemented + pushed; osac#131 rebased+CR cleared; edge-17 caas-dev cluster set up but lost access; PR #94 reviewed)
**Workspace:** osac-workspace

---

## Active Focus Areas

### Storage — OSAC-917 v0.2
**Status:** active  
**Read first:** `artifacts/storage-status-summary.md`  
**Jira keys:** OSAC-3011, OSAC-3012, OSAC-3013, OSAC-917  
**GitHub repos:** osac-project/osac (monorepo — ALL component work now here), osac-project/osac-installer (archiving soon), osac-project/enhancement-proposals  
**Tracked PRs:** osac#131 (OSAC-3011, WAITING /lgtm from Akshay+Roy re-lgtm; CaaS E2E now passes; VMaaS E2E flaky — needs /override from Eranco/Omer), osac#99 (Will's OSAC-1992, WAITING merge), osac#97 (OSAC-3547 EDA rename, both lgtms in, needs rebase — if merges before #131: rebase #131 for osac_job_vars rename)
**Next action:** (1) Akshay /lgtm on #131 this afternoon — don't rebase again, Tide handles it; (2) Ask Eranco or Omer for /retest or /override on VMaaS E2E flake; (3) OSAC-3234 branch `feat/OSAC-3234-caas-lvms` pushed, NOT yet draft PR — implementation complete, needs testing; (4) Recover edge-17 caas-dev cluster OR start from scratch (see test-env blocked item below); (5) After #131 merges: start OSAC-3234 PR and test on recovered env.  
**Slack channels:** C0B6USDQ85S (wg-osac-storage), C08ESMFV85Q (wg-osac-eng)  
**Slack contacts:** anadkarn (Akshay), wgordon17 (Will), rgolan (Roy), eliorerz (Elior, CI/monorepo)  
**Keywords:** storage, LVMS, VAST, StorageClass, CSI, local-lvms, local-ceph, tier, backend, storage-operations-ig, OSAC-3011, OSAC-3013  

---

## Paused / Background

### Quota (OSAC-998)
**Status:** handed off — reviewer only  
**Notes:** Ownership moved to Ronnie Lazar's Metering/Billing/Quota WG. OSAC-333 needs reassignment in Jira. No action unless Ronnie asks for review.
