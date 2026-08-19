# Focus Tracker

**Last session:** 2026-08-24 (PR #286 CI investigation — failures were STALE: e2e ran 2026-08-13 while the branch was 252 commits behind main; the metering fixes that turned main green (OSAC-3714 BSR→local proto, OSAC-3972 shared event schema → fixes `specversion: None`) were not in the branch. Rebased #286 on main + force-pushed to fork; re-triggered CI. vmaas e2e now green; caas e2e + metering unit test still red. ROOT-CAUSED the recurring osac-metering unit flake: `container.go:71` binds the Postgres container process to the BeforeSuite ctx via `exec.CommandContext`, and `postgres_test.go:47 defer cancel()` fires when BeforeSuite returns → SIGTERM/smart-shutdown to Postgres → new connections get 57P03 mid-suite. Introduced by OSAC-3418; ~37% flake on main itself (3/8 recent runs, identical signature); no ticket, team just /retests it. Slack MCP was down — used Slack web API directly via ~/.config/slack tokens. Prior session (2026-08-18): reviewed the 4 Volume PRs replacing #223, posted findings on #339/#340, built LVMS-CSI options doc, reviewed CSP admin UI for Elay.)
**Workspace:** osac-workspace

---

## Active Focus Areas

### Storage — OSAC-917 v0.2
**Status:** active  
**Read first:** `artifacts/storage-status-summary.md`  
**Jira keys:** OSAC-3234, OSAC-3013, OSAC-3702, OSAC-917  
**GitHub repos:** osac-project/osac (monorepo — ALL component work now here)  
**Tracked PRs:**
- osac#199 (OSAC-3234 CaaS LVMS — MERGED Aug 13 ✅)
- osac#201 (Volume API/CRD/DB — MERGED Aug 11 ✅)
- osac#223 (Volume controllers — CLOSED Aug 14, split into #339/#340/#341/#342)
- osac#286 (OSAC-3985 tier guard — OPEN, rebased on main 2026-08-24 head 5454b9f2; vmaas e2e green; STILL RED: caas e2e (+gate), osac-metering unit (flake), check-labels. caas e2e needs its own look — verify whether echo-adapter Service gap persists or is now something else; metering unit is the container.go ctx flake, not this PR)
- osac#327 (OSAC-4041 bot PR — MERGED ✅)
- osac#339 (OSAC-3276 Volume reconciler, fulfillment — OPEN; posted transient-error→FAILED finding, unaddressed)
- osac#340 (OSAC-3282/3283 Volume + feedback controllers, operator — OPEN; posted orphan-on-nil-provisioner-delete finding)
- osac#341 (OSAC-3274 remove pvcRef/pvRef — MERGED ✅)
- osac#342 (OSAC-3277 tier resolution at Volume create — MERGED ✅; closed the Backend-empty gap we flagged on #223)
- osac#188 (Roy OSAC-3289 vendor CSI controllers Helm chart — OPEN 11+ days; storage WG should review)
- osac#257 (Carlo OSAC-3632 per-disk StorageClass — OPEN DRAFT)

**Next action:** (1) LVMS decision — analyze Roy's Slack feedback: he leans **Option A** ("we can still work with A, lets see how far can we go"; says node-id via topology key in CreateRequest is enough, WaitForFirstConsumer handles the no-consumer-yet case, assume single cluster so hub can call topolvm-controller) — this CONTRADICTS the doc's "A ruled out." Re-read meeting transcript in Downloads (incl. non-LVMS-backend passthrough discussion) before deciding. (2) #286 — investigate why caas e2e still red (echo-adapter Service?); decide whether to raise the metering container.go ctx flake (draft-first: Slack to metering owner / Jira bug — fix = podman run under context.Background() or move cancel() to AfterSuite). (3) Pending reviews not yet done: EP #212, osac #369, #376, #340 (updated). (4) Review Roy's #188. (5) Resume K8s storage training Lesson 5. Reminder: Slack MCP down — use web API via ~/.config/slack tokens.

**Slack channels:** C0B6USDQ85S (wg-osac-storage), C08ESMFV85Q (wg-osac-eng)  
**Slack contacts:** anadkarn (Akshay), wgordon17 (Will), rgolan (Roy), eliorerz (Elior, CI/monorepo)  
**Keywords:** storage, LVMS, VAST, StorageClass, CSI, local-lvms, local-ceph, tier, backend, storage-operations-ig, OSAC-3011, OSAC-3013  

---

## Paused / Background

### Quota (OSAC-998)
**Status:** handed off — reviewer only  
**Notes:** Ownership moved to Ronnie Lazar's Metering/Billing/Quota WG. OSAC-333 needs reassignment in Jira. No action unless Ronnie asks for review.
