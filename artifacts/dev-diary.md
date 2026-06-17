# OSAC Dev Diary

---

## 2026-06-17

### Active Tickets
- OSAC-1145: Split AAP storage playbooks into 4 lifecycle actions — In Progress, PR osac-aap#338 (CI:PASS, awaiting review)
- OSAC-56: VMaaS Tenant Storage Setup — In Progress (Critical), no PR
- OSAC-333: Finalize quota management EP — In Progress, STALE (43d no update)
- OSAC-104: Add storage-tier support to tenant StorageClass discovery — In Progress, STALE (43d no update)
- OSAC-1146/1144/1143/499/326/498: VMaaS Tenant Storage tasks — New/To Do

### Open PRs
- osac-aap#338: OSAC-23: Rename storage playbooks to match two-stage model — CI:PASS, Review:NONE (updated 2026-06-16)

### Milestones
- Late June 2026: Storage v0.1 — CaaS with VAST, StorageBackend/StorageTier CRs (~2 weeks)
- End of summer 2026: HIPAA + NIST 800-171 compliance

### Notes
- Repo updates: fulfillment-service +16 commits (console ping, VN triggers, grpc keepalive), osac-operator +7 (on feat/OSAC-23), osac-installer +9, docs +1
- @zszabo mentioned by Roy Golan: StorageBackend soft-delete/delete design question (wg-osac-storage) — needs reply
- Roy Golan: suggests renaming README.md → design.md in enhancement-proposals (conflicts with CLAUDE.md convention — needs clarification)
- Akshay: addressed zszabo comments on EP PR #52, asking PTAL
- Prow CI unstable (Omer Vishlitzky, Jun 16)
- Storage meeting Jun 16: backend designs published, tenant onboarding in testing, paired reviews adopted, resource shortage blocking cluster provisioning
- osac-operator fork: 11 ahead, 2 behind fork/feat/OSAC-23-storage-controller — push needed
- osac-aap: fork 4 ahead, 3 behind fork branch — diverged, needs attention



---

## 2026-06-16

### Active Tickets
- OSAC-1146: Trigger cleanup on resource deletion — New
- OSAC-1145: Split AAP storage playbooks — In Progress, PR #338 open (CI passing, 6 days old, has naming mismatch comment from Akshay)
- OSAC-1144: Tenant controller trigger ensure — New
- OSAC-1143: Tenant controller readiness gate change — New
- OSAC-499: Dedicated ServiceAccount with scoped RBAC — New
- OSAC-498: Use target cluster client — New
- OSAC-326: Demo: Storage Story — New
- OSAC-56: VMaaS Tenant Storage Setup (Epic) — In Progress
- OSAC-104: Add storage-tier support — In Progress
- OSAC-333: Finalize quota EP — In Progress
- OSAC-70: Quota Management (Epic) — New

### Open PRs
- osac-aap#338: OSAC-23 storage playbooks rename — CI: passing, Review: awaiting (created Jun 10, 6 days old, Akshay comment on naming mismatch)
- enhancement-proposals#28: Quota management EP — CHANGES_REQUESTED (mhrivnak PTO until Jun 24)

### Milestones
- Jun 15-22 (0-7 days away): hypershift1 DOWN for data center maintenance
- Late June (~14 days): Storage v0.1 target (CaaS only, boot volumes)

### Notes
- **Repo refresh**: enhancement-proposals design/OSAC-23 branch rebase CONFLICT (13 behind, 5 ahead) — needs manual rebase
- **Jira migration impact**: statusCategory filter not supported in new OSAC project, using status names instead
- **Meeting notes**: Jun 15 weekly demo processed — Project Management API + Networking Manager discussions, no storage content
- **Slack**: Akshay pushed design doc updates Jun 15, ready for review (PR #58); Elad's PR dashboard shows 5 need review, 29 CI failing; hypershift1 API cert expired overnight
- **PR #338 naming mismatch**: Akshay noted Jun 15 that playbook names diverge between PR and PRD/design (storage-class vs cluster-storage)

---

## 2026-06-15

### Active Tickets
- No assigned tickets in OSAC Jira

### Open PRs
- osac-aap#338: OSAC-23 rename storage playbooks — CI: passing, Review: awaiting first review (created Jun 10, 5 days old)
- enhancement-proposals#52: PRD for Tenant Storage Onboarding Rework — Review: REVIEW_REQUIRED, last commit Jun 15 00:02 (Akshay pushed updates Sat night)
- enhancement-proposals#28: Quota management EP — CHANGES_REQUESTED (mhrivnak on PTO until Jun 24), stale since Apr 10

### Repo Refresh
- **osac-workspace (main)**: CONFLICT — rebase failed (6 behind, 55 ahead), rolled back. Auto-backup commit history divergence.
- fulfillment-service (main): UPDATED — rebased 5 commits from origin/main
- osac-operator (feat/OSAC-23-storage-controller): OK — up to date (uncommitted changes)
- osac-aap (feat/OSAC-23-storage-playbooks): OK — up to date (uncommitted changes)
- osac-installer (main): UPDATED — rebased 1 commit, restored uncommitted changes
- osac-test-infra (main): OK — up to date
- enhancement-proposals (design/OSAC-23): OK — up to date
- docs (main): OK — up to date (uncommitted changes)

### New Meeting Notes
**gws fetch**: no new transcripts (last: Jun 9 Storage WG, 0h old, all processed)

### What Changed Overnight (weekend activity)
**PR Activity:**
- **PR #52** (enhancement-proposals): Akshay pushed new commit Sat Jun 14 night (00:02 UTC) — responded to Avishay's Friday feedback
- **PR #52**: Now shows REVIEW_REQUIRED (was showing coderabbitai APPROVED on Jun 11) — awaiting human approval
- **PR #338** (osac-aap): No activity — still awaiting first review (5 days old, CI green)
- **Akshay Slack mention** (Fri Jun 13): "zszabo and I have pushed out changes to the PRD and responded to your comments. PTAL." — indicates PR #52 ready for review

**Inbox Activity:**
- **Akshay GitHub activity** (Sun Jun 14 6:51pm): notification on enhancement-proposals PR (design doc, not PRD)
- **Atlassian API token expiry warning** (Sun Jun 14)
- Multiple osac-workspace PR Dashboard CI failures (weekend cron runs)

**Slack Highlights:**
- **Avishay** (Fri Jun 14): Reminder about AI workflow (PRD → Design → Implement), using /osac-feature, /prd, /design, /implement
- **Vitaliy** (Sat Jun 14): Issues with bootstrap.sh (forks all branches, no osac- prefix)
- **brotman** (Sat Jun 14): Published UI wizard PRD (PR #57) for v0.1 cluster/vm creation
- **Dan Manor** (Fri Jun 14): Looking for reviews on fulfillment-service#689 and osac-operator#293
- **Lars** (Fri Jun 14): MOC data center shutdown reminder (this week: Jun 15-22)
- **Omer** (Fri Jun 14): CI completely down (prow outage)

**Infrastructure:**
- **hypershift1 DOWN starting TODAY** (Jun 15-22) — 7-day E2E testing blackout begins

### Milestones
- **Jun 15-22** (TODAY–7 days): hypershift1 cluster DOWN for data center maintenance
- **Late June** (15 days away): Storage v0.1 target — CaaS only, boot volumes

### Focus Today
1. **Resolve osac-workspace rebase conflict** — 55 local commits (auto-backup history) vs 6 upstream; need to clean up or reset
2. **Check PR #52 status** — Akshay says "ready for review" after Sat night push; likely needs Avishay's approval
3. **PR #338 aging** — 5 days without review; consider pinging in Slack if no activity by EOD Mon

### Heads Up
- **hypershift1 DOWN all week** (Jun 15-22) — E2E testing blocked starting today
- **Michael Hrivnak PTO until Jun 24** (9 days) — quota EP #28 review blocked
- **Late June storage v0.1 deadline** (15 days away) — CaaS only, boot volumes
- **PR #338 needs review** — 5 days old, CI green, no human feedback yet
- **osac-workspace git state** — 55 auto-backup commits ahead of upstream, rebase conflicts; need to resolve before further work

---

## 2026-06-11

### Active Tickets
- OSAC-1145: Split AAP storage playbooks into 4 lifecycle actions — In Progress, PR #338 open (CI passing, awaiting review)

### Open PRs
- osac-aap#338: OSAC-1145 split storage playbooks — CI: passing, Review: awaiting approval (created Jun 10, fresh)
- enhancement-proposals#52: PRD for Tenant Storage Onboarding Rework — Review: coderabbitai APPROVED (last commit Jun 11 02:12), awaiting human review
- enhancement-proposals#28: Quota management EP — CHANGES_REQUESTED (mhrivnak, on PTO until Jun 24), stale since Apr 10

### Repo Refresh
- osac-workspace: 2 behind upstream/main (uncommitted changes, not rebased)
- enhancement-proposals: rebased 1 commit from origin/main (design/OSAC-23 branch)
- fulfillment-service: rebased 12 commits from origin/main
- osac-aap: rebased 9 commits on feat/OSAC-1145 branch
- osac-installer: rebased 22 commits from origin/main (stashed changes restored)
- osac-test-infra: rebased 7 commits from origin/main
- **osac-operator: CONFLICT** — feat/OSAC-23-tenantstorage-controller failed rebase (36 behind, 4 ahead), needs manual rebase

### New Meeting Notes
- Storage WG (Jun 9): V0.1 scope = CaaS only (late June deadline), boot volumes prioritized, storage quotas explicitly required for infra admins, multiple backend support needed for scaling

### What Changed Overnight
- **PR #52 approved by CodeRabbit** (was CHANGES_REQUESTED yesterday) — human review still needed from Akshay/Avishay
- **Akshay active on PR #52** — 12+ review comment exchanges Jun 10 evening (7-10pm ET)
- **PR #338 created** (osac-aap) — fresh, CI passing, awaiting first review
- **Michael Hrivnak on PTO** — confirmed Jun 10-24, affects quota EP #28 review timeline
- **Storage meeting Jun 9** — V0.1 scope locked to CaaS, storage quotas requirement confirmed
- **Multiple repos rebased** — 12-22 commits absorbed across fulfillment-service, osac-aap, osac-installer, osac-test-infra

### Focus Today
1. **Fix osac-operator rebase conflict** — feat/OSAC-23-tenantstorage-controller branch needs manual rebase (36 commits behind)
2. **Respond to Akshay's PRD feedback** if there are unresolved items on PR #52 (last activity was exchanges, not clear approval)
3. **Monitor PR #338** for review feedback (fresh PR, CI passing)

### Heads Up
- Michael Hrivnak PTO until Jun 24 — quota EP #28 review blocked
- hypershift1 DOWN Jun 15-22 (4 days away) — blocks E2E testing for 7 days
- Late June storage v0.1 deadline (19 days away) — CaaS only, boot volumes
- osac-operator branch 36 commits behind — manual rebase needed before any further TenantStorage work

---

## 2026-06-10

### Active Tickets
- OSAC-1145: Split AAP storage playbooks into 4 lifecycle actions — In Progress (branch rebased, 6 upstream commits absorbed)
- OSAC-333: Finalize quota management enhancement proposal — In Progress (PR #28 stale, mhrivnak on PTO until Jun 24)
- OSAC-104: Add storage-tier support to tenant StorageClass discovery — In Progress
- OSAC-56: VMaaS Tenant Storage Setup (Epic) — In Progress
- OSAC-1146/1144/1143/499/498: TenantStorage follow-on tasks — New/unstarted

### Open PRs
- enhancement-proposals#52: PRD for Tenant Storage Onboarding Rework — CHANGES_REQUESTED (coderabbitai: 1 critical, 7 major findings), Akshay updated + tagged for review
- enhancement-proposals#28: Quota management EP — CHANGES_REQUESTED (mhrivnak, on PTO until Jun 24), stale since Apr 10
