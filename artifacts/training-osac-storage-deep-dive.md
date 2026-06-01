# OSAC Storage Deep Dive — Training Document

**Date:** 2026-05-11
**Scope:** Architecture, use cases, implementation details, and data flow of the OSAC storage solution
**Prerequisites:** Familiarity with Kubernetes storage concepts (PV, PVC, StorageClass), OSAC project structure, and the operator/AAP/fulfillment-service architecture

---

## Training Overview

This training covers OSAC's multi-tenant storage solution end-to-end: from the design motivation (sovereign cloud tenant isolation) through the label-based StorageClass architecture, the resolution algorithm, the data flow across all components (operator, fulfillment service, AAP), and the in-flight automatic storage provisioning feature. The training emphasizes WHY design decisions were made, not just WHAT they are.

---

## Lesson 1: The Storage Problem

### Key Concepts

**Why storage is special in multi-tenant platforms:**
- **Persistence** — disk data outlives VM processes; leaks are permanent
- **Performance interference** — noisy neighbor problem across shared storage pools
- **Encryption** — different tenants may require different encryption keys/policies
- **Cost differentiation** — same tenant may need fast NVMe for databases and cheap HDD for archival

**Kubernetes has no tenant concept** — StorageClasses are cluster-scoped, visible to everyone. OSAC builds tenant-awareness on top of this.

**Three personas with different concerns:**

| Persona | Concern | Storage Interaction |
|---------|---------|---------------------|
| **CSP Admin** | Infrastructure control | Configures backends, creates StorageClasses, customizes templates |
| **OSAC Contributor** | Template portability | Writes templates that work on ANY deployment without knowing backends |
| **Tenant User** | Simplicity | Specifies disk size only; never sees StorageClasses or tiers |

**The core tension:** CSP wants full control, OSAC contributor wants portability, tenant user wants simplicity. Every design decision balances these three needs.

**What OSAC does NOT do with storage:**
- Does not manage storage backends (Ceph pools, NetApp volumes, VAST tenants)
- Does not create StorageClasses itself (in merged codebase — WIP automation adds this as optional)
- Does not expose storage tiers to end users
- Does not enforce storage quotas (separate feature)

OSAC's storage role is **discovery, resolution, and selection**.

### Knowledge Check & Answers

**Q1:** A CSP has two tenants on the same cluster. Why can't OSAC just use the cluster's default StorageClass for both?

**A1:** The sovereign cloud concept requires full separation of resources. Shared StorageClasses mean: (a) no data isolation between tenants, (b) performance interference (noisy neighbor), (c) no per-tenant configuration (encryption, QoS, quotas). Each tenant needs dedicated storage pools.

**Q2:** An OSAC contributor writes a `general_vm` template that must work on Ceph AND NetApp deployments. Why is this a problem, and who solves it?

**A2:** Templates must be generic — they can't hardcode CSP-specific StorageClass names. The CSP solves it by setting up storage tiers that match the tier names requested by templates (e.g., `default`), regardless of the backend type. The template says "I need tier `default`", and the CSP ensures that tier resolves to a real StorageClass on their infrastructure.

**Q3:** A tenant user creates a VM specifying `bootDisk: { sizeGiB: 50 }` with no StorageClass or tier. Bug or design?

**A3:** By design. The tier is never specified by the user — it's hardcoded in the template. The `ocp_virt_vm` template always requests tier `default` from the `tenant_storage_class` role. The user's choice of *template* implicitly selects the tier, but they never see or interact with tier names.

---

## Lesson 2: The Label-Based Architecture

### Key Concepts

**Design choice: labels on StorageClasses** — the most Kubernetes-native approach. Alternatives were rejected:

| Rejected Approach | Reason |
|-------------------|--------|
| List of SCs on Tenant CRD | Denormalization — CSP maintains mapping in two places |
| New TenantStorage CRD | Over-engineering for a labeling problem |
| Cluster default SC | No tenant isolation |
| Ansible queries at runtime | No informer cache, duplicates resolution logic |

**The two-label system:**

```
osac.openshift.io/tenant: <tenant-name> or "Default"   ← WHO owns it
osac.openshift.io/storage-tier: <tier-name>             ← WHAT kind
```

Both labels are **required**. A StorageClass missing either label is invisible to OSAC.

**Why both required (not optional):** Making `storage-tier` optional with an implicit fallback creates ambiguity ("is `Default` a tier name or a sentinel?"). OSAC is pre-release — clean, explicit design now avoids permanent confusion. Cost: one extra label per SC.

**The `Default` fallback mechanism:**

```
Tenant axis (HAS fallback):
  tenant-specific SC → if not found → shared Default SC → if not found → tier unavailable

Tier axis (NO fallback):
  Requested tier must match exactly. "fast" never silently resolves to "standard".
```

Asymmetry is intentional: tenant fallback is safe (shared storage is reasonable), tier fallback is dangerous (wrong performance for workload).

**The composite key `(tenant, tier)` as a 2D lookup table:**

```
                    default              fast              archival
tenant-acme    │ ceph-acme-default │ ceph-acme-fast   │   (none)
Default        │ ceph-shared-def   │ ceph-shared-fast │ ceph-shared-arch

Resolution for tenant-acme:
  default  → ceph-acme-default  (tenant-specific wins)
  fast     → ceph-acme-fast     (tenant-specific wins)
  archival → ceph-shared-arch   (falls back to Default row)
```

**Result stored in `tenant.status.storageClasses`** — a list of `ResolvedStorageClass` (name + tier). This is the single source of truth. The older singular `status.storageClass` field was removed (clean break, pre-release).

### Knowledge Check & Answers

**Q1:** CSP creates a SC with `tenant=tenant-acme` but no `storage-tier` label. What happens?

**A1:** The SC is invisible to OSAC. If it was the only SC for tenant-acme, the Tenant stays in `Progressing` with `StorageClassReady=False`. If other properly-labeled SCs exist, those resolve and the Tenant can be `Ready`.

**Q2:** Tenant-acme has a tenant-specific SC for tier `default`, and a shared Default SC also exists for tier `default`. Which wins?

**A2:** Tenant-specific always wins over shared Default, per tier. The Default SC for that tier is never even considered when a tenant-specific one exists.

**Q3:** Template requests tier `fast`, tenant-acme only has `default` and `standard`. But a shared Default SC has tier `fast`. Does it succeed?

**A3:** Yes. The fallback to Default happens during Tenant reconciliation, not at provisioning time. `tenant.status.storageClasses` already contains `{ name: "ceph-shared-fast", tier: "fast" }`. The template and Ansible role don't know it came from the Default row.

---

## Lesson 3: The Resolution Algorithm

### Key Concepts

**Implementation location:** `osac-operator/internal/controller/tenant_controller.go`

**Two functions:**
- `groupByTier()` — groups StorageClasses by tier label, normalizes to lowercase, validates pattern
- `getTenantStorageClasses()` — main resolution with tenant-specific vs Default fallback per tier

**Algorithm steps:**

```
0. PRECONDITION: Namespace must exist (controller checks, does not create)
1. FETCH: List SCs with tenant=<name>, List SCs with tenant=Default
2. GROUP BY TIER: Each set grouped by storage-tier label value
3. DISCOVER ALL TIERS: Union of tier names from both groups
4. RESOLVE EACH TIER INDEPENDENTLY:
   - Tenant-specific count = 1 → use it
   - Tenant-specific count > 1 → DuplicateStorageClass error (this tier only)
   - Tenant-specific count = 0 → check Default:
     - Default count = 1 → use it (fallback)
     - Default count > 1 → DuplicateStorageClass error
     - Default count = 0 → tier not available (not an error at Tenant level)
5. BUILD RESULT: sorted alphabetically by tier name
```

**Critical:** Duplicate detection is per-tier. Duplicates in `(tenant, fast)` don't affect `(tenant, default)`.

**Validation filter in `groupByTier()`:**
- Missing tier label → skip
- Normalize to lowercase (`Fast` → `fast`)
- Invalid pattern → skip

**Tenant readiness rules:**

| Scenario | Phase | StorageClassReady |
|----------|-------|-------------------|
| At least one tier resolves | Ready | True |
| No tier resolves | Progressing | False |
| Some resolve, some have duplicates | Ready | True (events emitted for bad tiers) |

**Self-healing via StorageClass watch:** SC created/updated/deleted → Tenant re-reconciles automatically. No restart needed.

### Knowledge Check & Answers

**Q1:** CSP creates three SCs for `(tenant-acme, fast)` plus one shared Default for tier `fast`. What happens?

**A1:** Duplicate detection fires at the tenant-specific level (count > 1). It never falls through to Default when tenant-specific count is > 1. The `fast` tier errors with `DuplicateStorageClass`. Other tiers are unaffected.

**Q2:** Why does resolution happen in the Tenant controller rather than in Ansible at provisioning time?

**A2:** Three reasons: (1) **No informer cache in Ansible** — every `k8s_info` is a direct API hit; 50 concurrent VMs = 50 redundant calls. (2) **Single source of truth** — one code path to test and maintain, no risk of operator/Ansible disagreeing. (3) **Observability** — CSP can `oc get tenant -o yaml` and see resolved SCs immediately, vs buried in job logs.

**Q3:** Tenant has zero SCs anywhere. Phase? Then CSP creates a shared Default SC with tier `default`. What happens?

**A3:** Phase is `Progressing` (assuming the namespace already exists as a precondition). The StorageClass watch detects the new SC, triggers re-reconciliation, resolution succeeds, Tenant moves to `Ready` — all automatically without touching the Tenant CR.

---

## Lesson 4: Data Flow — Operator to VM Disk

### Key Concepts

**Four phases:**

```
Phase 1: Resolution      → Tenant controller resolves SCs into status
Phase 2: Injection        → CI controller injects storageClasses into extra_vars
Phase 3: Selection & Prov → AAP selects by tier, creates DataVolumes
Phase 4: Runtime          → KubeVirt binds PVCs to VM
```

**Phase 2 detail — why Go context:**
The CI controller reads `tenant.status.storageClasses` and stores it via `WithTenantStorageClasses()` (Go context value pattern). The AAP provider's `extractExtraVars()` reads it and adds `tenant_storage_classes` to the webhook payload. Context values are used because the provisioning provider interface is generic (handles CIs, ClusterOrders, Tenants) and storage classes are CI-specific data.

**Phase 3 detail — three Ansible stages:**

```
3a: EXTRACT — playbook sets tenant_storage_classes fact from extra_vars
3b: SELECT  — tenant_storage_class role matches tier, outputs SC name
3c: CREATE  — template creates DataVolumes with SC name and disk sizes
```

**DataVolume** = CDI resource that creates a PVC + triggers data population. Boot disks use `source.registry` (container image), additional disks use `source.blank`.

**Timing consistency:** CI controller reads Tenant status at the same moment it checks readiness. If Ansible queried later, the status could have changed between check and read.

**Who knows what:**

| Layer | StorageClasses | Tiers | Disk sizes |
|-------|---------------|-------|------------|
| Tenant Controller | Resolves | Groups | No |
| CI Controller | Reads from status | Passes through | From CR |
| tenant_storage_class role | Receives list | Selects | No |
| ocp_virt_vm template | Uses selected name | Hardcodes "default" | Creates DVs |
| Tenant User | No | No | Specifies |

### Knowledge Check & Answers

**Q1:** Why does the CI controller inject storageClasses into extra_vars instead of letting Ansible read the Tenant CR via `k8s_info`?

**A1:** (1) Tenant status is the single source of truth. (2) Eliminates redundant API calls (Ansible has no informer cache). (3) Timing consistency — reading at trigger time gives a snapshot consistent with the readiness check.

**Q2:** Can a template use `fast` for boot disk and `default` for additional disks?

**A2:** Yes. The `tenant_storage_class` role is stateless. A template can call it multiple times with different tier parameters:

```yaml
# Call once for boot disk
- include_role: osac.service.tenant_storage_class
  vars: { tenant_storage_class_storage_tier: "fast" }
- set_fact: { boot_disk_sc: "{{ tenant_storage_class_name }}" }

# Call again for data disks
- include_role: osac.service.tenant_storage_class
  vars: { tenant_storage_class_storage_tier: "default" }
- set_fact: { data_disk_sc: "{{ tenant_storage_class_name }}" }
```

**Q3:** 50 GiB boot + two 100 GiB additional disks, template uses tier `default`. How many DataVolumes?

**A3:** Three DataVolumes, all using the same StorageClass resolved from tier `default`. The current template applies the same tier to all disks.

---

## Lesson 5: The Fulfillment Service Layer

### Key Concepts

**The fulfillment service is a deliberate pass-through for storage.**

It knows: disk sizes, template defaults, validation (size > 0).
It does NOT know: StorageClasses, tiers, backends.

**Proto definition — minimal by design:**

```protobuf
message ComputeInstanceDisk {
    int32 size_gib = 1;    // Just a size. No tier, no SC.
}
```

No tier field is intentional — adding one would leak infrastructure concerns into the user-facing API and require proto changes, API versioning, and fulfillment-service updates.

**Data flow through the service:**

```
API request → Public server → Private server (validate + defaults) →
DAO → PostgreSQL (JSONB) → Reconciler → ComputeInstance CR
```

**Template defaults:** user-provided values ALWAYS win. Defaults applied at field level.

**Database design:** entire CI as JSONB in a `data` column. No separate disk tables. Advantage: adding fields to proto doesn't require DB migrations.

**Immutability:** enforced at CRD level (CEL validation) not API level. Defense in depth — anyone with kubectl access would bypass API-level enforcement.

**Backend change impact:**

```
CSP switches Ceph → NetApp → VAST:
  Fulfillment service: unchanged
  Proto definitions: unchanged
  Database: unchanged
  CLI: unchanged
  User workflow: unchanged
  Only changes: StorageClass labels + AAP backend hooks
```

### Knowledge Check & Answers

**Q1:** What would need to change to let users pick a storage tier?

**A1:** Proto `ComputeInstanceDisk` gets a `storage_tier` field. Fulfillment service passes it through (validation, defaults, reconciler). CLI gets `--storage-tier` flag. Operator `DiskSpec` CRD type gets the field. Database doesn't change (JSONB absorbs new fields). Design decision needed: user override vs template default.

**Q2:** Why JSONB instead of separate columns for disk fields?

**A2:** Schema flexibility for a pre-release project. Adding proto fields doesn't require DB migrations. Tradeoff: can't efficiently query by individual disk fields, but the service queries by ID/tenant/status, not disk size.

**Q3:** Why enforce disk immutability at CRD level rather than API level?

**A3:** Defense in depth. The Kubernetes API server is the ultimate gatekeeper. Anyone with kubectl or a rogue controller could bypass the fulfillment service. CRD-level CEL validation catches that. Enforce constraints as close to the data as possible.

---

## Lesson 6: Automatic Storage Provisioning (WIP)

### Key Concepts

**The gap:** In the merged codebase, CSPs manually create StorageClasses (step 3 of tenant onboarding). Doesn't scale for hundreds of tenants.

**WIP PRs (osac-operator#210, osac-aap#266)** add automatic StorageClass creation/deletion as part of the Tenant lifecycle.

**New Tenant phases:**

| Phase | Meaning |
|-------|---------|
| Pending | Initial, namespace not yet found |
| Progressing | Namespace exists (precondition met), waiting for SCs |
| Ready | At least one tier resolved |
| **Failed** (new) | Provisioning job failed — terminal, no auto-retry |
| **Deleting** (new) | Deprovisioning in progress |

**No auto-retry on failure:** Prevents infinite loops when backend is misconfigured. CSP must investigate and fix manually.

**Job tracking:** `tenant.status.jobs[]` records AAP job ID, action, and status. Same `JobStatus` pattern as ComputeInstance.

**The provisioning role (`tenant_storage_provision`):**

```
create.yaml:
  1. Find reference StorageClass (cluster default or configured)
  2. Call configure_backend.yaml (CSP hook — empty by default)
  3. Create one SC per tier with both required labels

delete.yaml:
  1. Find all labeled SCs for tenant
  2. Call cleanup_backend.yaml (CSP hook — empty by default)
  3. Delete StorageClasses
```

**CSP extension point pattern:** Ship working defaults with empty hook files. CSPs override hooks for their storage vendor (VAST, Ceph, NetApp) without forking the core role. The `osac-massopencloud-templates` repo is this pattern in action.

**VAST test infrastructure (PR #262):** Mock VMS server (Python HTTP) simulates VAST management API for integration testing without a real VAST cluster.

**Provider is optional:** If no provisioning provider configured, behavior is unchanged — manual SC creation.

**PR dependency chain:**

```
Layer 1: #210 + #266 (tenant lifecycle — merge first)
    ↓ populates Tenant.Status.StorageClasses
Layer 2: #229 + #291 (tier-aware VM provisioning — merge second)
    ↓ consumes storageClasses list
Layer 3: #262 (VAST test infra — independent)
```

### Knowledge Check & Answers

**Q1:** Why no auto-retry on failed provisioning jobs?

**A1:** If the backend is misconfigured (wrong credentials, missing pool, network issue), auto-retry hammers the backend indefinitely. The `Failed` phase signals the CSP Admin to investigate. Once fixed, they recreate the Tenant (or a future manual retry could be added).

**Q2:** CSP has two clusters (Ceph and NetApp). How do they customize tenant onboarding per cluster?

**A2:** Each cluster's AAP instance loads a CSP-specific Ansible collection that overrides `configure_backend.yaml` and `cleanup_backend.yaml`. No forking needed — use the OSAC template override pattern (like `osac-massopencloud-templates`).

**Q3:** Why does the creation flow need a "reference StorageClass"?

**A3:** The reference SC provides the `provisioner` field and base `parameters` (auth, backend connection, default pool settings). Without it, the CSP would need to specify every parameter for every tier explicitly. The reference acts as a prototype; tier-specific overrides layer on top.

---

## Lesson 7: Putting It All Together

### Full Lifecycle

```
PHASE 1: TENANT ONBOARDING
  Tenant CR created → check namespace exists (precondition) → trigger AAP → create backend + SCs → Ready

PHASE 2: VM CREATION
  User specifies disk size → fulfillment validates + persists →
  CI CR created → CI controller checks Tenant Ready →
  injects storageClasses into extra_vars → AAP selects by tier →
  creates DataVolumes + VirtualMachine → VM running

PHASE 3: VM DELETION
  User deletes VM → AAP stops VM → deletes DataVolumes + VM + secrets →
  PVC → PV → backend releases capacity

PHASE 4: TENANT TEARDOWN
  Admin deletes tenant → finalizer blocks → deprovision job →
  delete backend + SCs → remove finalizer → Tenant deleted
```

### Current State

**Merged:**
- Two-label StorageClass convention
- Resolution algorithm with per-tier fallback
- ResolvedStorageClass type and status.storageClasses list
- StorageClass watch for self-healing
- ComputeInstance DiskSpec (bootDisk, additionalDisks)
- Fulfillment service disk pass-through
- Both enhancement proposals

**In-flight (all CI passing, all need rebase):**
- Tenant storage lifecycle (operator#210, aap#266)
- Tier-aware VM provisioning via extra_vars injection (operator#229, aap#291)
- VAST mock server for testing (aap#262)
- Quota management proposal (enhancement-proposals#28)

### Connection to Quota Feature

Storage tiers are a prerequisite for meaningful storage quotas. Without tiers, "500 GiB used" is ambiguous (fast or cheap?). With tiers, usage can be reported and limited per tier per tenant.

Open design question: the fulfillment service knows disk sizes (from `approved_spec`) but not tiers. The tier mapping comes from the operator side. How this data flows back for quota aggregation is an active design decision.

### Knowledge Check & Answers

**Q1:** Two places where storage provisioning blocks and waits in the happy path?

**A1:** (1) Tenant stays in `Progressing` until StorageClasses exist (either from AAP job or manual creation). (2) ComputeInstance stays `Provisioned=False` with `TenantNotReady` until parent Tenant reaches `Ready`. Both are "wait for upstream" gates.

**Q2:** How many layers separate CSP Admin from Tenant User in the storage flow?

**A2:** Five layers:

```
CSP Admin: creates backends + StorageClasses
  ↓ (1) Tenant Controller: resolves SCs into status
  ↓ (2) CI Controller: injects into extra_vars
  ↓ (3) tenant_storage_class role: selects by tier
  ↓ (4) ocp_virt_vm template: creates DataVolumes
  ↓ (5) Kubernetes: PVC → PV → backend → VM disk
Tenant User: just said "100 GiB boot disk"
```

**Q3:** Quota reporting for: 2x general_vm (50 GiB each, tier default) + 1x database_vm (200 GiB, tier fast)?

**A3:** Report: 100 GiB on tier `default`, 200 GiB on tier `fast`. Data source options: (a) query PVC usage per StorageClass, map SC → tier via `tenant.status.storageClasses`; or (b) aggregate from fulfillment service `approved_spec` footprints, but tier mapping must flow back from the operator. The quota enhancement proposal takes approach (b), making the tier-to-size mapping an open design question.

---

## Key Takeaways (Ranked by Importance)

1. **Labels on StorageClasses are the architecture.** The two-label convention `(tenant, storage-tier)` is the foundation everything else builds on. No new CRDs, no new abstractions — just Kubernetes-native labels.

2. **The Tenant controller is the single source of truth for storage resolution.** Resolution happens once, writes to status, everyone downstream reads from there. No duplicated logic, consistent snapshots, observable results.

3. **Users never see storage infrastructure.** Templates encode tier requirements. Users pick templates and specify sizes. The platform bridges the gap between user simplicity and CSP control.

4. **Tier fallback is per-tier with tenant-specific priority.** The 2D resolution (tenant axis with Default fallback, tier axis with no fallback) balances flexibility with safety.

5. **The fulfillment service is deliberately ignorant of storage details.** It's a pass-through for disk sizes. Backend changes never ripple up to the user-facing API.

6. **Auto-provisioning is optional and additive.** WIP PRs add the ability to create StorageClasses automatically, but the system works without it. CSPs who prefer manual control are unaffected.

7. **Storage tiers are a prerequisite for meaningful quotas.** Per-tier usage tracking enables accurate cost attribution and capacity management.

---

## Further Reading / Next Steps

- **Enhancement proposals:** `enhancement-proposals/enhancements/tenant-specific-storageclasses/README.md` and `enhancement-proposals/enhancements/tenant-storage-tiers/README.md`
- **Operator implementation:** `osac-operator/internal/controller/tenant_controller.go` (resolution algorithm) and `osac-operator/internal/controller/tenant_controller_test.go` (test cases)
- **AAP roles:** `osac-aap/collections/ansible_collections/osac/service/roles/tenant_storage_class/` (selection) and `osac-aap/collections/ansible_collections/osac/templates/roles/ocp_virt_vm/` (DataVolume creation)
- **Open PRs:** osac-operator#210, #229; osac-aap#266, #291, #262
- **Quota intersection:** `enhancement-proposals/enhancements/quota-management/README.md` (PR #28)
- **Next topic to explore:** How the quota system will aggregate storage usage per tier — the open design question of how tier information flows back to the fulfillment service
