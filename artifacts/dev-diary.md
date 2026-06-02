# OSAC Dev Diary

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
- None since May 27 (no meetings May 28)

### Milestones
- 2026-06-01: MOC 2.0 dev cluster (**3 days!**)
- 2026-06-15–22: **hypershift1 shutdown** (data center maintenance, Lars confirmed)

### Notes
- **PR #210 MERGED** — major win; Akshay approved after retracting misleading comment; merge bot confirmed
- **Akshay storage doc** — Google Doc covering 3 storage phases, open questions, decisions; permissions updated for comment/edit; review before next storage meeting
- **Akshay storage meeting next week** — June delivery + gap identification; cc'd zszabo, Avishay, Alona, Michael, Oved, Lars, Roy Golan, Ygal Blum
- **Oved: /implement workflow volunteers** — Eran's agentic SDLC workflow ready for testing; steps: /ingest → /plan → /revise → /implement:code → /validate → /publish → /respond; requires Opus 1M
- **osac-operator CI failing** — Akshay investigating PublicIPAttachment resource issue; hold new PRs
- **Alona removed daily standup** — working groups replace it
- **osac-installer bump PRs** — Omer planning to remove auto-bump actions, replace with scheduled consolidation
- **hypershift1 down June 15-22** — blocks E2E testing for 1 week; impacts MOC 2.0 and Agentic SDLC milestones

---

## 2026-05-28 (Wednesday)

### Active Tickets
- OSAC-394 (Org Controller: Trigger Storage Provisioning) — In Progress, PR osac-operator#210 (29d, needs response to Akshay review)
- OSAC-278 (Ansible: Organization Storage Provisioning) — In Progress, **PR #266 CLOSED** (need to fix rebase and reopen)
- OSAC-56 (Tenant Storage and Tiers) — In Progress/Critical (epic, updated May 26)
- OSAC-104 (Add storage-tier support) — In Progress
- OSAC-333 (Finalize quota EP) — In Progress (5 commits in last 7d)

### Open PRs
- osac-operator#210: OSAC-394 — 29d, CI:pass, **Akshay COMMENTED May 27** (informer cache race condition)
- ~~osac-aap#266~~ — **CLOSED May 27** without merging (local branch still has work)

### Repo Refresh
- fulfillment-service: UPDATED +14 (still on OSAC-748 branch — **need to switch to main**)
- osac-aap: **CONFLICT worsening** (11 behind, 6 ahead) — blocks PR #266 work
- osac-operator: UPDATED +9
- osac-installer: UPDATED +26
- osac-test-infra: UPDATED +7
- github-config: UPDATED +1
- osac-ui: UPDATED +1

### New Meeting Notes
- **OSAC - Working Groups** (May 27): Team restructuring, Agentic SDLC strategy (Milestone 1 late June), Eran building harness
- **OSAC Full Team Weekly** (May 27): Jira updates (3 milestones, RFE type), bare metal profile demo, Enclave wizard

### Milestones
- 2026-06-01: MOC 2.0 dev cluster (**4 days!**)

### Notes
- **PR #266 closed** — 28-day old osac-aap PR closed without merge; local branch has all work, needs rebase fix first
- **Akshay review on PR #210** — identified informer cache race: immediate requeue may hit stale cache, suggests 5s delay
- **osac-aap rebase conflict worse** — 11 behind now (was 7 on May 27), critical blocker for storage work
- **Unanswered Slack messages** — Oved (May 18, 10d old), Akshay EDA question (May 18, 10d old)
- **Inbox activity** — 6 GitHub notifications from Akshay on PR #210, 2 Jira notifications on OSAC-56
- Working Groups restructuring announced — Lead/Manager/Architect/PM roles per WG
- Agentic SDLC push — team encouraged to explore AI skills, Eran building harness

---

## 2026-05-27 (Tuesday)

### Active Tickets
- OSAC-394 (Org Controller: Trigger Storage Provisioning) — In Progress, PR osac-operator#210 (28d!)
- OSAC-278 (Ansible: Organization Storage Provisioning Playbook) — In Progress, PR osac-aap#266 (28d!, updated May 26)
- OSAC-56 (Tenant Storage and Tiers) — In Progress/Critical (epic, updated May 26)
- OSAC-104 (Add storage-tier support) — In Progress
- OSAC-333 (Finalize quota EP) — In Progress (stagnant since May 5)
- OSAC-70 (Quota Management) — New (epic)
- OSAC-498 (Tenant controller: use target cluster client) — New
- OSAC-499 (Tenant ops: dedicated ServiceAccount) — New
- OSAC-326 (Demo: Storage Story) — New
- OSAC-179 (Remove deprecated status.storageClass field) — New

### Open PRs
- osac-operator#210: OSAC-394 — 28d, CI:pass, tzvatot COMMENTED May 13 (not blocking)
- osac-aap#266: OSAC-278 — 28d, CI:pass, adriengentil COMMENTED Apr 28, **updated May 26**

### Repo Refresh
- fulfillment-service: UPDATED +9 (still on OSAC-748 branch merged May 12 — **switch to main**)
- osac-aap: **CONFLICT** (7 behind, 6 ahead) — manual rebase required
- osac-operator: OK (+7 behind fork — need to push)
- All others: OK

### New Meeting Notes
- **OSAC Storage (for VMaaS and CaaS)** — May 26: 3-phase storage workflow, pre-provision strategy, Akshay actions (finalize tier process with Avishay, rework storage epic, evaluate OpenStack integration)

### Milestones
- 2026-06-01: MOC 2.0 dev cluster (5d away!)

### Notes
- **fulfillment-service branch stale**: Still on OSAC-748-console-authconfig-fix (PR merged May 12, 2 weeks ago) — updated to +9 ahead of upstream/main after rebase
- **osac-aap rebase conflict persists**: Same as May 21 — 7 commits behind, manual rebase needed
- **PR #266 updated yesterday** (May 26 09:56) — check what changed
- Akshay storage doc PTALs from May 21 still outstanding
- Oved May 18 question about storage epics meeting unanswered
- Will Gordon VAST PR #296 ready, demo available
- Elad PR status bot: PRs #210 and #266 both flagged :rotating_light: 27d stale (now 28d)
- Juan: fulfillment-service unit tests now run with full DB migrations
- Ygal: CoW volume assumption warning for VM images
- Ori: osac-test-infra version release procedure question
- Roy: multi-vendor storage consumption question for Akshay

---

## 2026-05-21 (Thursday)

### Active Tickets
- OSAC-394 (Org Controller: Trigger Storage Provisioning on Lifecycle Events) — In Progress, PR osac-operator#210 (22d!)
- OSAC-278 (Ansible: Organization Storage Provisioning Playbook Framework) — In Progress, PR osac-aap#266 (22d!)
- OSAC-56 (Tenant Storage and Tiers) — In Progress/Critical (epic)
- OSAC-104 (Add storage-tier support to tenant StorageClass discovery) — In Progress
- OSAC-333 (Finalize quota management enhancement proposal) — In Progress
- OSAC-70 (Quota Management) — New (epic)
- OSAC-498 (Tenant controller: use target cluster client) — New
- OSAC-499 (Tenant ops: dedicated ServiceAccount) — New
- OSAC-326 (Demo: Storage Story) — New
- OSAC-179 (Remove deprecated status.storageClass field) — New

### Open PRs
- osac-operator#210: OSAC-394 (Org Controller storage provisioning) — 22d, CI:pass, tzvatot COMMENTED May 13 (not blocking)
- osac-aap#266: OSAC-278 (tenant storage playbooks) — 22d, CI:pass, adriengentil COMMENTED Apr 28

### Repo Refresh
- fulfillment-service: UPDATED +11 (fast-fwd, OSAC-748 branch already merged — consider switching to main)
- osac-operator: OK (0 behind, 6 ahead) — fork origin diverged: local 41 ahead, 7 behind fork (rebase artifact)
- osac-aap: UPDATED +2 — fork origin diverged: local 20 ahead, 8 behind fork (needs force-push to update PR)
- osac-installer: UPDATED +2
- osac-test-infra: UPDATED +50 (major update)

### Milestones
- 2026-06-01: MOC 2.0 dev cluster (11d away)

### Notes
- Akshay posted Storage Update thread in #wg-osac-eng: Google Sheet with decisions by phase + 2 new design tabs in storage doc (PTAL)
- Avishay responded: opened OSAC-917 (StorageBackend CRD auto-discovery), working on OSAC-882 (StorageTier) and per-tier-and-org StorageClass creation
- Monday meeting canceled (US holiday). Demos move to Wednesday.
- avishay: API group inconsistency flagged: osac.openshift.io vs osac.io/owner-reference — needs resolution
- tzumainn: ci/prow/e2e-vmaas failing consistently in osac-aap on unrelated PRs
- PR #210 flagged :rotating_light: by Elad's PR Status Bot as 21d stale

---

## 2026-05-20 (Wednesday)

### Active Tickets
- OSAC-394 (Org Controller: Trigger Storage Provisioning on Lifecycle Events) — In Progress, PR osac-operator#210 (21d!)
- OSAC-278 (Ansible: Organization Storage Provisioning Playbook Framework) — In Progress, PR osac-aap#266 (21d!)
- OSAC-56 (Tenant Storage and Tiers) — In Progress/Critical (epic)
- OSAC-104 (Add storage-tier support to tenant StorageClass discovery) — In Progress
- OSAC-333 (Finalize quota management enhancement proposal) — In Progress
- OSAC-70 (Quota Management) — New (epic)
- OSAC-498 (Tenant controller: use target cluster client) — New
- OSAC-499 (Tenant ops: dedicated ServiceAccount) — New
- OSAC-326 (Demo: Storage Story) — New
- OSAC-179 (Remove deprecated status.storageClass field) — New

### Open PRs (still 2)
- osac-operator#210: OSAC-394 (Org Controller storage provisioning) — 21d
- osac-aap#266: OSAC-278 (tenant storage playbooks) — 21d

### Milestones
- 2026-06-01: MOC 2.0 dev cluster (12d away)

### Notes
- OSAC-473 (DeletionTimestamp guard) disappeared from Jira — ticket closed
- All 4 repos rebased cleanly: FS +10, AAP +3, installer +11, operator +15
- Akshay shared storage doc with edit permissions — "PTAL" cc'd you
- Avishay updated CaaS storage EP with NFS discussion (3 replies)
- osac-dev-bot first bug fix merged (#249)
- First recurring Tuesday storage meeting happened yesterday
- New weekly report from Alona (May 18) — processing
- Summit 2026 done — Chris Wright sent thank-you
- PRs #210 and #266 at 21 days — critical age

---

## 2026-05-18 (Monday morning)

### Active Tickets
- OSAC-394 (Org Controller: Trigger Storage Provisioning on Lifecycle Events) — In Progress, PR osac-operator#210 (20d!)
- OSAC-278 (Ansible: Organization Storage Provisioning Playbook Framework) — In Progress, PR osac-aap#266 (20d!)
- OSAC-56 (Tenant Storage and Tiers) — In Progress/Critical (epic)
- OSAC-104 (Add storage-tier support to tenant StorageClass discovery) — In Progress
- OSAC-333 (Finalize quota management enhancement proposal) — In Progress
- OSAC-473 (DeletionTimestamp guard) — ASSIGNED (PR #216 merged, ticket not yet closed)
- OSAC-70 (Quota Management) — New (epic)
- OSAC-498 (Tenant controller: use target cluster client) — New
- OSAC-499 (Tenant ops: dedicated ServiceAccount with scoped RBAC) — New
- OSAC-326 (Demo: Storage Story) — New
- OSAC-179 (Remove deprecated status.storageClass field) — New

### Open PRs (only 2 remaining)
- osac-operator#210: OSAC-394 (Org Controller storage provisioning) — 20d, tzvatot COMMENTED
- osac-aap#266: OSAC-278 (tenant storage playbooks) — 20d, adriengentil COMMENTED

### Merged This Week
- osac-operator#229: OSAC-687 (Inject storageClasses into extra_vars) — merged May 16
- osac-operator#216: OSAC-473 (DeletionTimestamp guard) — merged May 15
- osac-aap#291: OSAC-175/176 (Tier-aware StorageClass role) — merged May 13
- fulfillment-service#505: OSAC-748 (Console OPA allowlist) — merged May 12

### Milestones
- 2026-06-01: MOC 2.0 dev cluster (14d away — TWO WEEKS)

### Notes
- Tickets closed after PR merges: OSAC-687, OSAC-175, OSAC-176, OSAC-748 no longer in Jira results
- New osac-operator tag: api/v0.0.2 — first versioned API release
- 3 new Gemini transcripts from today: Storage+Epics, Zoltan/Akshay 1:1, group sync — processing
- Avishay posted CaaS storage EP (14 replies) + noticed VAST demo using CRs instead of OSAC APIs (12 replies)
- osac-aap CI failing — fix PR #304 from new team member
- All repos rebased cleanly
- PR Status Bot: 19 ready, 11 need review, 12 stale

---

## 2026-05-18 (Sunday)

### Active Tickets
- OSAC-687 (Inject resolved storageClasses into AAP extra_vars) — In Progress, PR osac-operator#229 **MERGED May 16**
- OSAC-473 (DeletionTimestamp guard) — ASSIGNED, PR osac-operator#216 **MERGED May 15**
- OSAC-394 (Org Controller storage provisioning) — In Progress, PR osac-operator#210 (19d, tzvatot COMMENTED)
- OSAC-278 (Ansible storage provisioning playbook) — In Progress, PR osac-aap#266 (19d)
- OSAC-56 (Tenant Storage and Tiers) — In Progress/Critical (epic)
- OSAC-176 (Update templates/playbook for tier-driven SC selection) — In Progress (PR #291 merged)
- OSAC-175 (Tier-aware StorageClass Ansible role) — In Progress
- OSAC-104 (Add storage-tier support) — In Progress
- OSAC-333 (Finalize quota management EP) — In Progress
- OSAC-70 (Quota Management) — New (epic)
- OSAC-498 (Use target cluster client) — New
- OSAC-499 (Tenant ops dedicated ServiceAccount) — New
- OSAC-326 (Demo: Storage Story) — New
- OSAC-179 (Remove deprecated storageClass field) — New

### Open PRs (down from 6 to 2!)
- osac-operator#210: OSAC-394 (Org Controller storage provisioning) — 19d, tzvatot COMMENTED
- osac-aap#266: OSAC-278 (tenant storage playbooks) — 19d, adriengentil COMMENTED

### Merged Since Last Check
- osac-operator#229: OSAC-687 (Inject resolved storageClasses into extra_vars) — merged May 16
- osac-operator#216: OSAC-473 (DeletionTimestamp guard) — merged May 15

### Milestones
- 2026-06-01: MOC 2.0 dev cluster (14d away)

### Notes
- TWO PRs MERGED: #216 (May 15) and #229 (May 16) — storage tier work landing!
- Avishay wrote CaaS storage enhancement proposal (following Thursday's discussion)
- Will Gordon's VAST PR #296 ready for review — tagged you
- Oved asked "did you sit with Avishay on storage epics?" — 20-reply thread
- Akshay scheduled recurring "OSAC Storage" weekly (Tuesdays 3-4pm) + "Storage + Epics" today at 3:30pm
- CI down for all ofcir jobs including OSAC (May 17, Omer)
- Summit recap: Rom Freiman spoke with ~50 people
- No new Jira status changes or transcript processing needed

---

## 2026-05-15 (morning)

### Active Tickets
- MGMT-24325 (Update assisted-service postgresql to PG16) — New/Major, **newly assigned by Liat Gamliel** (Assisted Installer, not OSAC)
- OSAC-687 (Inject resolved storageClasses into AAP extra_vars) — In Progress, PR osac-operator#229 (APPROVED, 7d, Akshay new comments)
- OSAC-176 (Update templates/playbook for tier-driven SC selection) — In Progress (PR #291 merged)
- OSAC-175 (Tier-aware StorageClass Ansible role) — In Progress
- OSAC-473 (DeletionTimestamp guard) — ASSIGNED, PR osac-operator#216 (APPROVED, 10d)
- OSAC-394 (Org Controller storage provisioning) — In Progress, PR osac-operator#210 (16d, tzvatot COMMENTED)
- OSAC-278 (Ansible storage provisioning playbook) — In Progress, PR osac-aap#266 (16d)
- OSAC-56 (Tenant Storage and Tiers) — In Progress/Critical (updated May 14)
- OSAC-104 (Add storage-tier support) — In Progress
- OSAC-333 (Finalize quota management EP) — In Progress
- OSAC-70 (Quota Management) — New (epic)
- OSAC-498 (Use target cluster client) — New
- OSAC-499 (Tenant ops dedicated ServiceAccount) — New
- OSAC-326 (Demo: Storage Story) — New
- OSAC-179 (Remove deprecated storageClass field) — New

### Open PRs
- osac-operator#229: OSAC-687 storageClasses into extra_vars — APPROVED (7d, Akshay new comments)
- osac-operator#216: OSAC-473 DeletionTimestamp guard — APPROVED (10d)
- osac-operator#210: OSAC-394 storage provisioning — 16d, tzvatot COMMENTED
- osac-aap#266: OSAC-278 tenant storage playbooks — 16d

### Milestones
- 2026-06-01: MOC 2.0 dev cluster (17d away)

### Notes
- NEW JIRA: MGMT-24325 (PG13→PG15 upgrade for assisted-service) assigned by Liat Gamliel — Assisted Installer work, not OSAC
- Two storage meetings happened yesterday: "Unified Model for VMaaS and CaaS" + "PR#296 + VAST setup" — processing
- Avishay posted detailed CaaS storage architecture (custom CSI Controller Plugin pattern) — 15 replies in wg-osac-eng
- Akshay invited to storage meeting tomorrow (May 15, 14:30 CEST): PR#296 + VAST setup
- PR checklist enforcement CI action added (Omer Vishlitzky)
- New PR from Ilya: fulfillment-service#539 (OSAC-841, VNC routing)

---

## 2026-05-14 (morning)

### Active Tickets
- OSAC-687 (Inject resolved storageClasses into AAP extra_vars) — In Progress, PR osac-operator#229 (APPROVED, 6d)
- OSAC-176 (Update templates/playbook for tier-driven SC selection) — In Progress, PR osac-aap#291 **MERGED** (May 13)
- OSAC-175 (Tier-aware StorageClass Ansible role) — In Progress
- OSAC-473 (DeletionTimestamp guard) — ASSIGNED, PR osac-operator#216 (APPROVED, 9d)
- OSAC-394 (Org Controller storage provisioning) — In Progress, PR osac-operator#210 (15d, tzvatot COMMENTED)
- OSAC-278 (Ansible storage provisioning playbook) — In Progress, PR osac-aap#266 (15d)
- OSAC-56 (Tenant Storage and Tiers) — In Progress/Critical (epic, updated May 13)
- OSAC-104 (Add storage-tier support) — In Progress
- OSAC-333 (Finalize quota management EP) — In Progress
- OSAC-70 (Quota Management) — New (epic, updated May 13)
- OSAC-498 (Use target cluster client) — New (updated May 13)
- OSAC-499 (Tenant ops dedicated ServiceAccount) — New
- OSAC-326 (Demo: Storage Story) — New
- OSAC-179 (Remove deprecated storageClass field) — New

### Open PRs
- osac-operator#229: OSAC-687 storageClasses into extra_vars — APPROVED (6d)
- osac-operator#216: OSAC-473 DeletionTimestamp guard — APPROVED (9d)
- osac-operator#210: OSAC-394 storage provisioning — 15d, tzvatot COMMENTED (new reviewer!)
- osac-aap#266: OSAC-278 tenant storage playbooks — 15d, adriengentil COMMENTED

### Merged Since Last Check
- osac-aap#291: OSAC-175/176 Tier-aware StorageClass role — merged May 13
- fulfillment-service#505: OSAC-748 Console OPA allowlist — merged May 12

### Milestones
- May 2026: Red Hat Summit (this week)
- 2026-06-01: MOC 2.0 dev cluster (18d away)

### Notes
- osac-aap#291 MERGED — tier-aware StorageClass role and template-driven selection landed!
- osac-aap back on branch (was detached HEAD) — rebased 9 commits cleanly
- osac-operator rebased with stash-pop (uncommitted changes preserved)
- fulfillment-service rebased — OSAC-748 branch now has 0 local commits (can delete branch)
- Elad Tabak (tzvatot) reviewed PR #210 — first new reviewer on this PR!
- Will Gordon tagged you about JIT storage class provisioning for VAST — needs coordination
- Alona: new Jira components added to OSAC project
- AAP broken in hypershift1 — Eran Cohen applying workaround
- OSAC-70 (Quota Management) and OSAC-498 (Use target cluster client) both updated May 13
- 3 unprocessed meeting files being processed (weekly report + 2 Gemini transcripts)

---

## 2026-05-13 (morning)

### Active Tickets
- OSAC-748 (Console gRPC methods missing from Authorino OPA allowlist) — ASSIGNED, PR fulfillment-service#505 **MERGED** (May 12)
- OSAC-687 (Inject resolved storageClasses into AAP extra_vars) — In Progress, PR osac-operator#229 (**APPROVED** by Akshay, 5d)
- OSAC-176 (Update templates/playbook for tier-driven SC selection) — In Progress, PR osac-aap#291 (5d, Akshay COMMENTED)
- OSAC-175 (Update tenant_storage_class Ansible role for tier-aware lookup) — In Progress
- OSAC-473 (DeletionTimestamp guard) — ASSIGNED, PR osac-operator#216 (APPROVED, 8d)
- OSAC-394 (Org Controller storage provisioning) — In Progress, PR osac-operator#210 (14d, pre-commit FAILING)
- OSAC-278 (Ansible storage provisioning playbook) — In Progress, PR osac-aap#266 (14d)
- OSAC-56 (Tenant Storage and Tiers) — In Progress/Critical (epic)
- OSAC-104 (Add storage-tier support) — In Progress
- OSAC-333 (Finalize quota management EP) — In Progress
- OSAC-499 (Tenant ops dedicated ServiceAccount) — New
- OSAC-498 (Use target cluster client) — New
- OSAC-326 (Demo: Storage Story) — New
- OSAC-179 (Remove deprecated storageClass field) — New
- OSAC-70 (Quota Management) — New (epic)

### Open PRs
- osac-operator#229: OSAC-687 storageClasses into extra_vars — APPROVED (5d) ⚠ OPERATOR BROKEN, hold merge
- osac-operator#216: OSAC-473 DeletionTimestamp guard — APPROVED (8d) ⚠ OPERATOR BROKEN
- osac-operator#210: OSAC-394 storage provisioning — needs review (14d, pre-commit FAILING)
- osac-aap#291: OSAC-175/176 tier-aware SC role — Akshay COMMENTED (5d)
- osac-aap#266: OSAC-278 tenant storage playbooks — needs review (14d)

### Merged Since Last Check
- fulfillment-service#505: OSAC-748 Console OPA allowlist — merged May 12

### Milestones
- May 2026: Red Hat Summit (happening now!)
- 2026-06-01: MOC 2.0 dev cluster (19d away)

### Notes
- **OSAC OPERATOR BROKEN** — Omer Vishlitzky warned to hold PRs. Bug merged via /override despite failing tests.
- PR #505 (fulfillment-service) MERGED — OSAC-748 done
- PR #229 (osac-operator) APPROVED by Akshay — but blocked by operator breakage
- PR #291 (osac-aap) has Akshay COMMENTED reviews — need to check inline feedback
- PR #210 pre-commit FAILING after rebase
- osac-aap still on DETACHED HEAD
- Akshay asking about deprecating EDA provider support
- Dan Manor + Netris Red Hat blog post published
- New weekly report from Alona (May 12) — saved, needs processing
- **TODAY: Demo with Ofer Bochan** — VM status reporting

---

## 2026-05-12 (morning, Monday)

### Active Tickets
- OSAC-748 (Console gRPC methods missing from Authorino OPA allowlist) — ASSIGNED, PR fulfillment-service#505 (APPROVED, 3 human reviews)
- OSAC-473 (DeletionTimestamp guard) — ASSIGNED (was: In Progress), PR osac-operator#216 (APPROVED)
- OSAC-687 (Inject resolved storageClasses into AAP extra_vars) — In Progress, PR osac-operator#229 (4d, needs review)
- OSAC-176 (Update templates/playbook for tier-driven SC selection) — In Progress, PR osac-aap#291 (4d, needs review)
- OSAC-175 (Update tenant_storage_class Ansible role for tier-aware lookup) — In Progress
- OSAC-394 (Org Controller storage provisioning) — In Progress, PR osac-operator#210 (13d, 2 human reviews)
- OSAC-278 (Ansible storage provisioning playbook) — In Progress, PR osac-aap#266 (13d, 6 human reviews + 6 inline)
- OSAC-56 (Tenant Storage and Tiers) — In Progress/Critical (epic)
- OSAC-104 (Add storage-tier support) — In Progress
- OSAC-333 (Finalize quota management EP) — In Progress
- OSAC-499 (Tenant ops dedicated ServiceAccount) — New
- OSAC-498 (Use target cluster client) — New
- OSAC-326 (Demo: Storage Story) — New
- OSAC-179 (Remove deprecated storageClass field) — New
- OSAC-70 (Quota Management) — New (epic)

### Open PRs
- fulfillment-service#505: OSAC-748 Console OPA allowlist — APPROVED (3d, 3 human reviews)
- osac-operator#229: OSAC-687 storageClasses into extra_vars — needs review (4d)
- osac-operator#216: OSAC-473 DeletionTimestamp guard — APPROVED (7d)
- osac-operator#210: OSAC-394 storage provisioning — needs review (13d, 2 reviews + 2 inline)
- osac-aap#291: OSAC-175/176 tier-aware SC role — needs review (4d)
- osac-aap#266: OSAC-278 tenant storage playbooks — needs review (13d, 6 reviews + 6 inline)

### Milestones
- May 2026: Red Hat Summit (THIS WEEK - kicks off today!)
- 2026-06-01: MOC 2.0 dev cluster (20d away)

### Notes
- Repos rebased against upstream/main: fulfillment-service +4, osac-operator +8 (osac-aap detached HEAD, installer already at 0)
- osac-aap on DETACHED HEAD — needs attention
- OSAC-473 and OSAC-748 status changed to ASSIGNED (new Jira status)
- Alona asked if we're presenting demos and if we took a free Beaker machine (3 direct Slack mentions)
- Liat mentioned PostgreSQL version update might be related to an issue
- Akshay updated osac-workspace skills for OSAC Jira project
- New person joining: UDV5LAS5N adding themselves to fulfillment-wg
- Jira MCP issues: Liat reported Rovo MCP blocking issue creation in OSAC project
- UI team asking about Resource quota graphs (relevant to quota feature!)
- PR Status Bot: 24 ready, 16 need review, 9 stale
- Red Hat Summit kicks off today
- New Gemini transcript: "OSAC - group sync" May 11 (processing)

---

## 2026-05-11 (morning, Monday)

### Active Tickets
- OSAC-748 (Console gRPC methods missing from Authorino OPA allowlist) — In Progress (NEW), PR fulfillment-service#505 (APPROVED)
- OSAC-687 (Inject resolved storageClasses into AAP extra_vars) — In Progress (was: New), PR osac-operator#229 (all CI pass)
- OSAC-176 (Update templates/playbook for tier-driven StorageClass selection) — In Progress (was: New), PR osac-aap#291 (all CI pass)
- OSAC-175 (Update tenant_storage_class Ansible role for tier-aware lookup) — In Progress (was: New), PR osac-aap#291
- OSAC-473 (DeletionTimestamp guard) — In Progress, PR osac-operator#216 (APPROVED)
- OSAC-394 (Org Controller storage provisioning) — In Progress, PR osac-operator#210
- OSAC-278 (Ansible storage provisioning playbook) — In Progress, PR osac-aap#266
- OSAC-56 (Tenant Storage and Tiers) — In Progress/Critical (epic)
- OSAC-104 (Add storage-tier support) — In Progress
- OSAC-333 (Finalize quota management EP) — In Progress
- OSAC-499 (Tenant ops dedicated ServiceAccount) — New
- OSAC-498 (Use target cluster client) — New
- OSAC-326 (Demo: Storage Story) — New
- OSAC-179 (Remove deprecated storageClass field) — New
- OSAC-70 (Quota Management) — New (epic)

### Open PRs
- fulfillment-service#505: OSAC-748 Console OPA allowlist — APPROVED (NEW PR)
- osac-operator#229: OSAC-687 storageClasses into extra_vars — all CI pass, needs review
- osac-operator#216: OSAC-473 DeletionTimestamp guard — APPROVED
- osac-operator#210: OSAC-394 storage provisioning — needs review
- osac-aap#291: OSAC-175/176 tier-aware StorageClass role — all CI pass, needs review
- osac-aap#266: OSAC-278 tenant storage playbooks — CI pass, needs review (14d)

### Merged Since Last Check
- osac-operator#199: MGMT-23977 Per-tier StorageClass resolution — merged May 4

### Milestones
- May 2026: Red Hat Summit (THIS MONTH)
- 2026-06-01: MOC 2.0 dev cluster inclusion (21d away)

### Notes
- BUG FOUND: coffee-update was rebasing against origin/main (fork) instead of upstream/main (real upstream). Fixed.
- Repos behind upstream: fulfillment-service 9, osac-operator 9, osac-aap 3, osac-installer 54
- New PR: fulfillment-service#505 (OSAC-748 Console OPA allowlist) — already APPROVED
- 3 tickets moved New→In Progress: OSAC-687, OSAC-175, OSAC-176
- New ticket OSAC-748 (Console gRPC auth fix) — In Progress
- Akshay thanked us in Slack, asked for help with console feature setup
- VAST storage discussion exploded (42-reply thread in wg-osac-eng)
- Liat rescheduled weekly 1:1 to today 10:30
- Edge engineering weekly report from Amir (May 10)

---

## 2026-05-08 (morning)

### Active Tickets
- OSAC-687 (Inject resolved storageClasses into AAP extra_vars) — New, PR osac-operator#229 (ALL CI + E2E PASS)
- OSAC-175 (Update tenant_storage_class Ansible role for tier-aware lookup) — New, PR osac-aap#291 (ALL CI PASS)
- OSAC-473 (DeletionTimestamp guard) — In Progress, PR osac-operator#216 (APPROVED, Prow e2e stale-branch fail)
- OSAC-394 (Org Controller storage provisioning) — In Progress, PR osac-operator#210 (Prow e2e stale-branch fail)
- OSAC-278 (Ansible storage provisioning playbook) — In Progress, PR osac-aap#266 (CI pass, tide ERROR)
- OSAC-56 (Tenant Storage and Tiers) — In Progress/Critical (epic)
- OSAC-104 (Add storage-tier support) — In Progress
- OSAC-333 (Finalize quota management EP) — In Progress
- OSAC-499 (Tenant ops dedicated ServiceAccount) — New
- OSAC-498 (Use target cluster client in tenantStorageClassExists) — New
- OSAC-326 (Demo: Storage Story) — New
- OSAC-179 (Remove deprecated storageClass field) — New
- OSAC-70 (Quota Management) — New (epic)

### Open PRs
- osac-operator#229: OSAC-687 storageClasses into extra_vars — CI: ALL PASS (incl. all 8 Prow e2e), needs review
- osac-operator#216: OSAC-473 DeletionTimestamp guard — APPROVED, Prow e2e FAILING (stale base)
- osac-operator#210: OSAC-394 storage provisioning — needs review, Prow e2e FAILING (stale base)
- osac-aap#291: OSAC-175/176 tier-aware StorageClass role — CI: ALL PASS, needs review
- osac-aap#266: OSAC-278 tenant storage playbooks — CI pass, tide ERROR, needs review (11d)

### Milestones
- May 2026: Red Hat Summit demos (VMaaS + CaaS)
- 2026-06-01: MOC 2.0 dev cluster inclusion (24d away)

### Notes
- TWO NEW PRs submitted yesterday: operator#229 (OSAC-687) and aap#291 (OSAC-175/176)
- PR #229 has ALL 8 Prow e2e tests passing — confirms e2e failures on #216/#210 are stale-base, not infra
- osac-aap has uncommitted changes on feature/OSAC-175 branch — active development
- Avishay posted instance types EP #39
- Will Gordon still asking about StorageClass provisioning overlap (3 Slack mentions)
- Quay registry in read-only mode
- PR Status Bot: 28 open (was 33), 7 need review (was 22), 13 stale

---

## 2026-05-07 (morning)

### Active Tickets
- OSAC-56: Tenant Storage and Tiers epic — In Progress (was: New) — status changed!
- OSAC-473: DeletionTimestamp guard bug — In Progress, PR osac-operator#216 (APPROVED, Prow E2E FAILING — infra-wide)
- OSAC-394: Org Controller storage provisioning — In Progress, PR osac-operator#210 (10d, Prow E2E FAILING — infra-wide)
- OSAC-278: Ansible storage provisioning — In Progress, PR osac-aap#266 (10d, CI pass)
- OSAC-104: Storage-tier support — In Progress
- OSAC-333: Quota enhancement proposal — In Progress
- OSAC-499: Tenant ops dedicated ServiceAccount — New (NEW TICKET)
- OSAC-498: Use target cluster client in tenantStorageClassExists — New (NEW TICKET)
- OSAC-326: Demo: Storage Story — New
- OSAC-179: Remove deprecated storageClass field — New
- OSAC-175: Update tenant_storage_class Ansible role — New
- OSAC-70: Quota Management epic — New

### Open PRs
- osac-operator#216: MGMT-23949 DeletionTimestamp guard — APPROVED by akshaynadkarni, Prow e2e FAILING (infra-wide, 8/8 e2e fail on most PRs)
- osac-operator#210: MGMT-23828 storage provisioning — needs lgtm+approved, Prow e2e FAILING (same infra issue)
- osac-aap#266: MGMT-23826 tenant storage playbooks — CI all pass, needs lgtm+approved (10d)

### Milestones
- May 2026: Red Hat Summit demos (VMaaS + CaaS)
- 2026-06-01: MOC 2.0 dev cluster inclusion (25d away)
- End of summer 2026: HIPAA + NIST 800-171 compliance

### Notes
- PR #216 APPROVED by Akshay (May 7 03:47 UTC) — review comments addressed in May 6 push
- New Prow E2E tests deployed overnight — ALL FAILING across most PRs (infra issue, not our code)
- OSAC-56 epic moved to "In Progress" — first status change
- Two new sub-tasks created: OSAC-499 (SA+RBAC) and OSAC-498 (target cluster client)
- Meeting decisions (May 6): blocking deletion adopted, AI-only reviews rejected, monorepo EP planned
- SNO integration test environment being set up by Adrien Gentil
- Storage demo listed as upcoming in weekly report
- Will Gordon messaged about StorageClass provisioning overlap

---

## 2026-05-06 (morning)

### Active Tickets (now OSAC project, migrated from MGMT)
- OSAC-394 (was MGMT-23828): Org Controller storage provisioning — Code Review (9d), PR osac-operator#210 (CI pass)
- OSAC-377 (was MGMT-23826): Ansible storage provisioning playbook — Code Review (9d), PR osac-aap#266 (CI pass)
- MGMT-23949: DeletionTimestamp guard bug — POST, PR osac-operator#216 (CI pass) [may also be migrated]
- OSAC-56 (was MGMT-23541): Tenant Storage and Tiers epic — New/Critical
- OSAC-253 (was MGMT-23456): Quota enhancement proposal / Implement Quota Service
- OSAC-326 (was MGMT-23571): Demo: Storage Story — To Do
- OSAC-453: Missing KubeVirt RBAC for hub-access breaks VM serial console — new

### Open PRs
- osac-operator#216: MGMT-23949 DeletionTimestamp guard — CI: ALL PASS, needs lgtm+approved (2d)
- osac-operator#210: MGMT-23828 storage provisioning — CI: ALL PASS, needs lgtm+approved (9d)
- osac-aap#266: MGMT-23826 tenant storage playbooks — CI: ALL PASS, needs lgtm+approved (9d)

### Milestones
- May 2026: Red Hat Summit demos (VMaaS + CaaS)
- 2026-06-01: MOC 2.0 dev cluster inclusion (26d away)
- End of summer 2026: HIPAA + NIST 800-171 compliance

### Notes
- **JIRA MIGRATION COMPLETED** — project moved from MGMT to OSAC (batch of OSAC-* notifications received)
- All 3 PRs still awaiting reviewer action — no changes overnight
- New Gemini transcript: "OSAC - group sync" May 4 — confirms migration decision, BMaaS demo, auth review
- Weekly report (Alona, May 4): "Storage Tenant Onboarding" listed as upcoming demo — our work is visible
- Slack: Ilya cc'd me on console-proxy PR (operator#213) + fulfillment-service#487 — review requests
- Slack: Crystal Chun posted Keycloak Org vs Realm discussion doc
- Slack: Customer interest in OSAC productization timeline
- Quota still absent from weekly report (visibility gap continues)

---

## 2026-05-05 (morning)

### Active Tickets
- MGMT-23949: DeletionTimestamp guard bug — POST, PR osac-operator#216 (CI NOW PASSING)
- MGMT-23828: Org Controller storage provisioning — Code Review (23d), PR osac-operator#210 (CI pass)
- MGMT-23826: Ansible storage provisioning playbook — Code Review (23d), PR osac-aap#266 (CI pass)
- MGMT-23499: Storage-tier support — In Progress (50d)
- MGMT-23456: Quota enhancement proposal — In Progress (54d)
- MGMT-23541: Tenant Storage and Tiers epic — New/Critical (48d)
- MGMT-24121: ComputeInstance stuck (empty storageClass) — New (11d)
- MGMT-24139: Remove deprecated storageClass field — To Do, blocked (8d)
- MGMT-23571: Demo: Storage Story — To Do (47d)
- MGMT-23368: Quota Management epic — Planning (62d)

### Open PRs
- osac-operator#216: MGMT-23949 DeletionTimestamp guard — CI: ALL PASS, needs lgtm+approved
- osac-operator#210: MGMT-23828 storage provisioning — CI: all pass, needs lgtm+approved
- osac-aap#266: MGMT-23826 tenant storage playbooks — CI: all pass, needs lgtm+approved

### Milestones
- May 2026: Red Hat Summit demos (VMaaS + CaaS)
- 2026-06-01: MOC 2.0 dev cluster inclusion (27d away)
- End of summer 2026: HIPAA + NIST 800-171 compliance

### Notes
- PR #216 CI fixed overnight — was failing, now all green
- All 3 open PRs need reviewer action (lgtm+approved labels)
- 4 repos on feature branches — not rebased (expected)
- No new meeting notes

---

## 2026-05-05

### Active Tickets
- MGMT-23949: DeletionTimestamp guard bug — POST, PR osac-operator#216 (CI FAILING)
- MGMT-23828: Org Controller storage provisioning — Code Review (22d), PR osac-operator#210 (CI pass)
- MGMT-23826: Ansible storage provisioning playbook — Code Review (23d), PR osac-aap#266 (CI pass)
- MGMT-23499: Storage-tier support — In Progress (50d)
- MGMT-23456: Quota enhancement proposal — In Progress (54d)
- MGMT-23541: Tenant Storage and Tiers epic — New/Critical (48d)
- MGMT-24121: ComputeInstance stuck (empty storageClass) — New (11d)
- MGMT-24139: Remove deprecated storageClass field — To Do, blocked on MGMT-23499 (8d)
- MGMT-23571: Demo: Storage Story — To Do (47d)
- MGMT-23368: Quota Management epic — Planning (62d)

### Open PRs
- osac-operator#216: MGMT-23949 DeletionTimestamp guard — CI: FAIL (Run Tests), Prow: pass
- osac-operator#210: MGMT-23828 storage provisioning — CI: all pass, Prow: pass
- osac-aap#266: MGMT-23826 tenant storage playbooks — CI: all pass, Prow: pass

### Milestones
- May 2026: Red Hat Summit demos (VMaaS + CaaS)
- 2026-06-01: MOC 2.0 dev cluster inclusion (27d away)
- End of summer 2026: HIPAA + NIST 800-171 compliance

### Notes
- Jira data from live MCP (VPN connected)
- PR #216 CI still failing — needs investigation
- Storage PRs (#210, #266) in Code Review 22-23 days — nudge reviewers
- Jira project migration decided (May 4) — will break JQL queries in skills
- Quota visibility gap persists

---

## 2026-05-04

### Active Tickets
- MGMT-23949: DeletionTimestamp guard bug — POST, PR osac-operator#216 (CI FAILING)
- MGMT-23828: Org Controller storage provisioning — Code Review, PR osac-operator#210 (CI pass)
- MGMT-23826: Ansible storage provisioning playbook — Code Review, PR osac-aap#266 (CI pass)
- MGMT-23499: Storage-tier support — In Progress
- MGMT-23456: Quota enhancement proposal — In Progress
- MGMT-23541: Tenant Storage and Tiers epic — New/Critical
- MGMT-24121: ComputeInstance stuck (empty storageClass) — New
- MGMT-24139: Remove deprecated storageClass field — To Do (blocked)
- MGMT-23571: Demo: Storage Story — To Do
- MGMT-23368: Quota Management epic — Planning

### Open PRs
- osac-operator#216: MGMT-23949 DeletionTimestamp guard — CI: FAIL (Run Tests), Review: 1 review, 3 comments
- osac-operator#210: MGMT-23828 storage provisioning — CI: pass, Review: 9 reviews, 3 comments
- osac-aap#266: MGMT-23826 tenant storage playbooks — CI: pass, Review: 12 reviews, 3 comments

### Milestones
- May 2026: Red Hat Summit demos (VMaaS + CaaS)
- 2026-06-01: MOC 2.0 dev cluster inclusion (28d away)
- End of summer 2026: HIPAA + NIST 800-171 compliance

### Notes
- First run of project-status skill
- PR #216 (MGMT-23949) has failing CI — needs immediate attention
- Two storage PRs (#210, #266) in Code Review for 3+ weeks — may need reviewer nudge
- Quota visibility gap flagged in roadmap — team unaware of EP progress
