# Focus Tracker

**Last session:** 2026-08-27 (OSAC-3702 PRD+design + storage-stack deep-dive. (1) **PRD** drafted→published **PR osac-project/enhancement-proposals#229** (branch `prd/OSAC-3702`, pushed to fork); iterated on CodeRabbit+EP-bot review to **EP quality 10/10**, CodeRabbit satisfied. Jira OSAC-3702 **retitled** "Support LVMS node-local storage for single-node VMaaS" + description rewritten to single-node-VMaaS scope (via REST). NOTE fixVersion=**0.3** on Feature+subtasks (you mentioned 0.2-M2 target — unreconciled). (2) **Design** drafted `osac/.artifacts/design/OSAC-3702/03-design.md` (via fork, used the project override template `.design/templates/`), self-reviewed + many edits. Locked framing: retire ONLY the OSAC-managed per-tenant topolvm SC (osac-csi flavor for control-plane path); **generic `lvms.enabled` mode (LVMS-operator default SC, controller-off) untouched**; OSAC-3702 requires **both** `lvms.enabled` AND `OSAC_ENABLE_STORAGE_CONTROLLER=true`; device-class server-side; conditional `accessible_topology` (empty for network backends); mount = proxy NodePublish to topolvm-node socket (our meta-driver config points at it, topolvm untouched); OQ 8.3 + deps on OSAC-4221/OSAC-4252. READY for `/design:decompose`. (3) **PR reviews** (big-picture architect lens): #171 Pure FlashBlade design (posted), #361 Will CSI-driver install (posted — key finding: role is controller-centric, needs node-local-vendor mode for LVMS; offered defer-to-3702), #505 Akshay tenant-SC-resolution (draft ready, recommended NOT approve — CI red IS PR-related: `register-local-storage` hook `BackoffLimitExceeded` on all 3 gates = the hook #505 edits). (4) **Deep storage-stack understanding**: VAST-first stack; `OSAC_ENABLE_STORAGE_CONTROLLER=false` by-default is intentional (enabling w/o full stack fails/blocks); `lvms.enabled` is a **pre-existing generic flag** (installs topolvm+default SC for non-tenant use) that storage-WG piggy-backed tenant-integration onto — so lvms+controller-off is a VALID generic mode. ComputeInstance playbook needs a SC from one of 3 sources (injected status / #305 labeled-SC fallback / JIT tiers); OSAC-1927 = all 3 failing at once. #305 (merged) = the labeled-SC fallback via the always-on ComputeInstance controller.)
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
- osac#286 (OSAC-3985 tier guard — OPEN, rebased+force-pushed 2026-08-25 head be68f168; bmaas+vmaas gates GREEN; caas-e2e transient infra flake → /retest; check-labels red ONLY due to missing `/lgtm` (already `approved`); "Check generated code" red but NOT a required check → ignore. Required gates: e2e-{bmaas,caas,vmaas}-gate + check-labels)
- osac#339/#340/#341/#342 (Volume reconciler/controllers/pvcRef/tier — ALL MERGED ✅; my findings on 339/340 merged over, unverified)
- osac#188 (Roy OSAC-3289 vendor CSI Helm chart — MERGED ✅)
- osac#292 (Will OSAC-3995 Public Storage Tier API — OPEN, reviewed: minor, migration doesn't backfill spec.protocol)
- osac#443 (Akshay OSAC-4257 tenant in CSI secrets — DRAFT, reviewed LGTM)
- osac#465 (Roy OSAC-4260 VIP pool convention — reviewed minor: tenant_id slice/leak)
- osac#466 (Roy OSAC-4262 block plugin — reviewed LGTM)
- osac#257 (Carlo OSAC-3632 per-disk StorageClass — OPEN DRAFT)

**Next action:** (1) **TODAY: OSAC-4542** "Volume Get/List Public API" (Feature, parent OSAC-2871, fixVersion 0.2, assigned Zoltan) — **Akshay specifically requested**. First phase of Public Volume API (OSAC-984); read-only Get/List public gRPC+REST for standalone volumes so the console UI can list them. Clarify Akshay's exact ask (PRD? design? impl?) — Feature is in "New", so likely PRD→design flow. (2) **OSAC-3702**: run `/design:decompose` (local only; design is 10/10-PRD-backed + self-reviewed; breakdown maps to T1–T9), then publish design PR → approve → sync. PRD PR #229 awaiting human approval (Ronnie said looks ok). (3) **#505**: post the draft review (recommend Akshay fix the register-local-storage hook — CI failure is PR-related — before approve). (4) **#286**: stop retesting (caas is merged-past on 5/12 recent PRs); escalate to Elior + get a fresh `/lgtm` (approval dismissed by rebase). (5) fixVersion realign 0.3→0.2-M2? (unresolved). (6) External confirms: Roy CR-vs-proxy (design OQ 8.1), Akshay OSAC-4221 (OQ 8.2).

**Slack channels:** C0B6USDQ85S (wg-osac-storage), C08ESMFV85Q (wg-osac-eng)  
**Slack contacts:** anadkarn (Akshay), wgordon17 (Will), rgolan (Roy), eliorerz (Elior, CI/monorepo)  
**Keywords:** storage, LVMS, VAST, StorageClass, CSI, local-lvms, local-ceph, tier, backend, storage-operations-ig, OSAC-3011, OSAC-3013  

---

## Paused / Background

### Quota (OSAC-998)
**Status:** handed off — reviewer only  
**Notes:** Ownership moved to Ronnie Lazar's Metering/Billing/Quota WG. OSAC-333 needs reassignment in Jira. No action unless Ronnie asks for review.
