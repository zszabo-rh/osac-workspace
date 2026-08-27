# Focus Tracker

**Last session:** 2026-08-27 (**OSAC-4542 Volume Get/List Public API — full fast-track, shipped + validated E2E.** (1) **Code** on `feat/OSAC-4542` (osac monorepo, fulfillment-service): public read-only `Volumes` service (List/Get at `/api/fulfillment/v1/volumes`) **generated from the private proto via cleanapi** — internal fields (backend/protocol/hub/vendor_volume_id) stripped, `storage_common_type` kept private, 2 now-unused imports hand-pruned per the `baremetal_instance_types` precedent (cleanapi v0.0.8 doesn't prune + buf lint IMPORT_USED rejects → tooling debt). Public `VolumesServer` wraps `PrivateVolumesServer` (tenant-scoped reads, mapper `SetStrict(false)` hides fields, `FilterDesc`=public); made private `tierResolver` optional (Create-only) + added `SetFilterDesc`; registered gRPC + REST; `authz.rego` allows tenant clients on public Volumes Get/List; unit + authz tests. **All green**: build/vet/golangci(0)/buf lint/**full internal suite 93 suites**/servers+auth. (2) **3 cross-linked PRs via full /prd + /design workflows** (seeded from lightweight drafts): PRD **EP#236**, Design **EP#237** (refs PRD), Code **osac#563** (refs both) — fork branches, base main, **READY-FOR-REVIEW**. Docs in OSAC house style; provenance footers rendered. Design **UX Alignment corrected per Elay**: `osac-ux` is DEPRECATED → authoritative UI types are in **osac-ui** (`libs/types`, gen-from-proto) → public Volume types don't exist yet → **no deviations** (dropped the whole block-volumes deviation table). **Scoping decision: tenant-level** (consistent w/ all resources); **owner-level (per-creator) deferred to a platform tenancy feature** — sole open question = who owns that follow-up. vendor_volume_id stays private (OQ removed). (3) **E2E on beaker edge-17** (new IP **10.6.141.65**): cleared chronic node DiskPressure via reversible cleanup (paused CaaS guest `e2e-caas-lvms` + `crictl rmi --prune` = 15→34GB); built+deployed branch image `:osac-4542-e2e`, migration auto-created `volumes` table, seeded volumes; **verified LIVE**: List/Get 200, unauth 401, internal-field hiding, **tenant-level isolation** (Keycloak tenant-user sees only own tenant [+shared special tenant]; other tenant → 404). edge-17 LEFT LIVE w/ full revert cheat-sheet. See [[project-osac-csi-next]], [[reference-beaker-osac-deployment]], [[reference-ui-types-source]].)

**Prior session:** 2026-08-27 (OSAC-3702 PRD+design + storage-stack deep-dive. (1) **PRD** drafted→published **PR osac-project/enhancement-proposals#229** (branch `prd/OSAC-3702`, pushed to fork); iterated on CodeRabbit+EP-bot review to **EP quality 10/10**, CodeRabbit satisfied. Jira OSAC-3702 **retitled** "Support LVMS node-local storage for single-node VMaaS" + description rewritten to single-node-VMaaS scope (via REST). NOTE fixVersion=**0.3** on Feature+subtasks (you mentioned 0.2-M2 target — unreconciled). (2) **Design** drafted `osac/.artifacts/design/OSAC-3702/03-design.md` (via fork, used the project override template `.design/templates/`), self-reviewed + many edits. Locked framing: retire ONLY the OSAC-managed per-tenant topolvm SC (osac-csi flavor for control-plane path); **generic `lvms.enabled` mode (LVMS-operator default SC, controller-off) untouched**; OSAC-3702 requires **both** `lvms.enabled` AND `OSAC_ENABLE_STORAGE_CONTROLLER=true`; device-class server-side; conditional `accessible_topology` (empty for network backends); mount = proxy NodePublish to topolvm-node socket (our meta-driver config points at it, topolvm untouched); OQ 8.3 + deps on OSAC-4221/OSAC-4252. READY for `/design:decompose`. (3) **PR reviews** (big-picture architect lens): #171 Pure FlashBlade design (posted), #361 Will CSI-driver install (posted — key finding: role is controller-centric, needs node-local-vendor mode for LVMS; offered defer-to-3702), #505 Akshay tenant-SC-resolution (draft ready, recommended NOT approve — CI red IS PR-related: `register-local-storage` hook `BackoffLimitExceeded` on all 3 gates = the hook #505 edits). (4) **Deep storage-stack understanding**: VAST-first stack; `OSAC_ENABLE_STORAGE_CONTROLLER=false` by-default is intentional (enabling w/o full stack fails/blocks); `lvms.enabled` is a **pre-existing generic flag** (installs topolvm+default SC for non-tenant use) that storage-WG piggy-backed tenant-integration onto — so lvms+controller-off is a VALID generic mode. ComputeInstance playbook needs a SC from one of 3 sources (injected status / #305 labeled-SC fallback / JIT tiers); OSAC-1927 = all 3 failing at once. #305 (merged) = the labeled-SC fallback via the always-on ComputeInstance controller.)
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
- **osac#563 (OSAC-4542 Volume Get/List public API — OPEN, ready-for-review; all local tests green; E2E PASS on edge-17)**
- **enhancement-proposals#236 (OSAC-4542 PRD — OPEN, ready-for-review)**
- **enhancement-proposals#237 (OSAC-4542 design — OPEN, ready-for-review; refs PRD #236)**

**Next action:** (1) **OSAC-4542 (code/docs/E2E all DONE + green) — check PR reviews/bot feedback** on osac#563, EP#236, EP#237 (all ready-for-review): address CodeRabbit/EP-bot/human comments; watch CI on #563 (non-required "Check generated code" may flag the hand-pruned public-proto imports — expected). When **design EP#237 is approved → `/design:decompose` + `/sync`** to create Jira epics/stories (orphan hand-created tasks superseded). Post the OSAC-4542 Slack announcement + E2E-pass thread comment (drafts ready). edge-17 left live w/ revert cheat-sheet (in [[reference-beaker-osac-deployment]]). (2) **OSAC-3702**: run `/design:decompose` (local only; design is 10/10-PRD-backed + self-reviewed; breakdown maps to T1–T9), then publish design PR → approve → sync. PRD PR #229 awaiting human approval (Ronnie said looks ok). (3) **#505**: post the draft review (recommend Akshay fix the register-local-storage hook — CI failure is PR-related — before approve). (4) **#286**: stop retesting (caas is merged-past on 5/12 recent PRs); escalate to Elior + get a fresh `/lgtm` (approval dismissed by rebase). (5) fixVersion realign 0.3→0.2-M2? (unresolved). (6) External confirms: Roy CR-vs-proxy (design OQ 8.1), Akshay OSAC-4221 (OQ 8.2).

**Slack channels:** C0B6USDQ85S (wg-osac-storage), C08ESMFV85Q (wg-osac-eng)  
**Slack contacts:** anadkarn (Akshay), wgordon17 (Will), rgolan (Roy), eliorerz (Elior, CI/monorepo)  
**Keywords:** storage, LVMS, VAST, StorageClass, CSI, local-lvms, local-ceph, tier, backend, storage-operations-ig, OSAC-3011, OSAC-3013  

---

## Paused / Background

### Quota (OSAC-998)
**Status:** handed off — reviewer only  
**Notes:** Ownership moved to Ronnie Lazar's Metering/Billing/Quota WG. OSAC-333 needs reassignment in Jira. No action unless Ronnie asks for review.
