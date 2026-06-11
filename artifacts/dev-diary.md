# OSAC Dev Diary

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

### Milestones
- Late June 2026: Storage v0.1 target — CaaS only (confirmed in Jun 9 storage meeting)
- Jun 15–22 2026: hypershift1 DOWN for data center maintenance

### Notes
- fulfillment-service: rebased 28 commits from origin/main (was stale)
- osac-aap: rebased 6 commits from origin/main (storage playbook branch current)
- osac-operator: 33 behind origin/main (dirty — TenantStorage work in progress, manual rebase needed)
- osac-installer: 10 behind origin/main (dirty — manual rebase needed)
- enhancement-proposals: rebased 4 commits from origin/main (prd/OSAC-23 branch current)
- Storage meeting Jun 9: V0.1 = CaaS only (end of month deadline), boot volumes prioritized, storage quotas needed
- Akshay: PRD ready for review, tagged @zszabo in wg-osac-storage
- Michael Hrivnak on PTO until Jun 24
- CI unstable: "Timeout waiting for CI resource provisioning" → /retest
- Elad: Swagger UI live at https://osac-project.github.io/fulfillment-service/
- ARPA-H/state initiative: deep planning this week with large team (Orran's message)


## 2026-06-09

### Active Tickets
- OSAC-1145: Split AAP storage playbooks into 4 lifecycle actions — In Progress, local implementation on feat/OSAC-1145-split-storage-playbooks branch
- OSAC-333: Finalize quota management enhancement proposal — In Progress
- OSAC-104: Add storage-tier support to tenant StorageClass discovery — In Progress
- OSAC-56: VMaaS Tenant Storage Setup (Epic) — In Progress

### Open PRs
- (none)

### Milestones
- Late June 2026: Storage v0.1 target (CaaS with VAST, TenantStorage EP)

### Notes
- OSAC-465 (ComputeInstance stuck) closed
- Recent commits (last 7 days):
  - osac-operator: TenantStorage CRD + controller implementation (4 commits on feat/OSAC-23-tenantstorage-controller)
  - osac-aap: AAP storage playbook split (1 commit on feat/OSAC-1145-split-storage-playbooks)
- New Jira tickets in backlog: OSAC-1146, OSAC-1144, OSAC-1143, OSAC-499, OSAC-498, OSAC-326, OSAC-70 (Epic)
- enhancement-proposals on branch prd/OSAC-23 (PRD work in progress)

---

## 2026-06-08 (Monday)

### Active Tickets
- No tickets currently assigned in Jira

### Open PRs
- enhancement-proposals#52: OSAC-23 PRD + Design — REVIEW_REQUIRED, CI passing, 5 unaddressed review comments from Akshay (Jun 5)
- enhancement-proposals#28: quota EP — CHANGES_REQUESTED (stale; on hold per Michael until metering direction settled)

### Milestones
- 2026-06-08: Q3 2026 Planning Kick-Off Meeting (4-5:30pm CEST)
- 2026-06-15–22: hypershift1 shutdown (7 days away)
- Late June 2026: Storage v0.1 target
- Late June 2026: Agentic SDLC Milestone 1

### Notes
- **Repo refresh**: osac-workspace updated (36 ahead, 28 behind origin/main), fulfillment-service rebased 16 commits, osac-installer rebased 16 commits, osac-test-infra rebased 7 commits, osac-aap rebased 5 commits on feat/OSAC-1145 branch
- **osac-operator rebase conflict**: feat/OSAC-23-tenantstorage-controller branch has conflict (29 commits behind, 4 ahead) — manual rebase needed
- **PR #52 needs review response**: 5 inline comments from Akshay on PRD clarity, decision references, CaaS storage timing, unnecessary content, OSAC storage controller scope
- **Inbox**: PR #631 review request from Ilya (websocket console), Q3 planning meeting today, weekly reports from Liat/Brett/Eugenia
- **Slack**: Avishay created #osac-questions channel, Rom asking about mockups + new associates onboarding (4+ joining Jun 9)
- **No new meeting transcripts** — folder current (0 hours old), all files processed

---

## 2026-06-05 (Thursday)

### Active Tickets
- OSAC-1145 (Split AAP storage playbooks into 4 actions) — In Progress (feature branch active)
- OSAC-56 (VMaaS Tenant Storage Setup) — In Progress/Critical
- OSAC-104 (Storage-tier SC discovery) — In Progress
- OSAC-333 (Finalize quota EP) — In Progress (stagnant — on hold per Michael)
- OSAC-70 (Quota Management) — New (epic, linked to NVIDIA-828)
- OSAC-1143 (Tenant controller: readiness gate SC → hub Secret) — New (Phase B)
- OSAC-1144 (Tenant controller: trigger osac-ensure-tenant-storage Phase 2) — New (Phase B)
- OSAC-1146 (Trigger osac-cleanup-tenant-storage on deletion) — New (Phase B)
- OSAC-498 (Tenant controller: use target cluster client) — New
- OSAC-499 (Tenant operations: dedicated SA with scoped RBAC) — New
- OSAC-326 (Demo: Storage Story) — New

### Open PRs
- enhancement-proposals#28: quota EP — CHANGES_REQUESTED (stale; on hold per Michael until metering direction settled)
