# OSAC Dev Diary

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

### Milestones
- 2026-06-15–22: hypershift1 shutdown (10 days away)
- Late June 2026: Storage v0.1 target
- Late June 2026: Agentic SDLC Milestone 1

### Notes
- **Repo refresh conflicts**: osac-operator on feat/OSAC-23-tenantstorage-controller has rebase conflict (24 commits behind, 4 ahead) — manual rebase needed
- **Local work in progress**: osac-aap on feat/OSAC-1145-split-storage-playbooks (Phase B), osac-operator on TenantStorage controller branch
- **Slack highlights**:
  - Ygal Blum: bootstrap.sh broken by `docs` directory collision — suggests renaming `docs` and `enhancement-proposals` to be fork-friendly
  - Will Gordon: asking if Catalog API should support storage-tier/storage-backend as generic types
  - Ethan Kim: CaaS prototype published (https://heyethankim.github.io/osac-caas/), catalog-based experience
  - Ilya S: all CRDs on dev cluster marked for deletion, stuck in Terminating — will patch finalizers if no objection
  - Roy Golan: storage backend EP#51 open for review
  - Akshay: detailed Liat feedback on storage screens, 3-phase workflow (Onboarding/Tenant/Resource), CaaS vs VMaaS SC timing differences
- **Inbox highlights**:
  - dbennett (Jun 4 02:27 UTC): PG16 adoption question — answered by Juan's PG18 PR#628
  - Stephen Benjamin: ai-helpers changes coming
  - GitHub workflow failure: PR Dashboard Data failed on osac-workspace main
  - Corporate noise: Career Week, GE Q&A, Z-Stream cadence changes
- **No new meeting transcripts** — all processed on Jun 4
- **Workspace activity**: 7 new commits on osac-workspace main (auto-backups), 17 on fulfillment-service, 13 on osac-installer, 9 on osac-test-infra, 4 on osac-aap, 1 on EPs

---

## 2026-06-04 (Wednesday)

### Active Tickets
- OSAC-179 (Remove deprecated status.storageClass) — **CLOSED** (PR #269 merged Jun 3)
- OSAC-56 (VMaaS Tenant Storage Setup) — In Progress/Critical
- OSAC-104 (Storage-tier SC discovery) — In Progress
- OSAC-333 (Finalize quota EP) — In Progress (stagnant — on hold per Michael)
- OSAC-70 (Quota Management) — New (epic, linked to NVIDIA-828)
- OSAC-1143 (Tenant controller: readiness gate SC → hub Secret) — New (Phase B)
- OSAC-1144 (Tenant controller: trigger osac-ensure-tenant-storage Phase 2) — New (Phase B)
- OSAC-1145 (Split AAP storage playbooks into 4 actions) — New (Phase B)
- OSAC-1146 (Trigger osac-cleanup-tenant-storage on deletion) — New (Phase B)
- OSAC-498 (Tenant controller: use target cluster client) — New
- OSAC-499 (Tenant operations: dedicated SA with scoped RBAC) — New
- OSAC-326 (Demo: Storage Story) — New

### Open PRs
- enhancement-proposals#28: quota EP — OPEN (stale; on hold per Michael until metering direction settled)

### Milestones
- 2026-06-15–22: hypershift1 shutdown (11 days away)
- Late June 2026: Storage v0.1 target
- Late June 2026: Agentic SDLC Milestone 1

### Notes
- **OSAC-179 CLOSED** — PR #269 merged, ticket closed
- **3 meetings processed (Jun 3)**:
  - *WG Storage*: Tier API prioritized for VMaaS; "backend" terminology adopted; per-provider proxy model; storage readiness decoupled from cluster status; PRD/design doc split formalized; V1 = attach network storage + validate PVCs; **Dylan onboarding** (VAST collab with Will)
  - *Full Team Weekly*: PRD/design doc split adopted project-wide; human-friendly resource names standard; weekly design reviews mandatory only for WG leads; Vladik adopting Cubert automation agent for OSAC; Alona opening Monday meetings to external community
  - *Weekly Report*: release milestones formalized (0.1/0.2/0.3); 0.1 = CaaS+VMaaS+BMaaS core; new workflow: Features→EPs→Epics→Tasks; new RFE ticket type; demos: bare metal profiles, catalog items, BCM, Enclave UI, Helm installer
- **PR #28 (quota EP)**: Vladik commented (Jun 3 01:36) proposing HostLease for bare metal tracking; Barakmor1 asking about scope (Jun 3 13:02); I replied explaining EP is on hold pending metering direction
- **Dan Manor: unified networking EP** — PR #50 opened on enhancement-proposals, covers VMaaS/CaaS/BMaaS networking unification. Tags everyone.
- **Juan Hernández: PG 15→18 upgrade** — PR #628 on fulfillment-service, no auto-migration (pre-release). Relates to dbennett's PG16 question.
- **Elad Tabak: PR dashboard** — new tool at osac-project.github.io/osac-workspace/pr-dashboard/. Oved concerned about CI issues visible there.
- **AAP CR broken on hypershift1** — rawagner reports AnsibleAutomationPlatform CR failing across namespaces (mtls attribute error). Oved escalated to Elior.
- **Akshay: Fix Version 0.1 assigned** to all Milestone 1.0 features. Epic owners asked to review/break down work.
- **Storage Jira tickets shared** by Akshay: OSAC-917 (Backend Framework), OSAC-1001 (Tenant Storage Lifecycle), OSAC-1191 (CaaS Storage)
- **Roy Golan sharing** Avishay's PRD+design example from flightctl
- **Rom Freiman joined** wg-osac-storage channel
- **Crystal Chun turned 30** — ran 30 miles in under 5 hours

---

## 2026-06-03 (Tuesday)

### Active Tickets
- OSAC-179 (Remove deprecated status.storageClass) — Review, **PR #269 MERGED overnight**
- OSAC-56 (VMaaS Tenant Storage Setup) — In Progress/Critical
- OSAC-104 (Storage-tier SC discovery) — In Progress
- OSAC-333 (Finalize quota EP) — In Progress (stagnant)
- OSAC-70 (Quota Management) — New (epic)
- OSAC-1143 (Tenant controller: readiness gate SC → hub Secret) — New (Phase B)
- OSAC-1144 (Tenant controller: trigger osac-ensure-tenant-storage Phase 2) — New (Phase B)
- OSAC-1145 (Split AAP storage playbooks into 4 actions) — New (Phase B)
- OSAC-1146 (Trigger osac-cleanup-tenant-storage on deletion) — New (Phase B)
- OSAC-498 (Tenant controller: use target cluster client) — New
- OSAC-499 (Tenant operations: dedicated SA with scoped RBAC) — New
- OSAC-326 (Demo: Storage Story) — New

### Open PRs
- enhancement-proposals#28: quota EP — CHANGES_REQUESTED (stale since April)

### Milestones
- 2026-06-15–22: hypershift1 shutdown (12 days away)
- Late June 2026: Storage v0.1 target
- Late June 2026: Agentic SDLC Milestone 1

### Notes
- **PR #269 MERGED overnight** — openshift-merge-bot merged at 03:33 UTC; OSAC-179 done!
- **Vladik commented on quota EP** — two new comments on PR #28 (Jun 2 evening)
- **WG Storage meeting Jun 2** — CaaS focus for 0.1, VAST backend, storage tiers via API, automated CSI driver install, storage info independent from tenant CR (modular), many action items for Akshay/Will/Avishay/Roy
- **Akshay updated OSAC-56** — Jira epic update Jun 2 21:23
- **Alona asking about Full Team meeting** — "do we need it tomorrow?" (Jun 4)
- **Piotr K: customer demo request** — looking for demo to show customer
- **Avishay: PRD vs design doc split proposal** — added to tomorrow's call agenda
- **Asaf + Liat: github-config PRs pending** — #83 and #88

---

## 2026-06-02 (Monday)

### Active Tickets
- OSAC-179 (Remove deprecated status.storageClass) — Review, PR #269 open, Akshay APPROVED with comment
- OSAC-56 (VMaaS Tenant Storage Setup) — In Progress/Critical (epic)
- OSAC-104 (Storage-tier SC discovery) — In Progress (story)
- OSAC-333 (Finalize quota EP) — In Progress (stagnant since May 5)
- OSAC-70 (Quota Management) — New (epic)
- OSAC-1143 (Tenant controller: readiness gate from SC to hub Secret) — New
- OSAC-1144 (Tenant controller: trigger osac-ensure-tenant-storage Phase 2) — New
- OSAC-1145 (Split AAP storage playbooks into 4 actions) — New
- OSAC-1146 (Trigger osac-cleanup-tenant-storage on deletion) — New
- OSAC-498 (Tenant controller: use target cluster client) — New
- OSAC-499 (Tenant operations: dedicated SA with scoped RBAC) — New
- OSAC-326 (Demo: Storage Story) — New

### Open PRs
- osac-operator#269: OSAC-179 — CI: e2e-vmaas FAILED (infra?), all other checks PASS. Review: APPROVED (Akshay) with 1 comment re: ToLower in groupByTier
- enhancement-proposals#28: quota EP — CHANGES_REQUESTED (stale since Apr 10)

### Milestones
- 2026-06-15–22: hypershift1 shutdown (data center maintenance) — 13 days away
- Late June 2026: Storage v0.1 target
- Late June 2026: Agentic SDLC Milestone 1

### Notes
- **Akshay approved PR #269** — but asked about ToLower in groupByTier: should mixed-case tier labels be rejected instead of normalized?
- **e2e-vmaas failed** on PR #269 — base SHA was b12cbfa (now 2 behind after rebase). May need re-trigger.
- **New Slack sub-channels created**: wg-osac-storage (C0B6USDQ85S), wg-osac-vmaas (C0B7GNC7UM8), wg-osac-bmaas (C0B6B7DK3HV), wg-osac-core (C0B6F4DNP3P)
- **Nick Carboni: component integration discussion** — how BMaaS/CaaS/networking compose at API level; consensus: resources should be visible, composition in Go not AAP, good defaults with flexibility
- **Avishay: annotation consistency PRs** — all repos switching osac.io → osac.openshift.io prefix (fulfillment-service#620, osac-aap#324, osac-workspace#35)
- **Juan: annotations shouldn't replace spec/status fields** — filed fulfillment-service#621 to codify this
- **Oved: /implement workflow volunteers** — Akshay, Will, David Crowder, Elad volunteered; Avishay hit model availability issue (opus-4-8[1m] not on Vertex)
- **osac-operator rebased** on feat/OSAC-179 branch — 2 commits from upstream, stash round-trip clean

---

## 2026-06-01 (Sunday)

### Active Tickets
- OSAC-56 (VMaaS Tenant Storage Setup) — In Progress/Critical (updated May 29, summary changed)
- OSAC-104 (Add storage-tier support) — In Progress (on hold)
- OSAC-333 (Finalize quota EP) — In Progress (stagnant since May 5)
- OSAC-70 (Quota Management) — New (epic)

### Open PRs
- None

### Repo Refresh
- fulfillment-service: UPDATED +5 (on OSAC-748 branch — PR merged May 12, **STALE**)
- osac-operator: UPDATED +8 (on feature/mgmt-23828 — PR #210 merged May 28, **STALE**)
- osac-aap: UPDATED +4 (on main, fork 210 ahead)
- osac-installer: UPDATED +7 (on MGMT-23998-console-rbac)

### New Meeting Notes
- None (weekend)

### Milestones
- **2026-06-01: MOC 2.0 dev cluster (TODAY!)**
- 2026-06-15–22: hypershift1 shutdown (data center maintenance)

### Notes
- **MOC 2.0 deadline is TODAY** — check with team tomorrow on status
- **OSAC-56 summary changed** — "Tenant Storage Provisioning using Tiers" → "VMaaS Tenant Storage Setup" (May 29)
- **OSAC-394 closed** — not in assigned tickets anymore; PR #210 merged May 28
- **Akshay resolved storage doc comment** — agreed to split teardown into two phases (reverse of creation): resource deletion (SCs+CSI from target), then tenant deletion (all targets + backend)
- **Crystal: tenant onboarding meeting Monday June 1** — OSAC-996 discussion scheduled
- **Akshay: Pure Storage integration** — asking for hard requirements/deadlines for Storage WG planning
- **Juan: FK constraint change coming** — fulfillment-service PR #603 will require organization to exist before creating resources; affects integration tests
- **Ilya: ProdSec config nitpicks** — CodeRabbit flagged security items on new component; none of existing components follow them
- **Dan Manor updated OSAC-473** — management-state unmanaged check missing DeletionTimestamp guard (parent: OSAC-68)
- **Oved created OSAC calendar** — working groups meetings being consolidated
- **Weekend activity quiet** — Slack daily standup still active

---

## 2026-05-29 (Thursday)

### Active Tickets
- OSAC-394 (Org Controller: Trigger Storage Provisioning) — **DONE: PR #210 MERGED May 28** — close ticket
- OSAC-278 (Ansible: Organization Storage Provisioning) — In Progress, PR #266 CLOSED — rebase and reopen
- OSAC-56 (Tenant Storage and Tiers) — In Progress/Critical (Akshay updated description today, storage meeting next week)
- OSAC-104 (Add storage-tier support) — In Progress (on hold)
- OSAC-333 (Finalize quota EP) — In Progress (stagnant)

### Open PRs
- **osac-operator#210: MERGED** May 28 17:21 UTC — OSAC-394 done! (Akshay retracted confusing comment, then approved)
- ~~osac-aap#266~~ — CLOSED May 27, local branch `feature/mgmt-23826-tenant-storage-provision` still intact

### Repo Refresh
- fulfillment-service: UPDATED +14 (on OSAC-748 branch — PR merged May 12, **need to switch to main**)
- osac-operator: UPDATED +3 (on feature/mgmt-23828 — PR #210 MERGED, **need to switch to main**)
- osac-aap: UPDATED +2 (on main, fork 206 ahead)
- osac-installer: UPDATED +9 (on MGMT-23998-console-rbac)

### New Meeting Notes
- Zoltan/Akshay 1:1 (May 29): Phase A complete (all 3 PRs resolved), Akshay to assign Phase B tasks June 2, OSAC-104 VAST integration blocked by secret access issue, hypershift1 shutdown June 15-22, Akshay traveling June 16-27
- OSAC Full Team Weekly (May 27): Quota EP roadblocked by security questions, TBD where it lands; OSAC-56 restructuring (6/10 tasks closed, 4 updated, 4 new Phase B tasks); Will's VAST PR #296 demo ready
- OSAC Working Groups (May 27): Bare metal progress, cluster sync w/ fulfillment-service, hypershift1 stability improvements, networking annotations cleanup
- OSAC Storage VMaaS/CaaS (May 26): 3-phase provisioning design (setup backend, provision tenant storage, ensure tenant readiness), quota-storage tier linkage, VAST demo by Will, Akshay to restructure OSAC-56 into clearer phases

### Milestones
- **2026-06-01: MOC 2.0 dev cluster** — 3 days away
- **2026-06-15–22: hypershift1 shutdown** — data center maintenance
- **Late June 2026: Storage v0.1 target** — VAST E2E for VMaaS, two-phase provisioning

### Notes
- **Phase A complete** — All three storage PRs resolved (PR #210 merged, #296 merged, #266 closed/superseded)
- **Akshay to assign Phase B tasks** — June 2 (today is May 29), refactoring to 4-action model from original 1-playbook
- **OSAC-104 blocked** — Will's VAST integration can't access secret in namespace, needs investigation
- **Quota EP stalled** — security questions unanswered, unclear when it will land
- **hypershift1 shutdown June 15-22** — Lars confirmed, affects E2E testing
- **Akshay traveling June 16-27** — planning around this
