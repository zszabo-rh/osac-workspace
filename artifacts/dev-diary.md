# OSAC Dev Diary

---

## 2026-08-24

### Focus Areas Active
- Storage — OSAC-917 v0.2: PR #286 CI stale-failure fix + rebase; metering flake root-cause; LVMS decision pending (Roy leans A)

### Completed Today
- PR #286 (OSAC-3985 tier guard): diagnosed the "CI never goes green" complaint — the red checks were STALE, from an e2e run on 2026-08-13 while the branch sat 252 commits behind main. The fixes that turned main green (OSAC-3714 metering BSR→local proto; OSAC-3972 shared metering event schema → kills `specversion: None`) were merged after that run and absent from the branch. Rebased #286 on main, force-pushed to fork (`--force-with-lease`), re-triggered CI. Diff is clean (operator `storage_controller.go` +6, test +60).
- Root-caused the recurring `Run unit tests (osac-metering)` flake (57P03 "database system is shutting down"): `container.go:71` binds the Postgres container to the BeforeSuite ctx via `exec.CommandContext`; `postgres_test.go:47 defer cancel()` SIGTERMs Postgres the moment BeforeSuite returns → every new spec connection rejected. From OSAC-3418; ~37% flake on main itself (confirmed identical signature on the 2026-08-18 main failure). No ticket; team just /retests. Wrote memory `project-metering-unit-flake.md`.
- Read the wg-osac-eng thread behind the metering CI question: it was the proto-skew case (DiskImage change vs stale `buf.build/...:v0.0.84` cloud module in `osac-metering/buf.gen.yaml`), fixed via #336 and productized as OSAC-3714. Related to but distinct from #286's failures.
- Slack MCP was down all session — established the web-API fallback (conversations.replies / search.messages via `~/.config/slack` tokens); recorded in `reference-slack-setup.md`.

### In Progress
- PR #286 (OPEN, head 5454b9f2): after rebase, vmaas e2e green; STILL RED — caas e2e (+gate), osac-metering unit (the flake), check-labels. caas e2e needs a fresh look (echo-adapter Service gap, or new cause).
- LVMS-as-CSI decision (OSAC-3702): shared the study; Roy responded leaning **Option A**.

### Decisions Made
- #286 needs no Omer ping — the metering/echo-adapter issues are already fixed on main; a rebase carries them in.
- Do NOT treat the metering unit failure as this PR's problem — it's a main-wide container.go flake.

### Blocked / Needs Follow-up
- LVMS option decision: Roy's Option-A push contradicts the doc's "A ruled out." Re-read meeting transcript in ~/Downloads (incl. non-LVMS-backend passthrough discussion) before committing. Updated `project-osac-csi-next.md` with his exact points.
- Decide whether to raise the metering flake (draft-first: Slack to metering owner and/or Jira bug — fix is small).
- Pending reviews untouched today: enhancement-proposals #212, osac #369, #376, updated #340; plus Roy's #188.

---

## 2026-08-14

### Focus Areas Active
- Storage — OSAC-917 v0.2: PR #286/#327 progress, OSAC-4041 filed, K8s training Lesson 4

### Completed Today
- PR #286 (OSAC-3985 tier guard): addressed Akshay's two nits — added `r.BackendsClient != nil` to guard condition, dropped `requeueAfter` log key, added error-path test for Stage 2; all CI failures confirmed pre-existing (metering postgres, securitygroup vet, console middleware flaky)
- PR #327 (OSAC-4041 bot PR): analyzed full bot timeline — bot addressed nil-guard + test comment nits after fullsend review; fullsend APPROVED; needs our /lgtm + /approve; bot's "unable to produce code changes" on `StorageBackendsCreateRequest.object` explained (out-of-diff comment on systemic cross-repo gap)
- OSAC-4041: filed Bug ticket, linked to OSAC-917, type corrected to Bug
- K8s storage Lesson 4: LVMS internals — LV/VG/PV naming, topolvm-controller + LogicalVolume CR + topolvm-node DaemonSet, topology key flow end-to-end, why OSAC NodeGetInfo should compute key itself (multi-backend concern)
- Graphify: discovered Elior's knowledge graph tool (wg-osac-eng announcement), installed `graphifyy`, ran `graphify claude install` in osac repo, manually fetched graph-latest bundle (99,990 nodes, 179,258 links)

### In Progress
- PR #199 (CaaS LVMS): APPROVED, waiting Akshay/Elior lgtm
- PR #201 (Volume API): needs our archived_volumes comment + approve
- PR #257 (Carlo per-disk SC): waiting for Carlo to fix storageTier defaults
- PR #286: waiting Akshay /lgtm
- PR #327: waiting our /lgtm + /approve

### Decisions Made
- `StorageBackendsCreateRequest.object` missing `required=true` deferred — systemic gap across all resource types; fixing only StorageBackend makes it inconsistent
- Graphify auto-fetch not yet in 0.9.42 — Elior's "consumption side in final review"; manual refresh needed until then
- PR #327 CI: osac-metering PostgresStore failures pre-existing on main (00:38 Aug 13), not caused by bot PR

### Blocked / Needs Follow-up
- Ping Elior: graphify auto-fetch SessionStart hook ETA
- Ping Akshay: /lgtm on PR #286
- Resume K8s training Lesson 5 (block vs file, RWO/RWX, protocols)
- Roy sync on OSAC-3702 passthrough architecture still pending

---

## 2026-08-11

### Focus Areas Active
- Storage — OSAC-3234 (CaaS LVMS E2E), PR reviews (#201/#223), demo prep

### Completed Today
- OSAC-3234 E2E fully verified on edge-17: happy path (LVMS→SC→PVC bound in 66s) + failure mode (no-disk fast-fail in 56s with clear error, not silent 30-retry timeout)
- Fixed 2 E2E bugs found during testing: OLM channel auto-detect from packagemanifest + overprovisionRatio field name for LVMS 4.16
- PR #199: removed draft, all 6 test plan items checked, rebased on upstream (6 commits now)
- OSAC-3234 Jira transitioned to Review
- Reviewed PR #201 (Akshay, Volume API/CRD) — 7 findings; PR #223 (Volume controllers) — 8 findings
- Demo narration reviewed + 4 corrections (Beaker→lab server, lvm→lvms, tenant clusters→CaaS clusters, lvms-vg1 prerequisite clarification)
- Role-play architect Q&A session — all 5 tough questions on the LVMS storage feature answered
- Investigated Roy's AAP tier validation failure — not a code regression (local tests pass); Roy's env-specific issue
- Confirmed Will's `STORAGE_TESTS_ENABLED=true uv run make test` is the correct approach

### In Progress
- PR #199: APPROVED, MERGEABLE, needs `lgtm` from Akshay/Elior

### Decisions Made
- LVMS default channel should be auto-detected from `packagemanifest.status.defaultChannel`, not hardcoded — OCP version-agnostic approach
- `lvms.enabled` controls both LVMS operator install (prereqs chart) AND backend registration (post-install hook) — single flag for the full stack
- StorageBackendReady=True means hub Secret exists, not backend liveness — same pattern across all backend types; no ongoing health monitoring
- SC deletion doesn't block on active PVCs in k8s — OSAC's finalizer on Tenant enforces teardown ordering, not k8s itself

### Blocked / Needs Follow-up
- **edge-17 LOST** to lab migration — CaaS E2E env gone; replication guide saved to memory `project-caas-replication-guide.md`
- PR #199 needs `lgtm` — ping Akshay or Elior
- PR #201/#223 findings not yet shared with Akshay — do it next session
- OSAC-333 (old quota EP) still In Progress/unassigned in Jira — needs reassignment to Ronnie's WG

---

## 2026-08-06

### Focus Areas Active
- Storage OSAC-917 v0.2: OSAC-3011 merged, OSAC-3234 E2E in progress

### Completed Today
- **osac#131 (OSAC-3011) MERGED** by Tide at 14:12 UTC — all three components (lvms_storage role, installer hook, operator sentinel removal)
- **osac-test-infra#326 MERGED** — three VMaaS CI fixes: storage wait fixture, template name (cli instead of raw manifest), loop correctness fix
- **Edge-17 cluster recovered** — kubeconfig was corrupted; cluster still alive; 6 cold-boot issues fixed by agent
- **SNAT fix applied on edge-17** — attempted to fix MetalLB VIP asymmetric routing for CaaS guest cluster enrollment
- **StorageBackendStatus/ClusterStorageStatus analysis** — found StorageBackendStatus always nil (TODO OSAC-1111), ClusterStorage VMaaS-overwrites-CaaS race, StorageBackendReady single-backend semantics
- **OSAC-3234 branch rebased** on latest main (now at `feat/OSAC-3234-caas-lvms`)
- Replied to Akshay's wg-osac-storage thread about Tenant conditions analysis
- Diagnosed and fixed VMaaS CI root cause: `templateID` CRD regex rejects hyphens → `ocp-virt-vm` invalid, test needed CLI path

### In Progress
- **OSAC-3234** — branch ready, edge-17 E2E blocked by SNAT fix verification + ClusterOrder completion
- **Edge-17 SNAT** — agent applied fix, ClusterOrder still progressing as of EOD; verify tomorrow
- **osac-test-infra#326 Akshay nit** — add print() to storage wait fixture; defer to next push

### Decisions Made
- `lvms.enabled` gates both Phase 2 (LVMCluster) AND Phase 3 (backend registration) — intentional, not split into separate flags
- OSAC-3234 E2E approach: SNAT on hub node (iptables POSTROUTING) rather than OVN topology change
- VMaaS E2E not a required Tide check — FAILED blocks (Tide won't re-evaluate) but PENDING doesn't; CI gap flagged to infra team
- vmaas-ci needs `storageFulfillment: enabled` + wait fixture — both in osac#131 + osac-test-infra#326 respectively

### Blocked / Needs Follow-up
- Edge-17 ClusterOrder enrollment: agent VM stuck in `installing-pending-user-action` (SNAT fix applied but not yet verified)
- OSAC-3234 draft PR: hold until E2E confirms LVMS installed on guest cluster + per-tenant SC created
- Tide CI gap: flag to Elior/Omer — VMaaS FAILED blocks but PENDING doesn't

---

## 2026-08-05

### Focus Areas Active
- Storage OSAC-3011: PR maintenance, CR cleared, awaiting /lgtm
- Storage OSAC-3234: full implementation completed + pushed
- Test env: edge-17 caas-dev cluster setup (partial — lost access at end)

### Completed Today
- **osac#131 rebased** onto origin/main (PR#98 EDA cleanup), force-pushed; CodeRabbit re-reviewed and cleared
- **Test coverage gap fixed**: added Default SC fixture to tier-resolution tests (`storage_controller_test.go`) — finding from CodeRabbit that was genuinely valid regression gap
- **OSAC-3234 fully implemented**: `feat/OSAC-3234-caas-lvms` branch created from #131 tip, pushed to fork
  - `setup-caas-agents.sh`: optional `AGENT_VM_DATA_DISK_SIZE` env var + second qcow2 disk + virt-install array approach
  - `ensure_storage_class.yaml`: CaaS path (LVMS operator install via OLM + LVMCluster + wait for SC + per-tenant SC on guest cluster), gated on `_remote_kubeconfig is defined`
  - `defaults/main.yaml`: `lvms_storage_operator_channel: stable-4.22`, `lvms_storage_operator_namespace: openshift-storage`
- **Route53 research completed**: domain=ecoeng-osac-ci.devcluster.openshift.com; IAM user=osac-ci-caas-route53; Vault path=selfservice/osac/packet-osac; Adrien granted access; AWS creds retrieved
- **values/edge-17/values.yaml created** (local, uncommitted): DNS overrides for caas-dev; usage pattern with EXTRA_HELM_ARGS for creds
- **Edge-17 cluster setup** (partial):
  - Destroyed osac-3011-demo, pulled caas flavor, booted caas-dev
  - Fixed cert-manager-webhook and cluster-proxy-addon-manager EC key issues (delete stale secret → rollout restart)
  - install-operators and install-prereqs: succeeded after bulk Helm adoption of kustomize-managed resources
  - install-osac: failed with context deadline exceeded (unknown — lost access before diagnosing)
- **PR #94 reviewed** (Roy's CSI gRPC client stub): key finding is Roy's own unaddressed comment on client.go:54; Jira AC mismatch; conn.go lacks tests; user posting only #3 (no tests)
- **storageFulfillment.enabled design note**: after #99 merges, the flag only controls VAST credentials, not storage fulfillment. Naming confusing for LVMS-only envs. Raised as future cleanup.

### In Progress
- osac#131: WAITING /lgtm from Akshay + Roy re-lgtm; VMaaS E2E flaky (need /override)
- osac#97: both lgtms set, needs rebase — will trigger rebase of #131 when it merges
- OSAC-3234: implementation done, branch pushed, NOT yet draft PR

### Decisions Made
- **OSAC-3234 branched from osac#131 tip** (not main) — shares lvms_storage role code; rebase onto main when #131 merges
- **lvms_storage_operator_channel: stable-4.22** — matches OCP version used in caas-ci and edge-17; matches osac-operators chart default
- **DNS_CLASS not needed in values** — defaults to `dns.route53.dns` in group_vars, not in IG ConfigMap
- **IMPORT_AGENTS_* not needed** — only for bare metal import scheduled job; setup-caas-agents.sh flow uses manage_agents with hardware-inventory namespace directly
- **Don't rebase osac#131 again** — every push clears lgtm; Tide rebases at merge time; BEHIND status is irrelevant to Tide

### Blocked / Needs Follow-up
- **Edge-17 caas-dev cluster access lost** — kubeconfig corrupted; virsh console unresponsive; core SSH uses Omer's key baked in caas flavor, not our cluster-tool key; options: (a) DM Omer for his cluster-tool key or kubeadmin password, (b) destroy and recreate (~45 min to redo prereqs+osac)
- **install-osac failure reason unknown** — context deadline exceeded; need cluster access to diagnose hooks
- **Akshay /lgtm** on #131 — ping him this afternoon
- **Eranco or Omer /override** on #131 VMaaS E2E flake
- **osac#97 rebase** — when it merges, rebase #131 and update ansible_eda → osac_job_vars rename in lvms_storage

---

## 2026-08-04

### Focus Areas Active
- Storage OSAC-3011: monorepo migration PR opened, CI fixes

### Completed Today
- **osac#131 opened** — single PR covering all 3 OSAC-3011 components in the monorepo (lvms_storage role, sentinel removal, hook, configure-lvms.sh)
- Major architectural simplification: role-only change, no playbook modifications (monorepo dispatcher handles routing)
- Provider renamed `local_lvms` → `lvms` (DNS-label compliant, follows `vast` pattern)
- SCC fix: removed `runAsUser: 1001` from hook (namespace SCC range violation)
- CI fixes: `defaultStorageClassSentinel` undefined in 9 tests, YAML parse error (f-strings at 0 indent), bmaas schema (`additionalProperties: false` blocking `lvms.channel`)
- CodeRabbit findings addressed: tier name validation dropped (Roy's call), 409 validation strengthened, teardown intentional behavior explained
- lvms.enabled flag split resolved: no split needed (Elior confirmed dev/CI only)
- OSAC-3011 Jira ticket → Review
- CaaS demo transcript analyzed: sno-4-22 vs vmaas-4-22 distinction, cluster-tool CaaS flow documented

### In Progress
- osac#131: WAITING /lgtm (Roy, Akshay); CodeRabbit re-review pending; VMaaS E2E flaky rerun in progress

### Decisions Made
- **Provider name `lvms`** (not `local_lvms`) — underscore fails dispatcher DNS-label regex; follows `vast` pattern
- **No playbook modifications** in monorepo — dispatcher routes automatically, direct dispatch is prohibited pattern
- **No flag split** — `lvms.enabled` is dev/CI only per Elior; piggybacking is fine
- **No tier name validation** in AAP role — fulfillment service enforces it; per Roy's review

### Blocked / Needs Follow-up
- VMaaS E2E flaky rerun (console/compute/external-IP, unrelated to storage)
- osac#99 (Will) merge → then drop STORAGE_TIERS fallback from osac#131
- osac#97 (OSAC-3547 EDA rename) merge → then rebase osac#131
- OSAC-3234 CaaS LVMS starts after osac#131 merges

---

## 2026-08-04 (morning session)

### Focus Areas Active
- Storage OSAC-3011: monorepo migration groundwork, lvms.enabled design gap

### Completed Today
- `/gm` scan: discovered Roy's lgtm on #454 pending monorepo re-open; Akshay's demo prep (slides + videos); OSAC weekly demo confirmed today at 15:30 CEST
- Jul 31 1:1 transcript processed: lvms.enabled flag split confirmed with Akshay; action to contact infra team; CSI driver next work identified; demo format confirmed (Akshay slides → Zoltan cast)
- Jul 30 demo discussion transcript processed: `/hold` on #397 confirmed; no-AAP fallback discussion captured
- Monorepo (`osac-project/osac`) forked + cloned into `osac-workspace/osac/` with correct remotes
- `fulfillment-service` standalone repo removed (absorbed into monorepo, only pr-728 tracking branches — already merged)
- osac-installer #474 force-pushed to fork (branch was rebased during /gm but not pushed)
- Elior Erez messaged re: lvms.enabled dev/prod scope — answer ambiguous ("easiest options for dev/CI" vs "customer can use whatever")
- Rephrased question drafted: "Is `lvms.enabled: true` a supported production config?"
- Demo narration for Scene 4 (3 Tenant conditions) explained: NamespaceReady → StorageBackendReady → ClusterStorageReady

### In Progress
- ALL 3 PRs (#454, #474, #397) need migration to osac-project/osac monorepo — Roy waiting on #454 to re-/lgtm
- Awaiting Elior's answer on lvms.enabled production scope (gates flag split decision)
- Demo today 15:30 CEST (no prep needed — cast is ready)

### Decisions Made
- lvms.enabled design gap: NOT yet closed — Elior's answer was ambiguous. Rephrased question sent. Do not change #474 until answer confirmed.
- All 3 PRs need monorepo migration (not just #397 as previously thought — osac-aap and osac-installer also archived/archiving)
- osac-installer is also in the monorepo — its configure-lvms.sh is old, register-local-storage hook absent
- Ronnie = line manager (not quota-related); Monday 10:00 CEST 1:1 is generic line management

### Blocked / Needs Follow-up
- Elior's lvms.enabled clarification (before changing #474)
- Roy's #97 (OSAC-3547): renames `ansible_eda.event.*` → `osac_job_vars.*` — must adapt our migrated #454 to use new naming
- After osac#99 (Will) merges: drop STORAGE_TIERS fallback from migrated #454
- CSI driver work: coming after cluster PRs merge (Akshay will assign)

---

## 2026-08-02–03

### Focus Areas Active
- Storage OSAC-3011: PR maintenance, demo finalization

### Completed Today
- Demo re-recorded (two-phase approach: pre-run with `lvms.enabled=false`, scene 2 flips to `true`); cast post-processed (TERM fix, 10s gap cap, 448.9s → 229.1s)
- Demo narration written (audience: first-time OSAC storage viewers; emphasizes LVMS dev-only context)
- osac-installer #474: `configure-lvms.sh` error handling fixed (oc get exit status captured), rebased onto origin/main (was 16 behind), CR responses posted
- osac-aap #454: CR responses posted to all 3 CodeRabbit Jul 30 findings (all confirmed false positives)
- osac-operator #397: stale code comment fixed at `storage_controller.go:381` (removed false claim about `tenant=Default` fallback), committed cc7e777
- Will's PR #455 (OSAC-1992) reviewed: compatible with #454; delete playbook hard-fail concern noted; review comments drafted and posted

### In Progress
- osac-aap #454: WAITING — Will approval + CodeRabbit re-review pass
- osac-installer #474: WAITING — human review (Roy/Akshay); design gap pending Akshay discussion
- osac-operator #397: BLOCKED — missed monorepo archive deadline (Jul 30); needs migration to new consolidated repo

### Decisions Made
- Two-phase demo approach confirmed: pre-run with `lvms.enabled=false` so API is live and empty in scene 1; scene 2 shows the flag flip + second refresh firing the hook
- `lvms.enabled` flag split needed: current flag gates both LVMCluster creation (Phase 2) and OSAC backend registration (Phase 3 new). Proposed: add `lvms.registerAsBackend: true` as separate flag. Do not change #474 until Akshay confirms.
- After #455 merges: drop STORAGE_TIERS fallback from #454 (the transitional dual-path code)

### Blocked / Needs Follow-up
- Akshay /lgtm on #454 and #474
- Discuss `lvms.enabled` flag split at next 1:1 or storage meeting
- Migrate osac-operator #397 to new consolidated monorepo when available (new repo not yet open)
- Tenant onboarding production path (`osac create`) not demoed — binary unavailable + reconciler not wired to edge-17 hub; narration explains the difference

---

## 2026-07-29

### Focus Areas Active
- Storage OSAC-3011: PRs ready, demo in progress

### Completed Today
- osac-operator rebase conflict resolved (2 commits replayed onto main post-#354/#375 merge)
- Removed `label-storageclass` Helm hook from operator PR #397 (Akshay's checklist item)
- CodeRabbit CHANGES_REQUESTED addressed on all 3 PRs: tier name validation (#454), init container security context + SIGPIPE fix in configure-lvms.sh (#474)
- Status bot replied in wg-osac-storage
- OSAC-3012 closed (Akshay asked, covered by OSAC-3011)
- Demo plan + recording script created (`artifacts/demo-osac-3011.md`, `demos_and_workflows/osac-3011-storage/record-demo.sh`)
- Demo flow updated to match Akshay's input: Backend/Tier → no SCs → onboard tenant → SC created → PVC + VM
- MOC E2E attempted — cleaned up `osac-zszabo` namespace and restored CRD ownership to tzumainn after hitting hard AAP 2.6 licensing blocker
- Booted `osac-3011-demo` cluster on edge-17 for demo recording; fixed DNS issue (vmaas-4-22 hostnames added to VM /etc/hosts)

### In Progress
- osac-operator#397 READY — needs Akshay /lgtm
- osac-aap#454 READY — needs Akshay /lgtm
- osac-installer#474 READY — needs Akshay /lgtm
- Demo recording — cluster booting, install + record tomorrow

### Decisions Made
- MOC fresh namespace installs broken due to AAP 2.6 dropping subscription manifest licensing (requires RHSM service account). Not our problem to fix.
- OSAC-3013 AAP gap (storage-operations-ig Secret) is Will's work; documented as dependency in PR #454. Our PRs proceed independently.
- Clean install test: proper vehicle is CI (`e2e-vmaas-full-install.yml` with /ok-to-test), not manual Beaker reprovision.

### Blocked / Needs Follow-up
- Akshay /lgtm on all 3 PRs before July 31
- Demo cluster API needs to be confirmed up tomorrow morning (DNS fix applied Jul 29, not verified)
- Roy posted "Storage tier and backends demo" in wg-osac-storage — worth coordinating if it overlaps Monday slot

---

## 2026-07-28

### Focus Areas Active
- Storage (OSAC-917 v0.2): OSAC-3011 PRs — CodeRabbit fixes, CI unblocked, E2E nearly there

### Completed Today
- Addressed all CodeRabbit CHANGES_REQUESTED comments across all 3 draft PRs: teardown robustness (osac-aap#454), lvms values/schema + helm lint fix + activeDeadlineSeconds + securityContext hardening (osac-installer#474), unused function removal (osac-operator#397)
- Fixed wrong cross-repo PR references in all 3 PR descriptions (`#375` → `osac-operator#375`, `#OSAC-3011` → `#474`); added OSAC-3013 AAP side as explicit dependency
- Pushed all fixes to fork, CI lint and helm lint failures now resolved
- Regenerated stale TLS secrets on edge-17 demo cluster (cert had vmaas-4-22 SANs), restarted ingress-proxy → fulfillment-console-proxy recovered to 1/1
- Helm upgrade on edge-17 completed (revision 4, deployed)
- AAP bootstrap completed on edge-17; job template `osac-create-tenant-cluster-storage` (ID 49) confirmed to exist
- Responded to Roy's OSAC-CSI / passthrough question in storage meeting thread
- Explained OSAC-3013 AAP side to team context (Will's task = strip static STORAGE_TIERS from IG, read dynamic tier defs from operator event)

### In Progress
- OSAC-3011 E2E: operator triggers AAP job 132, job fails in ~30s — AAP project points to upstream commit (no `local_lvms_storage` role). Needs branch patch to `zszabo-rh/osac-aap:test/OSAC-3011-combined` via AAP API
- PR #354: CHANGES_REQUESTED addressed, needs /ok-to-test from org member
- PR #375: needs /lgtm

### Decisions Made
- OSAC-3011 intentionally does NOT use osac-csi-driver (still PoC, dev/CI needs no credential hiding) — direct topolvm path. Roy's "passthrough" idea is a valid future migration but out of scope.

### Blocked / Needs Follow-up
- E2E: patch AAP project branch via port-forward to AAP API (steps documented in memory)
- SSH to edge-17 unreliable at EOD — lab network issue
- PR #354 /ok-to-test: needs org member action

---

## 2026-07-27

### Focus Areas Active
- Storage — OSAC-3011 (implementation complete), E2E test on edge-17 (partial)

### Completed Today
- **OSAC-3011 full implementation** — 3 PRs across 3 repos:
  - `osac-aap feat/OSAC-3011-local-lvms-storage`: `local_lvms_storage` role (6 files: meta/osac.yaml, defaults/main.yaml, setup/ensure_sc/teardown_cluster/teardown_backend)
  - `osac-installer feat/OSAC-3011-local-lvms-storage`: register-local-storage.yaml hook (fixed YAML indentation bug — multi-line Python inside block scalar), configure-lvms.sh idempotency (skip LVMCluster + annotation when lvms-vg1 exists), development/values.yaml lvms.enabled true
  - `osac-operator feat/OSAC-3011-local-lvms-storage`: sentinel removal (getTenantStorageClasses, mapStorageClassToTenant, tenant_names.go constant, 6+ test updates)
- **OSAC-3013 AAP minimal fix** — `osac-aap feat/OSAC-3013-aap-tier-extra-vars`: all 4 storage playbooks now accept `ansible_eda.event.storage_tier_definitions` from operator, fall back to `STORAGE_TIERS` env var
- **Test operator image built and pushed** — `quay.io/rh-ee-zszabo/osac-operator:osac-3011-test` (integration branch: main + PR#354 + PR#375 + OSAC-3011 sentinel removal)
- **edge-17 E2E cluster** — machine-init.sh (partial), cluster-tool setup, vmaas-4-22 flavor pulled, cluster booted. StorageBackend `local` and StorageTier `local` manually registered via API and verified active.
- **PR #354 rebased** — force-pushed to fork, ok-to-test needed

### In Progress
- OSAC-3011 PRs: not yet submitted for review (waiting for E2E verification and ok-to-test on #354)
- E2E on edge-17: operator running with test image, API calls verified; blocked on AAP task worker stuck in wait-for-migrations (snapshot pre-existing issue)

### Decisions Made
- **StorageClass naming**: `osac-{tenant}-{tier}` per Akshay's Saturday proposal (no protocol in name for LVMS)
- **configure-lvms.sh idempotency fix**: skip both LVMCluster creation AND the is-default-class annotation when lvms-vg1 already exists (avoids making LVMS the default on MOC where Ceph is the real default)
- **No separate localStorageFulfillment IG** — confirmed, uses storage-operations-ig after OSAC-3013 strips VAST credentials
- **Hub Secret is required** for `hubSecretExists()` gate even for LVMS (no credentials, just a lifecycle marker with the tenant label)
- **cluster-tool scope**: cluster-tool manages ONLY the SNO hub VM; CaaS agent VMs are in `setup-caas-agents.sh` (osac-installer), not cluster-tool. No need to contact Omer for OSAC-3011.
- **OSAC-3013 AAP half**: instead of waiting for Will, implemented minimal fix ourselves (playbooks accept event tier defs OR env var); Will's full redesign still needed for long term

### Blocked / Needs Follow-up
- **E2E completion**: AAP task worker `Init:wait-for-migrations` has been stuck for 10+ days (snapshot state, not our code). Options: (A) investigate what the init container checks and manually unblock, (B) do fresh `make install` instead of snapshot restore
- **PR #354 ok-to-test**: force push cleared the CI gate; need org member to post `/ok-to-test` on PR #354
- **Storage meeting Tuesday 9AM ET**: bring OSAC-3011 implementation summary + E2E status (partially verified)
- **OSAC-3011 demo**: original target was Aug 3; likely needs 1-2 more days for E2E completion + PR review

---

## 2026-07-24

### Focus Areas Active
- Storage — OSAC-3011/3012/3013: pre-meeting prep, live cluster verification, Akshay sync, plan approved

### Completed Today
- Exhaustive pre-meeting preparation for OSAC-3011/3012: verified every plan claim against live code and running cluster
- Tested LVMS on hypershift1 live: PVC bound, pod ran, cleaned up — confirmed working
- Confirmed `lvms-vg1` NOT annotated as default on MOC (Ceph is); MOC LVMCluster has hardcoded device path — running our `config.yaml` without guard would create a second conflicting LVMCluster
- Designed idempotent `configure-lvms.sh` (check `lvms-vg1` exists → skip without annotating)
- Researched all OSAC installation methods: fresh install, cluster-tool snapshot, MOC dev, Enclave, GH Actions full-install, kind-based, production
- Updated OSAC-3011 Jira description with full implementation plan (replaced comment-based updates with description-based living document)
- Meeting with Akshay (14:30–15:00 CEST): plan approved, timeline set
- Analyzed meeting transcript and extracted all decisions and action items

### In Progress
- osac-operator #354: APPROVED+MERGEABLE, waiting human /lgtm (Akshay to check with Will)
- osac-operator #375 (Will): CHANGES_REQUESTED, Will addressing
- enhancement-proposals #151 (Akshay): actively being pushed, credential transit Option A/B with Roy open
- edge-17 cluster-tool setup: deferred to Monday (fresh RHEL 9 install over weekend)

### Decisions Made
- OSAC-3011 **plan approved** by Akshay; target Friday July 31, demo Monday August 3
- No separate `localStorageFulfillment` IG (previously discussed; meeting confirmed)
- `configure-lvms.sh` → idempotent (check `lvms-vg1`, exit without annotation if found)
- `development/values.yaml` `lvms.enabled: false → true` (safe with idempotent hook)
- OSAC-3012 folded into OSAC-3011 (minimal, no-op)
- CaaS guest cluster storage: separate ticket (Akshay to create), two cluster-tool CaaS flavors (with/without storage)
- Plan updates live in Jira **description** field, not comments — Akshay confirmed fine with this
- `storage.enabled` = controller; `storageFulfillment.enabled` = AAP IG secrets — separate concerns

### Blocked / Needs Follow-up
- Will's reply on IG thread (posted July 24 morning) — determines if Zoltan takes over OSAC-3013 AAP half
- Contact Omer (cluster-tool owner) Monday about second disk in CaaS flavor
- PR #354 /lgtm — Akshay to coordinate with Will
- Flag risk to Akshay by Tuesday July 28 if July 31 target looks at risk

---

## 2026-07-24 (session 2 — afternoon)

### Focus Areas Active
- Storage: OSAC-3011/3012/3013 design + PR work

### Completed Today
- PR #354 (OSAC-1957): force-pushed, conflicts resolved, now MERGEABLE — needs /lgtm
- OSAC-3011 design: agreed on Akshay's AAP dispatcher approach; no proto field, no separate IG
- OSAC-3012: confirmed LVMS operational on MOC (481d), scope = registration only
- OSAC-3013 dependency: confirmed AAP half starts after PR #375 merges; bridge approach decided
- KubeVirt worker disk: confirmed only root disk (64Gi filesystem) — CaaS LVMS deferred
- /gm and /bye skills created at ~/.claude/skills/; focus-tracker.md and storage-status-summary.md created

### In Progress
- osac-operator#354: MERGEABLE, waiting /lgtm (Akshay or Will)
- osac-operator#375: CHANGES_REQUESTED (CodeRabbit), Will addressing
- enhancement-proposals#151: CHANGES_REQUESTED (10 comments), review comments drafted but not posted
- OSAC-3011: design agreed, waiting on OSAC-3013 AAP half before implementation

### Decisions Made
- OSAC-3011: AAP dispatcher approach (not proto field); `local_lvms_storage` role; hub cluster only; bridge with n/a VAST creds
- No separate `localStorageFulfillment` IG — OSAC-3013 will clean existing IG
- CaaS guest cluster LVMS deferred (KubeVirt workers lack raw block devices)
- Daily session workflow: /gm (opener) + /bye (closer) + focus-tracker.md

### Blocked / Needs Follow-up
- PR #354: needs /lgtm
- OSAC-3011 CaaS scope: pending Akshay DM response on KubeVirt disk question
- PR #151 review comments: not yet posted (Finding 2 + 4 drafted)

---

## 2026-07-24

### Active Tickets
- OSAC-3011: Local/Dev/E2E CI Storage Setup — moved to **In Progress** (was "New" yesterday). Full design negotiation with Akshay overnight landed on an AAP-dispatcher approach (new `local_lvms_storage` role, `provider: local-lvms` StorageBackend, `local` naming) — reverses yesterday's proto-field plan. Two items explicitly deferred to today: CaaS guest cluster local storage, and (resolved) whether a separate `localStorageFulfillment` IG is needed (answer: no, pending OSAC-3013 landing).
- OSAC-3012: MOC Developer Environment Storage Setup — still "New" but investigation posted: LVMS confirmed already fully operational on hypershift1 in production (481-day-old install). Scope narrowed to registration-only. Same CaaS-guest-cluster open item as OSAC-3011.
- OSAC-1957: PR #354 — still DIRTY/CONFLICTING, now 10th day since 2026-07-15 approval, same unpushed-rebase root cause as the last two days.
- OSAC-333: Finalize quota management EP — In Progress since 2026-07-01 (23d stale); ownership now with Ronnie Lazar's WG per yesterday's DM thread, ticket reassignment/closure not yet actioned.

### Open PRs
- osac-operator#354 (OSAC-1957): APPROVED, CI green, DIRTY/CONFLICTING — needs force-push (3rd day flagging this)
- osac-operator#375 (OSAC-1992/OSAC-3013, Will Gordon): CHANGES_REQUESTED, new FAILURE check appeared 2026-07-23T16:15 — worth checking what broke, this PR is a dependency for OSAC-3011's IG assumption
- enhancement-proposals#151 (Akshay, new): Storage Control Plane design doc draft posted 2026-07-23, open for comment

### Milestones
- v0.2 planning phase deadline: 2026-07-31 (7 days away)

### Notes
- **Repo refresh**: osac-workspace merged 1 commit from upstream (Claude hooks smoke test infra). All component repos rebased cleanly. osac-installer showed the same benign stash-pop false-positive as the last two days (submodule ref bumps only, confirmed nothing lost).
- **No new meeting transcripts** — folder current, no new Gemini/weekly-report emails found today.
- **Jira**: Akshay directly mentioned Zoltan in comments on both OSAC-3011 and OSAC-3012 overnight (2026-07-23 late evening) — full design back-and-forth, see project-storagebackend-schema-proposal.md memory for the condensed version.
- **Slack (wg-osac-storage)**: Akshay opened a thread on the future of `storage-operations-ig` (credential removal via OSAC-3013 making it provider-agnostic) — concluded no new `localStorageFulfillment` IG needed, asked Will and Zoltan to coordinate directly. New `chai-bot` AI assistant enabled in the channel (indexes channel history for Q&A). PR dashboard bot: 18 need review, 20 CI failing, 15 with conflicts, 19 stale (7+d) — CI-failing count worsening (17→20).
- **Inbox**: Jira mention notifications for OSAC-3011/3012 (already covered above); a "Monthly breakfast" calendar event for Jul 29 was canceled; no other action-required items.

---

## 2026-07-23

### Active Tickets
- OSAC-1957: Backend-registration-aware storage provisioning — PR #354 (osac-operator) still DIRTY/mergeable:CONFLICTING, tide state ERROR. 9th day stuck since 2026-07-15 approval. Confirmed cause: today's rebase again produced new commit SHAs (local 3 behind fork/feat/OSAC-1957 on old SHAs) — never force-pushed.
- OSAC-333: Finalize quota management EP — In Progress since 2026-07-01 (22d, stale); restart via `/prd:ingest OSAC-998` still not kicked off
- OSAC-3011 (NEW to Jira as of yesterday, already known from prior session's design proposal): Local/Dev/E2E CI Storage Setup — status "New"; design proposal (storage_class_name field) drafted 2026-07-22 but not yet posted to Jira/Slack for Akshay's sign-off
- OSAC-3012 (NEW to Jira as of yesterday): MOC Developer Environment Storage Setup — status "New", LVMS-on-MOC investigation, not started
- OSAC-2520: Storage Framework E2E Integration — still "New", unstarted since 2026-07-17; possibly superseded by OSAC-3011/3012, needs confirmation with Akshay

### Open PRs
- osac-operator#354 (OSAC-1957): APPROVED, CI green, DIRTY/CONFLICTING on GitHub — needs `git push --force-with-lease fork feat/OSAC-1957`
- osac-operator#375 (OSAC-1992, Will Gordon): CHANGES_REQUESTED (CodeRabbit, 2 actionable comments); Zoltan already left one COMMENTED review 2026-07-22, not a requested reviewer for next round (Akshay, José Hernández are)
- enhancement-proposals#28: Quota management EP — CHANGES_REQUESTED, stale since 2026-06-03 (reference only)
- enhancement-proposals#134 (OSAC-2872): merged 2026-07-22, no longer needs review

### Milestones
- v0.2 planning phase deadline: 2026-07-31 (8 days away)
- OSAC-917 epics (incl. OSAC-3011/3012) targeted for 0.2-M2, end of August, per Akshay's 2026-07-22 Jira reorg

### Notes
- **Repo refresh**: osac-workspace merged 3 commits from upstream (evals/review harness added). All component repos rebased/updated cleanly. osac-installer showed the same benign stash-pop false-positive as before (submodule ref bumps only, nothing lost — confirmed via `git stash list` empty).
- **No new meeting transcripts** — folder current (newest is the already-processed Jul 21 storage WG notes, 24h old).
- **Slack (wg-osac-storage)**: no new activity since yesterday's Akshay epic-assignment message; Roy Golan asked about CSI helm chart / fulfillment-service client / installer wiring / CSI sanity tests work items pending OSAC-2872 epic breakdown. Sdanni (Pure Storage) posted a new PRD PR #148 (FlashBlade NFS provider) asking for reviewer assignment.
- **Slack (wg-osac-eng)**: PR dashboard bot — 19 need review, 17 CI failing, 16 with conflicts, 15 stale (7+d) — improving from 2026-07-22's 27/21/5/17 on the CI-failing count but conflicts count is worse.
- **Inbox**: no direct action items overnight; Google Cloud 2FA nag and a Digital Sovereignty Architecture Forum calendar re-invite (today's Jul 23 instance canceled, now recurring weekly) are FYI-only.

## 2026-07-22

### Active Tickets
- OSAC-1957: Backend-registration-aware storage provisioning — PR #354 (osac-operator) now **worse**: `mergeStateStatus` moved from BEHIND to DIRTY/`mergeable: CONFLICTING`. Root cause: yesterday's local rebase+fix was never force-pushed to `fork`; GitHub still sees the July 15 commit. 8th day stuck.
- OSAC-333: Finalize quota management EP — In Progress since 2026-07-01 (21d, stale); restart via `/prd:ingest OSAC-998` still not kicked off
- OSAC-2520: Storage Framework E2E Integration (Akshay-assigned) — still "New"/To Do, not started
- OSAC-2300: could not verify today — REST API and text search both return "does not exist" in the OSAC project. Yesterday's diary listed it as a new Akshay-flagged ticket; either it was never actually created, got deleted, or the key was mistranscribed. Needs a check with Akshay before assuming it's resolved or gone.

### Open PRs
- osac-operator#354 (OSAC-1957): APPROVED, CI green, but now DIRTY/CONFLICTING on GitHub because the local rebase from 2026-07-21 was never pushed. Today's repo refresh rebased the local `feat/OSAC-1957` branch again (7 new commits from origin/main, 2 ahead) — local branch should be conflict-free; needs a force-push to `fork` to sync the PR.
- enhancement-proposals#28: Quota management EP — CHANGES_REQUESTED, stale since 2026-06-03 (kept only as reference, no action)
- enhancement-proposals#134 (OSAC-2872, Storage Control Plane PRD): **merged 2026-07-22** — Zoltan was a requested reviewer but it merged without his review. Explicitly puts "Quota lifecycle (reserve/commit/release)" in Out of Scope for v0.3, which resolves the 2026-07-20 overlap-risk flag (no generic quota framework introduced).

### Milestones
- v0.2 planning phase deadline: 2026-07-31 (9 days away)
- New, unresolved: 2026-07-21 WG-OSAC-Storage meeting notes say "the project release moved to the end of August" — conflicts with the tracked 2026-07-31 v0.2 planning deadline; unclear if this is v0.2 itself slipping or a different release train. Needs clarification.

### Notes
- **Repo refresh**: osac-workspace merged 10 commits from upstream; all component repos rebased/updated cleanly. osac-installer showed a stash-pop "conflict" warning that is a false positive — caused by submodule ref bumps (bare-metal-fulfillment-operator, osac-aap, osac-fulfillment-service, osac-operator) that `git stash push` doesn't actually stash; stash list is empty, nothing was lost.
- **New meeting transcript (1)**: "WG - OSAC Storage" (Jul 21) — decision to discontinue the default tenant storage class in favor of auto-provisioned, configurable backend tiers; new action item for Zoltan to propose naming/setup for the local backend and tier configuration (not started); compliance/RBAC-for-personas discussion continues from prior meetings.
- **Quota overlap resolved**: the Storage Control Plane PRD (#134, merged today) explicitly excludes quota lifecycle from scope (v0.3 target) — the three-way quota-effort collision risk noted 2026-07-20/21 is down to two (OSAC-998 PRD work vs. Ronnie Lazar's independent effort).
- **Slack (wg-osac-eng)**: Moti Asayag's WG (masayag) posted the Metering design EP (enhancement-proposals#131, OSAC-985) for cross-WG review — relevant background for quota given the validated metering/quota separation (see quota-feature-details.md). PR dashboard bot: 27 need review, 21 CI failing, 5 with conflicts, 17 stale (7+d).
- **Inbox**: Konflux Service Account Migration follow-up (hcaballe, Assisted-side, not OSAC) marked [action required] — revised deadline end of August, live AMA 2026-07-28 10am DST.

---

## 2026-07-21

### Active Tickets
- OSAC-1957: Backend-registration-aware storage provisioning — PR #354 (osac-operator) still APPROVED/CI green, tide PENDING (7th day) — root cause found: GitHub reports `mergeStateStatus: BEHIND`, fork branch needs rebase+push
- OSAC-333: Finalize quota management EP — In Progress since 2026-07-01 (20d, stale); restart via `/prd:ingest OSAC-998` still not kicked off
- OSAC-2520: Storage Framework E2E Integration (Akshay-assigned) — still "New"/To Do, not started, updated yesterday
- OSAC-2300 (NEW, unassigned): SNO install missing `storage-operations-ig` secret — Akshay pinged me directly in Slack to review; explicitly references OSAC-1957/PR #354 as the broader related fix

### Open PRs
- osac-operator#354 (OSAC-1957): APPROVED, all checks SUCCESS, but `mergeStateStatus: BEHIND` — this is why tide has been stuck 7 days. Needs: rebase feat/OSAC-1957 onto origin/main (done locally today) then force-push to `fork` remote to update the PR.
- enhancement-proposals#28: Quota management EP — CHANGES_REQUESTED, stale since 2026-06-03 (kept only as reference, no action)

### Milestones
- v0.2 planning phase deadline: 2026-07-31 (10 days away)

### Notes
- **Repo refresh**: osac-workspace merged 8 commits from upstream. All component repos rebased clean. osac-operator's feat/OSAC-1957 rebase dropped one duplicate commit (private-api version bump already merged upstream) — not related to PR #354's actual fix.
- **New meeting transcripts (2)**: "OSAC - weekly demo" (Jul 20) — Milestone 02 planning (2 sub-milestones ending August), Bootstrap Epic process note (apply "design approved" label once PRD+design both linked — relevant for OSAC-998/70 later). "OSAC Storage Control Plane" (Jul 20) — quota/inventory/auditing framed as generic fulfillment-service components; next step to propose a cross-service generic framework, which **may overlap with the quota EP restart** — worth checking before `/prd:ingest OSAC-998` who's driving that framework proposal.
- **Direct Slack mention**: Akshay in wg-osac-storage asked me to review OSAC-2300 (SNO storage secret bug, related to OSAC-1957/#354).
- **Slack (wg-osac-eng)**: PR dashboard bot — 32 need review, 9 CI failing, 10 with conflicts, 21 stale (7+d), continuing a slow upward drift. `ssh_key` renamed to `ssh_public_key` on ComputeInstance (fulfillment-service #924 merged) — anyone using the CLI locally needs to adjust.
- **Inbox**: no direct action items; OCP 4.22 release notes change notice and a Kube 1.36 rebase/lgtm-mode announcement are FYI-only.

---

## 2026-07-20

### Active Tickets
- OSAC-1957: Backend-registration-aware storage provisioning — status "Review"; PR #354 (osac-operator) still APPROVED/CI green, tide still PENDING (5th day now — worth checking why it's stuck)
- OSAC-333: Finalize quota management EP — In Progress since 2026-07-01 (19d, stale); restart via `/prd:ingest OSAC-998` still not kicked off
- OSAC-2520 (NEW): Storage Framework E2E Integration — assigned by Akshay 2026-07-17, status "New"/To Do, not yet started. Validate full storage stack across 3 deployment configs (AAP+VAST, AAP+no-backend, no-AAP), document for demo-team handoff.

### Open PRs
- osac-operator#354 (OSAC-1957): APPROVED, all checks SUCCESS, tide PENDING 5 days — flag for investigation, no longer "just hasn't landed yet"
- enhancement-proposals#28: Quota management EP — CHANGES_REQUESTED, stale since 2026-06-03 (kept only as reference, no action)

### Milestones
- v0.2 planning phase deadline: 2026-07-31 (11 days away)
- Core-team session on OSAC Storage Control Plane requirements — today, 2026-07-20 3pm CEST (Akshay's calendar invite, tied to the Jul 16 meeting's proposal)

### Notes
- **Repo refresh**: osac-workspace merged 19 commits from upstream (new github-actions-workflows skill, osac-cluster/osac-feature skill reference-file splits). All component repos rebased/merged clean; osac-installer again showed the harmless stash-pop false-positive (nothing actually lost).
- **No new meeting transcripts** — newest is still the Jul 16 "OSAC Volumes Architecture (Contd.)" file (71h old), consistent with the weekend gap. Today's 3pm storage control-plane session hasn't happened yet.
- **New Jira assignment found via Slack, not the ticket query**: Akshay assigned OSAC-2520 directly in wg-osac-storage on 2026-07-17 — the standard `assignee = zszabo AND status in (To Do)` sweep didn't surface it (ticket status is "New", a sub-state of the To Do category that the query apparently missed). Worth double-checking the Jira query filter.
- **Storage v0.2 feature structure posted** (Akshay, wg-osac-storage, 2026-07-17): new Outcome OSAC-2871 (Storage Volumes) containing OSAC-2181 (CSI Meta-Driver) and OSAC-2872 (Storage Control Plane), plus OSAC-984 (Volume Public API, later). OSAC-917 and OSAC-2117 continue in parallel. No action needed — informational, PRD/Design phases will produce real epics.
- **Slack (wg-osac-eng)**: PR dashboard bot (2026-07-19) — 27 need review, 9 CI failing, 10 with conflicts, 22 stale (7+d) — roughly flat vs. Jul 17's numbers (26/10/11/18), stale count ticking up slightly.
- **Inbox**: recurring CI failure notifications continue unaddressed — osac-installer "Bump submodules"/"Integration Tests"/"Nightly Build" and osac-workspace "PR Dashboard" workflows have been failing repeatedly since at least Jul 16-17. Worth root-causing if it keeps going. Also a batch of Jira watch notifications for Alona Paz's storage-tier tickets (OSAC-173/174/175/176) and OSAC-219/239/242 — not assigned to Zoltan, no action.
- **No direct Slack mentions** since Jul 17.

---

## 2026-07-17

### Active Tickets
- OSAC-1957: Backend-registration-aware storage provisioning — status "Review"; PR #354 (osac-operator) still APPROVED/CI green, tide still PENDING (2nd day)
- OSAC-333: Finalize quota management EP — In Progress since 2026-07-01 (16d, stale by rule); restart via `/prd:ingest OSAC-998` still not kicked off

### Open PRs
- osac-operator#354 (OSAC-1957): APPROVED, all checks SUCCESS, tide still PENDING — no action needed, just hasn't landed yet
- enhancement-proposals#28: Quota management EP — CHANGES_REQUESTED, stale since 2026-06-03 (kept only as reference, no action)

### Milestones
- v0.2 planning phase deadline: 2026-07-31 (14 days away)

### Notes
- **Repo refresh**: osac-workspace merged 18 commits from upstream (skillsaw CI workflows added, Jira/report-bug/osac-feature skill rewrites). All component repos rebased/merged clean. osac-installer showed the same harmless stash-pop false-positive as before (submodule pointers transiently dirty; `git stash list` confirmed empty, nothing lost).
- **Meeting processed**: "OSAC Volumes Architecture (Contd.)" (Jul 16, thin Gemini summary, follow-on to Jul 15 work-breakdown meeting) — new decisions: one StorageClass per tier; storage requests bypass standard creation logic via direct RPC (matches Roy's CSI proxy PoC direction); **separate new repo planned for the OSAC CSI driver**, deployed with its own operator for enterprise/cert requirements. Jira to be restructured into distinct epics (storage volumes vs. private volume APIs). Open items: reconciliation tool choice (GitOps/ACM/AAP) and whether single-hub-cluster assumption holds at scale. Core-team session proposed for Monday 2026-07-20 on control-plane requirements.
- **Quota WG question resolved (Slack, wg-osac-storage thread, 2026-07-16)**: Ronnie Lazar asked which workgroup owns the Quota Service; Zoltan and Avishay confirmed it falls under **OSAC-Metering** (roster responsibilities: Observability, Metering, Billing, Quota). Zoltan also restated quota status in-thread: on hold pending metering foundation (now merged, but storage metering deferred to future PRDs), two prior EP attempts obsolete, restarting from blank slate, **targeted for v0.3** (nothing quota needs to land in v0.2). No further action needed — question is closed.
- **Heads up for the quota PRD restart**: Vitaliy flagged (wg-osac-eng, 2026-07-16) that the `/prd` skill's draft phase defaults the risk "Owner" field to the author's personal name instead of a team/role, inconsistent with every published OSAC PRD. Worth checking whether this has been fixed before running `/prd:ingest OSAC-998` — could otherwise put "Zoltan Szabo" in the quota PRD's risk-owner fields.
- **Slack (wg-osac-eng)**: PR dashboard bot (2026-07-16 post) — 26 need review, 10 CI failing, 11 with conflicts, 18 stale (7+d), trending down from the numbers in yesterday's diary entry. Haim Tayrie opened enhancement-proposals#121 (OSAC-1330 design) for review — not assigned to Zoltan.
- **Slack (wg-osac-storage)**: Akshay posted the Jul 16 "OSAC Volumes Architecture (Contd.)" recording in the same thread as the quota Q&A above. wgordon shared current default-volume inventory on his dev SNO (19 volumes across Keycloak/fulfillment-service/AAP/ACM/OS-image storage) — useful baseline if quota's storage-tier work needs real numbers later.
- **Inbox**: no new review requests or direct asks; mostly CI failure notifications for osac-installer "Bump submodules" and osac-workspace "PR Dashboard" workflows (repeated, not yet root-caused — worth a look if it keeps recurring) plus routine Red Hat corporate mail. Akshay sent a calendar invite for "OSAC Storage Control Plane" Monday 2026-07-20 3pm CEST — matches the core-team session floated in the meeting notes.

---

## 2026-07-16

### Active Tickets
- OSAC-1957: Backend-registration-aware storage provisioning — status "Review"; PR #354 (osac-operator) open, APPROVED, CI green, tide PENDING
- OSAC-333: Finalize quota management EP — In Progress since 2026-07-01 (still no restart via `/prd:ingest OSAC-998`)

### Open PRs
- osac-operator#354 (OSAC-1957): APPROVED, all checks SUCCESS, tide PENDING — should merge on its own
- enhancement-proposals#28: Quota management EP — CHANGES_REQUESTED, stale since 2026-06-03 (kept only as reference)

### Milestones
- v0.2 planning phase deadline: 2026-07-31 (15 days away)

### Notes
- **Repo refresh**: osac-workspace merged 5 commits from upstream (protobuf-conventions rewrite pointing to fulfillment-service/docs/API.md, design-review skill tweak, .gitignore). All component repos rebased clean (fulfillment-service +26, osac-aap +12, osac-installer +10, osac-test-infra +12, enhancement-proposals +1). osac-installer showed a harmless stash-pop false-positive (submodule pointers transiently dirty during fetch — verified `git stash list` empty, nothing lost).
- **Resolved since yesterday**: OSAC-1957 commitment gap closed — PR #354 is up, approved, CI green (yesterday it was still 3 unpushed local commits).
- **Meeting processed**: "OSAC Volumes for v0.2 - Work Breakdown" (Jul 15, thin Gemini summary) — CaaS reaffirmed over VMaaS for v0.2; controller deployment confirmed on hub cluster; RBAC direction is creator's-role-based; DaemonSets used for volume attachment; CSI driver placement (hub vs. storage-logic-layer) still open (Roy's call); new ask to consult the CAS (Cluster-as-a-Service) team on auth/forgery/network. Follow-up "OSAC Volumes Architecture (Contd.)" meeting scheduled today 9:30-10:30am EDT — **Zoltan's calendar shows it declined**, worth checking if intentional.
- **Quota-relevant**: Roy Golan assigned Zoltan an action item in his Google Doc "osac-csi-meta-driver-design.md" (comment + Slack post in wg-osac-storage, both Jul 15) asking him to mention the quota PRD there. Not yet actioned — second external ask (after Vladik's) to reference quota status before a PRD exists.
- **Slack (wg-osac-eng)**: Eranco posted a workspace update summary — AGENTS.md consolidation, auto-update on session start, PRD/design template changes, quick-fix skill added. Already covered by this morning's repo refresh (upstream merge). PR dashboard bot: 26 need review, 14 CI failing, 15 with conflicts, 20 stale (7+d) — up slightly from yesterday.
- **Slack (wg-osac-storage)**: wgordon linked an OSAC Core thread on tenant-owned CaaS cluster ongoing access/auth (relevant to today's RBAC/CAS discussion). Ygal Blum asked how Storage Tier maps to StorageClass per workload cluster (VMaaS split of root/data volumes) — team question, not assigned to Zoltan.
- **Inbox**: Roy Golan's Google Doc share + comment (see above). JP Jung's PQC-in-OCP note and the k8s 1.36 bump note are general FYI, not OSAC-specific action items.

---

## 2026-07-15

### Active Tickets
- OSAC-1957: Backend-registration-aware storage provisioning — In Progress; local branch `feat/OSAC-1957` (osac-operator) has 3 commits, no PR yet
- OSAC-333: Finalize quota management EP — In Progress since 2026-07-01 (14d, stale by rule but restart is the known plan — see quota-feature-details.md)

### Open PRs
- enhancement-proposals#28: Quota management EP — CHANGES_REQUESTED, stale since 2026-06-03 (kept only as reference, restart in progress via `/prd:ingest OSAC-998`, no action needed)

### Milestones
- No new milestone changes today

### Notes
- **Repo refresh**: osac-workspace merged 2 commits from upstream (skills/osac-feature/SKILL.md rewrite), fulfillment-service +39, osac-aap +2, osac-installer +11, osac-test-infra +29, enhancement-proposals +26 commits — all rebased clean. osac-installer showed a harmless stash-pop warning (submodule pointer diffs aren't stashable, not a real conflict).
- **Resolved since yesterday**: osac-test-infra#138 (CaaS E2E test) merged 2026-07-14 — no longer needs my `/lgtm`.
- **New**: Akshay commented on OSAC-1957 (Jira, 7/14) — once the Backend API check lands, also remove stub `vast-tenant-config-*` secrets in `osac-installer/scripts/prepare-tenant.sh` (currently `TODO(OSAC-1957)`), and validate all 3 deployment configs (AAP+VAST, AAP+no-VAST, no-AAP) before opening the PR.
- **Meeting**: "WG - OSAC Storage" Jul 14 (thin Gemini summary) — VIP pools chosen over NAT gateway for tenant storage networking, resolving the open "how do tenant VPCs reach VAST" question from 7/9. Full detail needs `/storage-update`, not captured here. User-flows/Jira-epic-breakdown meeting rescheduled to today as "OSAC Volumes for v0.2 - Work Breakdown" (Akshay, 10AM EDT/4-4:30pm CEST) — confirmed independently in Slack, some attendees double-booked, may move to Thursday.
- **Slack (wg-osac-storage, 7/14)**: Tier API merged (fulfillment-service#887, OSAC-1992, Ygal lgtm). Akshay shared a new "WG_Storage_UserFlows_Roadmap" spreadsheet ahead of today's work-breakdown meeting — worth reviewing beforehand. **Status-bot reply already posted by me 7/14** said OSAC-1957 "PR ready to submit" — as of this morning that's still not true (3 local unpushed commits, no PR). Need to close that gap today.
- **Slack (wg-osac-eng)**: Carlo Lobrano reported `cluster-tool` broken by OSAC-1928/PR#404 (deleted `ensure-ca-bundle.sh` but `refresh-after-snapshot.py` still calls it; also new Helm chart structure vs. old snapshot ownership labels) — may affect local dev/testing. PR dashboard bot: 20 need review, 17 CI failing, 14 with conflicts, 18 stale (7+d).
- **Inbox**: ACM-37727 assigned to zszabo by Liat Gamliel (Assisted Installer/ACM project, not OSAC — outside normal scope, worth a quick look). osac-installer fork's scheduled "Bump submodules" GitHub Action failed on `088ad12`.

---

## 2026-07-14

### Active Tickets
- OSAC-333: Finalize quota management EP — In Progress since 2026-07-01, still no movement
- OSAC-1957: Storage provisioning should key off registered backends, not AAP availability — New, assigned today by Akshay (follow-up from OSAC-1908/PR#333)

### Open PRs
- enhancement-proposals#28: Quota management EP — CHANGES_REQUESTED, stale since 2026-06-03 (unchanged)
- osac-test-infra#138 (Akshay's, review-requested from me): CaaS E2E test — Will Gordon requested changes 7/13, Akshay addressed 7/14, CI green, blocked only on `/lgtm`

### Milestones
- No new milestone changes today

### Notes
- **Repo refresh**: docs +2, enhancement-proposals +3, fulfillment-service +23, osac-aap +31, osac-installer +12, osac-operator +14, osac-test-infra +4 commits — all rebased clean, forks still ahead (push-back pending, see feedback-coffee-update-fork-sync).
- **Resolved since yesterday**: EP#79 (CaaS design) and osac-installer#384 both merged — no longer need my review (previously flagged as "3 PRs needing review NOW").
- **New**: OSAC-1957 assigned to me by Akshay — see project-caas-storage-workitems.md for full technical writeup.
- **New signal for quota**: github-config#127 proposes a new `osac-metering-service` repo (masayag) — metering PRD #78 moving from design to infra standup. Worth a look before finalizing OSAC-333's `/v1/usage` design.
- **Meeting**: "OSAC weekly demo" Jul 13 — UI/persona strategy discussion, 3-phase Model-as-a-Service rollout decided (provider-managed first, tenant-admin interfaces deferred). Not directly quota-relevant.
- **Inbox**: no urgent action-required items beyond what's already tracked; a few Jira/PR notification threads on fulfillment-service#866 (Ygal Blum, removes cores/memory_gib fields — not mine to review) and github-config#127.

---

## 2026-07-13 (2-week holiday catch-up: 2026-06-29 → 2026-07-13)

### Active Tickets
- OSAC-333: Finalize quota management EP — In Progress since 2026-07-01, no actual movement during holiday

### Open PRs
- enhancement-proposals#28: Quota management EP — CHANGES_REQUESTED, stale since 2026-06-03 (unchanged)
- enhancement-proposals#78 (not mine, watch): Moti Asayag's Metering and Usage Tracking PRD — active, likely overlaps quota `/v1/usage` design

### Milestones
- v0.1 formally closed 2026-07-12 (Akshay, storage side); v0.2 planning through 2026-07-31

### Notes
- **All previously-tracked storage PRs merged while away**: osac-operator#299 (Jun 23), osac-aap#338 (Jun 24), fulfillment-service#728 (Jun 24), osac-test-infra#107/OSAC-77 (Jun 29), osac-operator#333/CaaS storage (Jul 12). OSAC-23 epic is done.
- **Quota EP (PR #28 / OSAC-333) did not move** — needs attention now that back.
- **New finding**: PR #78 (Metering and Usage Tracking PRD, masayag) progressed through 2 review cycles during the holiday, addressing the same reviewer (mhrivnak) who blocked the quota EP. Directly adjacent scope — review before resuming OSAC-333.
- **Repo refresh**: massive 2-week catch-up — fulfillment-service +244, osac-installer +104, osac-aap +158, osac-test-infra +142, enhancement-proposals +87, osac-operator +48 commits. All rebased clean, forks pushed back in sync.
- **Process/policy changes while away**: one PRD+design per Feature (not Epic) going forward (Eran, Jul 7); "Ship/Show/Ask" auto-merge proposal raised and effectively rejected (Ygal pushed back); `/pr-review-quality` skill found 45% of PRs in the last 14 days had zero human reviewer.
- **Security incident**: committed Keycloak secret found in osac-installer#286 — gitleaks CI scanning added workspace-wide, rotation status still unconfirmed as of Jul 9.
- **Org change**: weekly report ownership moved from Alona Paz to Brad Nichols (Jun 28).
- **Storage architecture decisions**: OpenStack Cinder/Manila adopted as CaaS translation layer (Jun 23, PoC authorized); VAST stayed on ClusterAdmin through v0.1 (no tenant-admin shift yet); unresolved question on how tenant VPCs reach VAST storage (escalated Jul 9, still open).
- **Quarterly Connections Q2 2026**: reminder posted Jul 12 in storage channel that it was the last day to fill — verify this got submitted.
- **Minor cleanup**: local osac-test-infra checkout is still on the merged `feat/OSAC-77-storage-e2e` branch (0 commits ahead of origin/main) — safe to switch back to main and delete.

---

## 2026-06-26

### Active Tickets
- OSAC-56: VMaaS Tenant Storage Setup — In Progress (Critical)
- OSAC-333: Finalize quota management EP — In Progress, STALE (52d)
- OSAC-77: Automated E2E tests for tenant StorageClass in osac-test-infra — To Do

### Open PRs
- enhancement-proposals#28: Quota management EP — CHANGES_REQUESTED, stale since Jun 3
- enhancement-proposals#72: OSAC-1123 CaaS Cluster Storage PRD — CI:SUCCESS,pending

### Milestones
- Late June (~4 days): Storage v0.1 target (CaaS, boot volumes)

### Notes
- **Repo updates**: docs +1, enhancement-proposals +9, fulfillment-service +42, osac-aap +8, osac-installer +17, osac-operator +3, osac-test-infra +3 (all rebased to latest upstream)
- **PRs merged**: osac-operator#299 (OSAC-23) + osac-aap#338 (OSAC-23) both merged Jun 23-24
- **Fork divergence WARNING CRITICAL**: enhancement-proposals 9 ahead, fulfillment-service 42 ahead, osac-aap 8 ahead, osac-installer 17 ahead, osac-operator 3 ahead, osac-test-infra 3 ahead — ALL need push (coffee-update should have pushed after rebase)
- **CI failures**: Multiple osac-workspace PR dashboard failures, osac-installer bump-submodules failing
- **Inbox**: Friday Five newsletter, GitHub Actions failures (workspace PR dashboard, installer bump-submodules), Cursor newsletter, Red Hat 101 newsletter, Gemini 1:1 notes (Jun 25)
- **Slack highlights (Jun 25)**: Juan Hernández added migration hash check to prevent duplicate numbers (PR #761 merged, PR #747 in progress); Omer's CI triage bot analyzing failures with Claude+Gemini; Eran proposing to flip `strict: false` on branch protection to reduce Prow retests; PRD quality standards clarified (Michael: "PRD does not stand for 'Please Review my Design'"); Rom's daily summary shows 10/12 E2E vmaas passed, 6 Helm full-setup still failing
- **Meeting notes**: No new transcripts fetched — newest is Jun 23 Storage WG (45h old, WARNING: possible missed meetings)
- **git activity**: osac-workspace (4 auto-backup commits), osac-aap (5 OSAC-23 commits Jun 19-24), osac-operator (10 OSAC-23 commits Jun 17-23)

---

## 2026-06-25

### Active Tickets
- OSAC-56: VMaaS Tenant Storage Setup — In Progress (Critical)
- OSAC-333: Finalize quota management EP — In Progress, STALE (51d)
- OSAC-77: Automated E2E tests for tenant StorageClass in osac-test-infra — To Do (assigned Jun 24)

### Open PRs
- enhancement-proposals#28: Quota management EP — CHANGES_REQUESTED, stale since Jun 3, updated 2026-06-03
- enhancement-proposals#72: OSAC-1123 CaaS Cluster Storage PRD — CI:SUCCESS,pending, Michael/Akshay active discussion Jun 24

### Milestones
- Late June (~5 days): Storage v0.1 target (CaaS, boot volumes)

### Notes
- **Repo updates**: enhancement-proposals +2, fulfillment-service +24, osac-aap +13, osac-installer +11, osac-operator +6, osac-test-infra +3
- **PRs merged yesterday**: osac-operator#299 (OSAC-23 storage controller), osac-aap#338 (OSAC-23 playbook split)
- **Fork divergence WARNING**: enhancement-proposals 4 ahead, fulfillment-service 54 ahead, osac-aap 13 ahead, osac-installer 43 ahead, osac-operator 6 ahead — all need push
- **New Jira assignment**: OSAC-77 (E2E tests for tenant StorageClass) assigned by Akshay overnight
- **CI failures**: osac-installer bump-submodules failing (multiple runs), osac-workspace PR dashboard failing
- **Inbox**: Multiple Jira tickets from Akshay (OSAC-1143/77/1144/1146/499/56/498), PR #72 review activity (Akshay/Michael/CodeRabbit), RHEM 1.2 GA announcements
- **Slack**: Eran stressed PR/Jira hygiene — 63% PRs have no ticket, many merged PRs not closed in Jira; Ygal flagged duplicate migration numbers breaking CI; Lars reported hypershift1 back up with 2 new nodes; Michael clarified PRD vs design scope
- **Meeting notes**: All processed (last: Jun 23 Storage WG, 23h old)
- **git activity**: osac-workspace (10 auto-backup commits), osac-aap (5 OSAC-23 commits), osac-operator (10 OSAC-23 commits)

---

## 2026-06-24

### Active Tickets
- OSAC-1145: Split AAP storage playbooks — In Progress, PR osac-aap#338 (CI:SUCCESS, APPROVED)
- OSAC-56: VMaaS Tenant Storage Setup — In Progress (Critical)
- OSAC-333: Finalize quota management EP — In Progress, STALE (50d)
- OSAC-104: Add storage-tier support to tenant StorageClass discovery — In Progress, STALE (50d)

### Open PRs
- osac-aap#338: OSAC-23 rename storage playbooks — CI:SUCCESS, Review:APPROVED (Akshay), updated 2026-06-24, READY TO MERGE
- osac-operator#299: OSAC-23 storage controller — awaiting Prow override (zszabo requested Jun 23 evening)
- enhancement-proposals#28: Quota management EP — CHANGES_REQUESTED, stale since Jun 3 (mhrivnak returns Jun 24)

### Milestones
- Jun 15-22 (ENDED): hypershift1 DOWN — CI should be unblocked
- Late June (~6 days): Storage v0.1 target (CaaS, boot volumes)

### Notes
- **Repo updates**: .ai-workflows +4, enhancement-proposals +2, fulfillment-service +13, osac-installer +20, osac-operator +3, osac-test-infra +3
- **New meeting**: OSAC Storage (Jun 23) — OpenStack Cinder/Manila PoC authorized, Vast 4000 tenant limit noted, milestone tracking protocol established (fix versions on features only)
- **PR #338 ready to merge** — all CI passing, Akshay approved, awaiting final merge
- **PR #299 awaiting Prow override** — zszabo requested `/override ci/prow/e2e-vmaas` on Jun 23 evening, Akshay confirmed manual E2E run passed
- **Fork divergence**: fulfillment-service 30 ahead fork/main, osac-installer 32 ahead fork/main — push needed after coffee-update
- **Slack overnight**: Rom's daily summary (11 green E2E runs, Full Setup Helm root cause found by Ameya), Riccardo asked for config parameter review for wizard, Souvik Das new UI install issue
- **Action items from storage meeting**: Akshay to review operator+backend PRs, create VMaaS storage tier selection ticket, research BM storage needs; Roy+Avishay to run OpenStack PoC
- **Inbox**: PR #338 approved by Akshay overnight, osac-installer bump-submodules CI failures (4 instances), Akshay 1:1 scheduled Thu Jun 25

---

## 2026-06-23

### Active Tickets
- OSAC-1145: Split AAP storage playbooks — In Progress, PR osac-aap#338 (CI:SUCCESS/pending, APPROVED)
- OSAC-56: VMaaS Tenant Storage Setup — In Progress (Critical)
- OSAC-333: Finalize quota management EP — In Progress, STALE (49d)
- OSAC-104: Add storage-tier support to tenant StorageClass discovery — In Progress, STALE (49d)

### Open PRs
- osac-operator#299: OSAC-23 storage controller — CI:SUCCESS/pending, Review:APPROVED (Akshay), updated 2026-06-23
- osac-aap#338: OSAC-23 rename storage playbooks — CI:SUCCESS/pending, Review:APPROVED (Akshay), updated 2026-06-22
- enhancement-proposals#28: Quota management EP — CHANGES_REQUESTED, stale since Jun 3 (mhrivnak returns Jun 24)

### Milestones
- Jun 15-22 (ended): hypershift1 DOWN for data center maintenance — CI should be unblocked
- Late June (~7 days): Storage v0.1 target (CaaS, boot volumes)

### Notes
- Repos: osac-workspace merged 1 upstream commit (settings cleanup), fulfillment-service +17, osac-aap +6, osac-operator +2, osac-installer +12, osac-test-infra +12
- **PR #299 APPROVED** by Akshay (Jun 23) — all review comments addressed, pending JobType refactoring (Option C complete)
- **PR #338 APPROVED** by Akshay (Jun 22)
- Fork status: osac-workspace 2 ahead origin/main, fulfillment-service 17 ahead fork/main, osac-aap 16 ahead/4 behind fork branch, osac-installer 12 ahead fork/main, osac-test-infra 12 ahead fork/main
- osac-installer stash pop warning — no actual conflicts, just "no stash entries" after successful rebase
- osac-operator fork 2 behind fork/feat/OSAC-23-storage-controller (fork has newer commits from Jun 22-23 pushes)
- Inbox: GitLab PAT expires in 7 days, CI failures (osac-workspace PR dashboard, osac-installer bump-submodules, osac-operator pre-commit), Kalyn calendar invites (July telco events)
- Slack: @Akshay confirms reviewing #299 today (wg-osac-storage), Rom's daily summary shows GitHub Actions E2E POC passed, Ygal requesting reviews on fulfillment-service PRs, Crystal asking about migration gap handling
- Meeting notes: 96h old (last: Jun 18 weekly report) — WARNING: possible missed meetings

---

## 2026-06-22

### Active Tickets
- Jira CLI currently unavailable (jira_failed) — unable to retrieve ticket status

### Open PRs
- osac-operator#299: OSAC-23 storage controller — CI:SUCCESS (pending), Review:CHANGES_REQUESTED, updated 2026-06-21
- osac-aap#338: OSAC-23 rename storage playbooks — CI:SUCCESS (pending), Review:NONE, updated 2026-06-18
- enhancement-proposals#28: Quota management EP — CHANGES_REQUESTED, stale since Jun 3 (mhrivnak returns Jun 24)

### Milestones
- Jun 15-22 (ongoing, ends today): hypershift1 DOWN for data center maintenance
- Late June (~8 days): Storage v0.1 target (CaaS, boot volumes)

### Notes
- Repos: enhancement-proposals +2 (auto/bump-submodules branch, new PR #64), fulfillment-service +15, osac-aap +6, osac-operator +2, osac-installer +12, osac-test-infra +3
- Fork status: osac-operator 13 ahead/11 behind fork branch, osac-aap 10 ahead/4 behind fork branch — both diverged
- Inbox: Weekly reports from Tatjana and Yaron (Jun 16-17)
- Slack: Dan Manor asking for review on EP #64 (Friday evening)
- **Option C implementation complete** (commit f4f6529 on osac-operator) — renamed jobs→provisioningJobs across all CRDs
- osac-installer submodules updated (osac-aap, fulfillment-service, osac-operator all advanced)
- **Jira CLI unavailable** — all jira_failed, cannot retrieve ticket status this session

---

## 2026-06-18

### Active Tickets
- OSAC-1145: Split AAP storage playbooks — In Progress, PR osac-aap#338 (CI:PASS, 1 new Akshay comment overnight)
- OSAC-56: VMaaS Tenant Storage Setup (Epic) — In Progress (Critical)
- OSAC-104: Add storage-tier support to tenant StorageClass discovery — In Progress, STALE (44d)
- OSAC-333: Finalize quota management EP — In Progress, STALE (44d, mhrivnak returns Jun 24)

### Open PRs
- osac-operator#299: OSAC-23 storage controller — CI:PASS, Review:CHANGES_REQUESTED (coderabbitai bot), 6 substantive Akshay comments overnight (01:42-01:51 UTC)
- osac-aap#338: OSAC-23 rename storage playbooks — CI:PASS, Review:NONE, 1 Akshay question overnight (02:39 UTC)
- enhancement-proposals#28: Quota management EP — CHANGES_REQUESTED, stale since Jun 3 (mhrivnak PTO until Jun 24)

### Milestones
- Jun 15-22 (ongoing): hypershift1 DOWN for data center maintenance
- Late June (~12 days): Storage v0.1 target (CaaS, boot volumes)

### Notes
- Repos: enhancement-proposals +15, fulfillment-service +15 (v0.0.65, v0.0.66 tagged), osac-operator rebased 2 new upstream commits, osac-installer +4
- PR #60 (Roy's StorageBackend EP design) MERGED — zszabo merged in wg-osac-storage thread yesterday
- PR #58 (zszabo's tenant storage design): reviewDecision=APPROVED, Roy conditional LGTM pending final look
- Akshay: #299 needs — rename handleClassXxx→handleClusterStorageXxx, Secrets RBAC→namespaced Role, fill StorageBackendStatus/ClusterStorageStatus on TenantStatus, use shared NeedsProvisionJob, rename osacTenantAnnotation→osacTenantLabel, add TODO(OSAC-1123)
- Akshay: #338 question — teardown_cluster_storage.yaml accepts hcp_data_plane but teardown_backend.yaml only accepts vmaas — intentional?
- osac-aap: feature branch has uncommitted nvidia.bare_metal vendor changes (from upstream) — investigate
- Inbox: DB Bennett DM asking if OSAC team ready to adopt PG16 for MCE 5.0 — needs reply
- DB Bennett DM: "We have added PG16 to the bundle for MCE 5.0. Is your team ready to adopt it?"
- Fork: osac-operator 9 ahead fork remote, 7 behind fork remote — push needed after #299 fixes

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
