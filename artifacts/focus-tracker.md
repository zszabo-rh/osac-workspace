# Focus Tracker

**Last session:** 2026-08-14 (PR #286 nits addressed + pushed to fork — all CI pre-existing; PR #327 OSAC-4041 bot PR analyzed — fullsend APPROVED, needs our /lgtm + /approve; OSAC-4041 Bug ticket filed + linked to OSAC-917; K8s storage training Lesson 4 (LVMS internals) delivered; graphify installed + graph fetched (99,990 nodes))
**Workspace:** osac-workspace

---

## Active Focus Areas

### Storage — OSAC-917 v0.2
**Status:** active  
**Read first:** `artifacts/storage-status-summary.md`  
**Jira keys:** OSAC-3234, OSAC-3013, OSAC-3702, OSAC-917  
**GitHub repos:** osac-project/osac (monorepo — ALL component work now here)  
**Tracked PRs:**
- osac#199 (OSAC-3234 CaaS LVMS — OPEN, APPROVED, e2e-caas PASS; needs `lgtm` from Akshay/Elior)
- osac#201 (Akshay OSAC-2872 Volume API/CRD — OPEN; needs our archived_volumes comment + approve)
- osac#223 (Akshay OSAC-2872 Volume controllers — OPEN DRAFT, CONFLICTING; needs rebase after #201 merges)
- osac#256 (OSAC-3886 bot fix — MERGED Aug 11 ✅)
- osac#257 (Carlo OSAC-3632 per-disk StorageClass — OPEN DRAFT; Carlo fixing storageTier defaults; post cross-check comment after)
- osac#286 (OSAC-3985 tier guard — OPEN, nits addressed Aug 14; needs /lgtm from Akshay)
- osac#327 (OSAC-4041 bot PR — OPEN, fullsend APPROVED; needs our /lgtm + /approve)

**Next action:** Post /lgtm + /approve on PR #327. Ping Akshay for /lgtm on PR #286. Post PR #201 archived_volumes comment + approve. Ping Akshay/Elior for lgtm on #199. Resume K8s storage training (Lesson 5: block vs file, RWO/RWX, protocols). Ping Elior about graphify auto-fetch SessionStart hook ETA.

**Slack channels:** C0B6USDQ85S (wg-osac-storage), C08ESMFV85Q (wg-osac-eng)  
**Slack contacts:** anadkarn (Akshay), wgordon17 (Will), rgolan (Roy), eliorerz (Elior, CI/monorepo)  
**Keywords:** storage, LVMS, VAST, StorageClass, CSI, local-lvms, local-ceph, tier, backend, storage-operations-ig, OSAC-3011, OSAC-3013  

---

## Paused / Background

### Quota (OSAC-998)
**Status:** handed off — reviewer only  
**Notes:** Ownership moved to Ronnie Lazar's Metering/Billing/Quota WG. OSAC-333 needs reassignment in Jira. No action unless Ronnie asks for review.
