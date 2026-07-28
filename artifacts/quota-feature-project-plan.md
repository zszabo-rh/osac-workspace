# OSAC Quota Management — Project Plan

## Feature Overview

The Quota Management feature introduces resource usage limits for OSAC tenants. It prevents any single tenant from over-consuming shared infrastructure (bare metal hosts, VMs, clusters) and provides visibility into quota limits and current usage.

**Original Enhancement Proposal:** https://github.com/osac-project/enhancement-proposals/pull/8
**Current Working Document:** Enhancement proposal on branch `enhancement/quota-management-v2` in fork `zszabo-rh/enhancement-proposals` (supersedes the original PR #8 analysis)
**Author:** Lars Kellogg-Stedman (larsks)
**Status:** Proposal finalized after multiple self-review rounds; ready for team PR creation against `osac-project/enhancement-proposals`

---

## Architecture Summary

### Current Flow (No Quotas)

```
Tenant ──request──▶ Fulfillment Service ──CR──▶ OSAC Operator ──▶ AAP ──▶ Provisioned
```

### Proposed Flow (With Quotas)

```
Tenant ──request──▶ Fulfillment Service ──────────────────────────────────▶ Operator ──▶ Provisioned
                    │ stores spec (user's intent)                                ▲
                    │ sets status.approval.state=pending                         │
                    ▼                                                            │
               FS gating semaphore (one per tenant in gating at a time)         │
                    │ sets status.approval.state=gating                          │
                    ▼                                                            │
               OSAC Quota Service                                               │
               ├── watches for gating resources                                 │
               ├── reads tenant usage from /v1/usage(tenant, exclude=gated)     │
               ├── compares usage + gated resource spec against quota limits    │
               ├── ADMITTED ──▶ writes gates.quota.state=admitted ───────────────│
               │                 FS sees all gates admitted,                     │
               │                 sets state=approved, approved_spec=spec (DB),   │
               │                 creates CR on hub ─────────────────────────────┘
               └── REJECTED ──▶ writes gates.quota.state=rejected + reason
                                 FS sets state=rejected
                                 On footprint change: FS (deletion/scale-in) or QS (limit increase)
                                 sets non-expired, non-deleted rejected → pending
```

**Approval states:** pending → gating → approved / rejected / expired

### Key Components

The proposal decomposes into 3 independently valuable layers:

| Component | Details | Description |
|-------|-----------|-------------|
| **Usage Query** | `/v1/usage` endpoint on Fulfillment Service | Computes point-in-time per-tenant resource consumption from `approved_spec` in FS DB via SQL aggregation. Serves quota enforcement and basic CLI/UI visibility. Read-only, no state. Has an `exclude` parameter. Authorization: tenants see own usage, privileged accounts see all. Replaceable when comprehensive metering system is available. |
| **Approval workflow** | `status.approval` block + gating semaphore | The approval state machine (pending → gating → approved/rejected/expired), extensible gates map, and per-tenant gating semaphore. Lives in the Fulfillment Service. |
| **Quota Service** | Standalone service | Reads tenant usage from `/v1/usage` endpoint, compares against quota limits, writes gate decisions. Stores only limits in its own DB. |

These components can be built and shipped incrementally. The `/v1/usage` endpoint is a prerequisite for the Quota Service but is designed to be replaceable when a comprehensive metering system is available.

**Scale rule:** If new spec > approved_spec, state resets to pending (re-evaluation required). If new spec <= approved_spec, state stays approved immediately (no re-gating needed).

**Re-evaluation:** When the tenant's footprint changes, rejected (non-expired, non-deleted) resources are set back to pending for re-evaluation through the normal gating flow. Trigger ownership: FS handles deletions and scale-ins (it processes these operations directly). QS handles quota limit increases (it detects changes in its own limits DB and writes state back to pending via the FS API).

**Reconciler behavior (3-step):** (1) approved_spec (DB-internal) empty → skip (no CR exists), (2) approved + spec != approved_spec → set approved_spec=spec, push to hub, sync status, (3) approved_spec non-empty → sync status from hub (covers approved, rejected scale-out, expired — ensures accurate hub status for running resources).

### New Components

| Component | Description |
|-----------|-------------|
| **`/v1/usage` usage query endpoint** | Read-only endpoint on Fulfillment Service. Computes per-tenant resource consumption from `approved_spec` in FS DB via SQL aggregation. Has `exclude` parameter to omit a specific resource (used by QS for the gated resource). Authorization: tenants see own usage, privileged accounts see all. Consumers: Quota Service, CLI, UI, future billing/capacity planning. |
| **OSAC Quota Service** | Standalone service with its own DB (limits only, no footprint cache). Watches for gating resources, reads tenant usage from `/v1/usage` endpoint, writes to its own gate entry (`gates.quota`). |
| **`status.approval` block on all resources** | Contains `state` (pending/gating/approved/rejected/expired) and `gates` (extensible map of gate entries, v1: quota only). `approved_spec` is DB-internal only, not exposed in the public API. Gate services write only to their own gate entry, never to `state`. |
| **Quota management API** | CRUD API for managing per-tenant quota limits. Admin-write, tenant-read. |

### Key Design Decisions

1. **K8s-like API model** — `spec` = user's intent (always written by FS on behalf of the tenant); `approved_spec` = the last approved state, used by the reconciler for hub CR operations (DB-internal only, not exposed in the public API). The reconciler never reads `spec` directly — it uses `approved_spec` as the source of truth for what should exist on the hub. Tenants see running state via `status.node_sets` (hub-reported) and usage via `/v1/usage`.
2. **No `desired_spec`** — eliminated entirely. `spec` always represents the user's intent. There is no separate "desired" field; the approval block tracks what has been approved via `approved_spec`.
3. **Quota Service is a separate component** — not built into the Fulfillment Service. This keeps OSAC platform-agnostic; different deployments plug in different quota logic/sources.
4. **`status.approval` block with extensible gates structure** — contains `state` and a `gates` map. `approved_spec` is DB-internal only, not exposed in the public API. `status.approval` is purely observational (reports gate decisions, K8s conformant). v1 has a single gate (`quota`). Each gate entry has `state` (pending/admitted/rejected), `reason` (string), and `timestamp`. Gate-level `state` is set to `pending` by the FS when the resource enters gating; the gate service writes `admitted` or `rejected`. Gate services write only to their own gate entry, never to `state`. The FS owns state transitions and `approved_spec` updates internally.
5. **5 approval states** — `pending` (waiting for gating semaphore), `gating` (being evaluated by gate services), `approved` (all gates admitted), `rejected` (a gate rejected), `expired` (approval timed out or resource expired).
6. **Gating semaphore** — one resource per tenant in the `gating` state at a time. The FS manages transitions from `pending` to `gating`. This serializes gate evaluation per tenant to prevent race conditions without database-level locking in the Quota Service.
7. **Scale rule** — if new `spec` > `approved_spec`, state resets to `pending` (re-evaluation required). If new `spec` <= `approved_spec`, state stays `approved` immediately (no re-gating needed, the resource is shrinking or unchanged).
8. **Re-evaluation trigger** — rejected (non-expired, non-deleted) resources are set back to `pending` when the tenant's footprint changes. The FS triggers this for deletions and scale-ins (it processes these operations). The QS triggers this for quota limit increases (detects changes in its own DB, writes state via FS API). The normal gating flow then re-evaluates them.
9. **No footprint cache in QS** — QS reads tenant usage from the `/v1/usage` usage query endpoint on the Fulfillment Service. No cache, no drift, no reconciliation. The `/v1/usage` endpoint computes usage via SQL aggregation from `approved_spec` in the FS DB.
10. **Gate service minimum contract** — a gate service watches for resources in `gating` state, evaluates its gate, and writes `state` (`admitted` or `rejected`) + `reason` (string) to its own gate entry. The gate-level `state` starts as `pending` (set by the FS when the resource enters gating). It never writes `state` or `approved_spec`. This is the entire contract for adding new gate types in the future.
11. **Spec-based computation, no usage ledger** — Quota Service reads current tenant usage from `/v1/usage` endpoint. Quota formula: `/v1/usage(tenant, exclude=gated_resource) + spec_of_gated_resource <= limits`. No separate ledger, no drift, no reconciliation needed.
12. **CRs only created after approval** — during the pending/gating state, the resource exists only in PostgreSQL. The reconciler skips resources with empty approved_spec (no CR exists). Resources with existing CRs (including rejected/expired scale-outs) still get status synced from the hub.
13. **3-step reconciler logic** — (1) approved_spec empty: skip (no CR), (2) approved + spec != approved_spec: update approved_spec and hub CR, sync status, (3) approved_spec non-empty: sync status from hub (regardless of approval state — rejected/expired resources with existing CRs still get status synced).
14. **Quota limits are arbitrary key/value pairs** — extensible to new resource types without code changes. E.g., `{"clusters": 5, "nodes.h100": 20, "nodes.fc430": 10}`.
15. **Single replica deployment** — consistent with all OSAC components at `replicas: 1`. No HA for v1.
16. **Polling-based, not Events API** — the Fulfillment Service Events API only supports Cluster/ClusterTemplate payloads today. Quota Service uses polling for v1; will migrate to Events API when it is extended to cover all resource types.
17. **Global-per-organization quotas, not per-hub** — natural consequence of the central Fulfillment Service DB. Quotas apply across all hubs.
18. **v1 independently shippable before Organizations proposal** — quota feature does not depend on the Organizations proposal and can ship first.
19. **Idempotent reconciliation, not transactional atomicity** — the Quota Service reconciliation loop is idempotent; re-evaluating a resource produces the same result.
20. **Processing order not guaranteed** — FIFO ordering was considered and dropped. Pending resources are processed in no guaranteed order.
21. **Auto-approve drain** — when `OSAC_APPROVAL_REQUIRED` changes from `true` to `false`, all pending resources are automatically approved.
22. **Multi-gate coordination deferred to v2** — v1 has a single gate (`quota`). Multi-gate semantics (reservation, rollback, ordering across gates) are deferred to a future version.

---

## Resource Types Subject to Quotas

| Resource | Where It Runs | Quota Keys (examples) |
|----------|---------------|----------------------|
| **Clusters** (HyperShift) | Control plane: pods on hub workers; Worker nodes: bare metal from ESI | `clusters`, `nodes.<resource_class>` |
| **VMs** (OCP-Virt) | KubeVirt on hub worker nodes | `compute_instances`, `vcpus`, `memory_gb`, `gpus` |
| **Bare Metal** (standalone) | ESI-managed physical hosts | `nodes.<resource_class>` |

Note: Cluster control plane nodes run as pods on the hub and do NOT consume separate machines — only worker nodes count against quotas.

---

## Open Architecture Decisions

### 1. Resource Resolution and Usage Tracking (RESOLVED — spec-based computation with no ledger)

Two intertwined decisions:
- **Decision A:** How does the system determine the resource footprint of a request?
- **Decision B:** How does the Quota Service know current tenant usage?

See the full comparison in the **Architecture Options Comparison** section below.

**Current state:** Template resolution is currently implicit — it happens inside Ansible roles at provisioning time. There is no queryable API for "what resources will this request consume?" This must be built regardless of which option is chosen.

### Template Resolution Feasibility (confirmed via codebase analysis)

The Fulfillment Service **already stores template metadata** including `node_sets` (from `meta/osac.yaml`) and `parameters` (from `argument_specs.yaml`) in the `cluster_templates` PostgreSQL table. Resolution logic can be implemented in the Fulfillment Service itself — no new service needed.

**Enrichment needed in `meta/osac.yaml`:**
- `countParameter`: (optional) which user parameter overrides a node_set's count
- `quotable`: (optional) whether a node_set counts against quota (workers yes, control plane no)

**Template enrichment is backwards compatible** — both fields are optional additions to the existing `default_node_request` format, not a restructuring. Templates without these fields work as before.

**This supports A4 (Resolve-at-Creation)** as the simplest viable approach.

### Live Resource Resolution Feasibility (confirmed via codebase analysis)

| Resource Type | Current Footprint Computable? | How |
|---------------|-------------------------------|-----|
| **VMs** | YES — fully sufficient | `spec.cores`, `spec.memory_gib`, `spec.boot_disk.size_gib` are structured fields |
| **Clusters** | YES — for quota purposes | `status.node_sets` contains `{host_class, size}` per node set. Node count by resource class = direct quota check |
| **Host Pools** | YES — for quota purposes | `status.host_sets` contains `{host_class, size}` |

**Key architectural detail:** Cluster resources have both `spec.node_sets` (desired state) and `status.node_sets` (actual state). They can diverge during scaling or degraded conditions. For quota purposes, **spec** represents the user's intent (what they requested), **approved_spec** (DB-internal) represents committed resources (what was approved). Quota should count **approved_spec** (the commitment), not status. The `/v1/usage` usage query endpoint computes usage from `approved_spec` in the FS DB.

**One limitation:** HostClass hardware details (CPU cores, RAM, GPU count) are stored as markdown text in `HostClass.description`, not structured fields. For quota purposes this doesn't matter — quotas count nodes by resource class (e.g., `nodes.h100: 5`), not by raw hardware specs. But if future quotas need hardware-level granularity (e.g., `total_gpus`, `total_ram_gb`), HostClass needs structured fields added.

### Data Access Pattern (confirmed via architecture analysis)

The Fulfillment Service PostgreSQL DB and Kubernetes CRs on the hub are **complementary stores, not caches of each other**:
- **PostgreSQL** is the API-layer store: tenancy, auth context, approval state, template params, archived records
- **Kubernetes CRs** are the orchestration-layer store: operator communication, provisioning state
- Spec flows out (DB → CR), status flows back (CR → DB)

The Quota Service MUST access data via the **Fulfillment Service gRPC/REST API**, never direct DB access or direct K8s API:
- Direct DB: bypasses auth/tenancy isolation, couples to schema, two-writer problem
- Direct K8s: missing tenancy, approval state, template data
- Fulfillment API: proper auth, tenancy filtering, stable contract, combines both stores

**Performance:** API call (~5-20ms) vs direct DB (~1-5ms) is irrelevant at OSAC's approval frequency (a few per day per tenant). The QS reads tenant usage from the `/v1/usage` usage query endpoint — no cache:

```
GET /v1/usage?tenant=org-A
→ {clusters: 2, nodes.h100: 8, nodes.fc430: 3, compute_instances: 4, vcpus: 16}

GET /v1/usage?tenant=org-A&exclude=resource-xyz
→ {clusters: 1, nodes.h100: 3, nodes.fc430: 3, compute_instances: 4, vcpus: 16}
```

### Multi-Hub Architecture

The Fulfillment Service is a **single central instance**, not one-per-hub. It connects to multiple management clusters (hubs) via stored kubeconfigs:

- Each hub is registered with a kubeconfig and namespace via a **private gRPC API** (not exposed to tenants)
- Each hub runs its own OSAC Operator + AAP stack independently
- **Hub selection is currently random** -- no load balancing, no capacity awareness
- Once a resource is assigned to a hub, it stays there permanently (immutable assignment via `status.hub` field)
- Tenants cannot choose or see which hub they are on -- hub assignment is entirely transparent
- A single tenant can have resources scattered across multiple hubs
- **HubCache** provides lazy-loaded cached Kubernetes client connections per hub, so the Fulfillment Service does not re-authenticate on every operation

**Quota implication:** Cross-hub quotas come naturally with the B3 (no ledger) design because the central PostgreSQL database contains all resource records from all hubs. The Quota Service reads usage from the `/v1/usage` usage query endpoint, which queries PostgreSQL -- there is no need to aggregate across multiple hub APIs. This is a significant advantage of the centralized architecture.

### Resource Lifecycle Model

**CRITICAL:** There is NO separate "request" entity in OSAC. The resource record IS the request.

One row in the `clusters` / `compute_instances` / `host_pools` table represents the entire lifecycle of a resource. The record starts as a "request" (spec fields filled, status fields empty) and evolves into a live resource as provisioning progresses:

```
Without quotas:  creation → progressing → ready → deleted  (all same row)
With quotas:     creation → pending → gating → approved → progressing → ready → deleted  (all same row)
                 creation → pending → gating → rejected  (new resource stays rejected)
                 creation → pending → gating → rejected → pending (re-eval on footprint change)
                 approved → pending → gating → rejected → approved (scale rejected, spec > approved_spec)
                 approved (scale where spec ≤ approved_spec — stays approved immediately)
                 gating → expired  (approval timed out)
```

Key implications:
- The ClusterOrder / ComputeInstance / HostPool CRs on the hub are **only created AFTER approval** -- CR creation is the provisioning trigger
- During the pending/gating states, the resource exists only in the Fulfillment Service PostgreSQL database -- there is no Kubernetes representation on any hub
- The `status.approval` block is part of the existing resource row, not a separate approval table
- `spec` always holds the user's intent (what they requested); `approved_spec` (DB-internal, not in public API) holds the last approved state used for hub CR operations
- The reconciler uses `approved_spec` for hub CR operations, never `spec` directly
- Tenants see running state via `status.node_sets` (hub-reported) and usage via `/v1/usage`
- This means the Fulfillment Service List API returns pending, gating, approved, rejected, expired, and live resources from the same table -- the Quota Service can query all of them uniformly

### CRD Summary

All CRDs are under the `osac.openshift.io/v1alpha1` API group (note: some code still references the old name `cloudkit.openshift.io`):

| CRD | Short Name | Purpose | Key Spec Fields | Key Status Fields |
|-----|-----------|---------|-----------------|-------------------|
| **ClusterOrder** | `cord` | Cluster provisioning lifecycle | `templateID`, `templateParameters`, `nodeRequests[]` | `phase`, `conditions[]`, `clusterReference` |
| **ComputeInstance** | `ci` | VM provisioning lifecycle | `templateID`, `cores`, `memoryGiB`, `bootDisk`, `image` (most immutable) | `phase`, `virtualMachineReference`, `jobs[]` |
| **HostPool** | `hp` | Group of bare metal hosts | `hostSets[]` | phase, host status |
| **Tenant** | -- | Tenant organization | tenant identity | Creates namespace + OVN `UserDefinedNetwork` for L2 isolation |

Common annotation: `osac.openshift.io/management-state: manual|unmanaged` (controls operator reconciliation behavior).

### Data Flow Details

- **Template data flow:** AAP discovery job scans Ansible collections for `meta/osac.yaml` metadata, then publishes template information to the Fulfillment Service API, which stores it in the `cluster_templates` PostgreSQL table
- **Resource status flow:** Fulfillment Service creates CRs on the selected hub → Operator updates CR status fields → Fulfillment Service reconciler reads CR status back from the hub → updates PostgreSQL
- **Reconciler modes:** The Fulfillment Service reconciler operates in two modes:
  - **Event-driven:** PostgreSQL `NOTIFY`/`LISTEN` mechanism triggers immediate reconciliation when resource records change
  - **Periodic sync:** Hourly full reconciliation ensures no status updates are missed
- **Multi-hub overhead:** The reconciler must contact each hub's Kubernetes API to read CR status. More hubs = more API calls per reconciliation cycle. This is manageable at current scale but worth monitoring.

### DB Schema Gap: GPU for VMs

The `ComputeInstance` has structured fields for `cores`, `memory_gib`, and `boot_disk`, but there is **no GPU field**. GPU allocation is currently buried in `template_parameters` (unstructured JSON). This means GPU consumption cannot be efficiently queried or aggregated for quota enforcement without parsing JSON blobs.

**Action needed:** Add a `gpus` field to `ComputeInstanceSpec` (both the protobuf definition and the CRD) to support GPU quota enforcement as a first-class resource dimension.

### Per-Tenant Aggregation

The database stores individual resource records, not pre-computed per-tenant usage summaries. The `/v1/usage` usage query endpoint on the Fulfillment Service computes per-tenant aggregation via SQL from `approved_spec` in the FS DB:
- **Read-only, no state** — pure SQL aggregation on every call
- **`exclude` parameter** — omits a specific resource from the sum (used by QS to exclude the gated resource when computing "existing usage")
- **Authorization** — tenants see own usage, privileged accounts (QS service account) see all tenants
- **Consumers** — Quota Service (quota decisions), CLI (`get quota` command), UI (usage dashboard), future billing/capacity planning

### 2. Quota Data Source Integration Model

The proposal describes a generic Quota Service API that external systems push quotas into. For MOC, ColdFront pushes allocations via a plugin.

**Open questions:**
- What is the API contract for pushing quotas?
- Authentication/authorization for the quota push API?
- How are quota changes propagated (real-time push vs. periodic sync)?
- What happens if ColdFront and the Quota Service disagree?

### 3. Multi-Approval Workflows (RESOLVED — extensible gates structure)

Reviewer **knikolla** suggested replacing the boolean approved/rejected with a list-based `approved_by` to support multi-party approval (e.g., quota service + admin). The proposal author pushed back, preferring simplicity.

**Resolution:** The extensible `status.approval.gates` map addresses this. v1 has a single gate (`quota`), but new gate types can be added by implementing the gate service minimum contract. Multi-gate coordination semantics (reservation, rollback, ordering) are deferred to v2.

---

## Architecture Options Comparison

> **FINAL DECISION:** The brainstorming sessions converged on **spec-based computation with no ledger, K8s-like API model, and extensible gating**. The A4 (resolve-at-creation) concept evolved into a `spec` + `approved_spec` (DB-internal) model: `spec` = user's intent (always), `approved_spec` = last approved state used for hub CRs (not exposed in public API). B3 (no ledger) remains. `desired_spec`, `approved_resources`, `pending_resources`, and `resolved_resources` were all eliminated. QS reads tenant usage from `/v1/usage` usage query endpoint — no cache in the Quota Service. The comparison below is retained for historical context.

Two decisions are intertwined: how to **resolve** resource footprints, and how to **track** current usage. They must be evaluated together because some combinations are natural fits while others create contradictions.

### Decision A: Resource Resolution

How does the system determine what resources a request (or live resource) consumes?

#### A1: Resolution API in Fulfillment Service (Proposal Option 1)

Fulfillment Service exposes a `POST /resolve` endpoint. Quota Service calls it with a pending request, gets back a resource footprint.

```
Quota Service ──"resolve request xyz"──▶ Fulfillment Service
              ◀──{nodes.h100: 5}────────
```

| Aspect | Assessment |
|--------|------------|
| Separation of concerns | Good — Fulfillment Service owns all calculation logic |
| Template complexity | Handled — Fulfillment Service knows templates |
| Consistency | Strong — same logic used for resolution and provisioning |
| New API needed | Yes — must design, build, version, maintain |
| Latency | Extra network call per approval |
| Bidirectionality | Partial — can resolve templates, but resolving live resources requires additional work |
| Handles scale events | Only if Resolution API also supports "resolve current state of resource X" |
| Failure mode | If Fulfillment Service down, cannot resolve → cannot approve anything |
| Multiple consumers | Only if other services also call this API (billing, UI) |

#### A2: Direct Inspection by Quota Service (Proposal Option 2)

Quota Service reads the request spec directly and calculates resource footprint itself.

```
Quota Service ──reads spec──▶ request.spec.node_sets = {h100: 5}
              ──calculates──▶ {nodes.h100: 5}
```

| Aspect | Assessment |
|--------|------------|
| Separation of concerns | Poor — Quota Service must understand Fulfillment data model |
| Template complexity | Dangerous — must duplicate template defaults, parameter logic |
| Consistency | Weak — calculation logic can diverge from provisioning logic |
| New API needed | No |
| Latency | Lowest — no extra calls |
| Bidirectionality | Must implement both template and live resource parsing |
| Handles scale events | Must understand all spec change types |
| Failure mode | Self-contained, no external dependency for calculation |
| Multiple consumers | No — logic trapped inside Quota Service |

#### A3: Independent Resolution Service (Tutoring proposal)

Standalone service with three capabilities: `resolve_template()`, `resolve_resource()`, `resolve_all(tenant)`.

```
                    ┌─────────────────────┐
                    │  Resolution Service  │
Quota Service ────▶ │  resolve_template()  │
Billing ──────────▶ │  resolve_resource()  │
UI ───────────────▶ │  resolve_all()       │
Capacity planner ─▶ │                      │
                    └─────────────────────┘
```

| Aspect | Assessment |
|--------|------------|
| Separation of concerns | Best — dedicated service, clean boundaries |
| Template complexity | Handled — service owns resolution logic |
| Consistency | Strong — single source of truth for resolution |
| New API needed | Yes — entirely new service to design, build, deploy, operate |
| Latency | Extra network call(s) per approval |
| Bidirectionality | Full — designed for templates AND live resources |
| Handles scale events | Yes — resolve_resource() returns current state |
| Failure mode | New SPOF — if Resolution Service down, nothing can resolve |
| Multiple consumers | Yes — primary advantage |

**Key concern:** Where does this service get template knowledge? Templates are Ansible roles. The Resolution Service needs access to `meta/osac.yaml` metadata, `defaults/main.yaml`, and parameter specs. This is currently only available in the `osac-aap` repo / AAP Execution Environment.

#### A4: Resolve-at-Creation (Fulfillment Service stores resolved footprints)

> **HISTORICAL NOTE:** This concept evolved into the `desired_spec`/`spec` model. The `resolved_resources` field was eliminated — `spec` and `desired_spec` carry all information needed.

Fulfillment Service resolves the template at request creation time and stores the result as a field on the request object (e.g., `resolved_resources`). Scale operations update this field.

```
Request creation:
  Fulfillment Service ──resolves template──▶ stores in request object
     request.resolved_resources = {nodes.h100: 5, clusters: 1}

Scale event:
  Fulfillment Service ──updates──▶ request.resolved_resources = {nodes.h100: 8, clusters: 1}

Quota check:
  Quota Service ──reads──▶ request.resolved_resources (already there, no extra call)
```

| Aspect | Assessment |
|--------|------------|
| Separation of concerns | Moderate — Fulfillment Service takes on resolution responsibility |
| Template complexity | Handled — resolved once at creation |
| Consistency | Good — resolved by the same system that accepts the request |
| New API needed | No new service, but Fulfillment Service needs resolution capability |
| Latency | Best — no extra calls at approval time (data already stored) |
| Bidirectionality | Yes — field is updated on scale, reflects current state |
| Handles scale events | Yes — if Fulfillment Service updates the field on every modification |
| Failure mode | No new dependency — data travels with the request |
| Multiple consumers | Partial — anyone who can read request objects gets resolved data |

**Key concerns:**
- Fulfillment Service must understand template internals (same as A1, but without a separate API)
- If resolution logic changes, previously stored footprints are stale (existing resources show old calculations)
- What about dynamic resource allocation? E.g., ESI node selection happens at provisioning time — the exact resource class might not be known at request time
- Resolution at creation assumes all parameters are known upfront — what about templates with late-binding values?

---

### Decision B: Usage Tracking

How does the Quota Service know what a tenant is currently consuming?

#### B1: Separate Usage Ledger (Proposal design)

Quota Service maintains its own PostgreSQL database with per-tenant usage totals. Updated on approval (+) and deletion (-).

| Aspect | Assessment |
|--------|------------|
| Approval speed | Fast — local DB read |
| Accuracy | Degrades over time (drift from missed events, failures) |
| Reconciliation | MANDATORY — without it, errors accumulate |
| Scale event handling | Must catch every scale event and update ledger |
| Operational complexity | High — second database to manage, backup, monitor |
| Fulfillment Service dependency | Low — only for watching events |
| Failure recovery | Ledger survives restart, but may be stale |
| Data for analytics | Yes — historical tracking possible |

#### B2: Per-Resource Ledger (Tutoring refinement)

Like B1, but tracks per-resource rows instead of per-tenant totals.

| Aspect | Assessment |
|--------|------------|
| Approval speed | Fast — local DB read + sum |
| Accuracy | Better than B1 for scale events — tracks individual resources |
| Reconciliation | Still mandatory |
| Scale event handling | Update the specific resource row |
| Operational complexity | Higher than B1 — more rows, more updates |
| Fulfillment Service dependency | Low |
| Failure recovery | Better — can identify which specific resource is wrong |
| Data for analytics | Best — full per-resource history |

#### B3: No Ledger / On-Demand Query (Latest discussion)

Quota Service stores only limits. Queries Fulfillment Service for current resources on every approval decision.

| Aspect | Assessment |
|--------|------------|
| Approval speed | Slower — network call + query + sum per approval |
| Accuracy | Perfect — always reads source of truth |
| Reconciliation | Unnecessary — no state to reconcile |
| Scale event handling | Automatic — query returns current state |
| Operational complexity | Lowest — no second database for usage |
| Fulfillment Service dependency | FULL — every approval decision requires Fulfillment Service |
| Failure recovery | No state to recover — stateless (except limits) |
| Data for analytics | No — no historical tracking (would need separate analytics solution) |

**Key concerns:**
- At scale: listing + resolving all resources per tenant on every approval could be slow
- If Fulfillment Service has a brief hiccup during approval check, the request fails
- No usage history for trend analysis, capacity planning, or billing reports
- Race condition mitigation: still need per-tenant locking (on the limits table)

#### B4: Ledger as Cache with Mandatory Reconciliation (Hybrid)

Quota Service maintains a ledger (B1 or B2) but treats it as a cache. Mandatory reconciliation on startup and periodic (configurable). Reconciliation source: Fulfillment Service via API.

| Aspect | Assessment |
|--------|------------|
| Approval speed | Fast — local cache hit |
| Accuracy | Good — self-healing via reconciliation |
| Reconciliation | Built-in — core feature, not optional |
| Scale event handling | Best-effort update + reconciliation catches misses |
| Operational complexity | Medium — cache DB + reconciliation job |
| Fulfillment Service dependency | Moderate — needed for reconciliation but not for every decision |
| Failure recovery | Cache rebuilt from source of truth on startup |
| Data for analytics | Yes — if using per-resource variant |

---

### Compatible Combinations

Not all A+B combinations make sense. Here are the viable architectures:

```
                        B1: Ledger    B2: Per-Rsrc   B3: No Ledger   B4: Cache
                                       Ledger                         Ledger
A1: Resolution API        ✅ (1)        ✅ (2)          ⚠️ (3)         ✅ (4)
A2: Direct Inspection     ⚠️            ⚠️              ⚠️             ⚠️
A3: Resolution Service    ✅ (5)        ✅ (6)          ✅ (7)          ✅ (8)
A4: Resolve-at-Creation   ❌ (9)        ❌ (10)         ✅ (11)         ✅ (12)

✅ = natural fit    ⚠️ = works but has issues    ❌ = contradictory
```

**Why A2 is always ⚠️:** Direct inspection means the Quota Service must understand internal data models. This creates maintenance burden regardless of usage tracking approach. Not recommended.

**Why A4+B1/B2 is ❌:** If you've already resolved footprints into the request object, maintaining a separate ledger is redundant — you're duplicating data that's already in the Fulfillment Service DB.

### The Strongest Candidates

#### Candidate 1: A4+B3 (Resolve-at-Creation + No Ledger) — "The Simple One"

```
Fulfillment Service                          Quota Service
┌──────────────────────────┐                ┌─────────────────┐
│ Resolves template at     │                │ Stores limits    │
│ creation, stores in      │◀── queries ────│ only             │
│ request.resolved_resources│               │                  │
│ Updates on scale events  │                │ No ledger        │
└──────────────────────────┘                └─────────────────┘
```

- Fewest moving parts, no drift, no reconciliation
- Quota Service accesses data via Fulfillment Service gRPC API (not direct DB, not direct K8s)
- Best for: OSAC's current scale, fast time-to-market
- Risk: Fulfillment Service availability is critical; no usage analytics; resolve-at-creation may not handle late-binding resource allocation
- `/v1/usage` usage query endpoint on FS provides server-side usage computation; future: add Resolution API endpoint for billing/UI preview consumers

#### Candidate 2: A3+B3 (Resolution Service + No Ledger) — "The Clean One"

```
Fulfillment Service         Resolution Service        Quota Service
┌─────────────────┐        ┌──────────────────┐      ┌──────────────┐
│ Stores resources│◀─reads─│ resolve_template()│◀─────│ Stores limits│
│                 │        │ resolve_resource()│      │ No ledger    │
│                 │        │ resolve_all()     │      │              │
│                 │        └──────────────────┘      └──────────────┘
│                 │               ▲    ▲
│                 │               │    │
│                 │          Billing   UI
└─────────────────┘
```

- Cleanest architecture, reusable resolution, no drift
- Best for: long-term platform vision, multiple resolution consumers
- Risk: Most upfront work; new service to build and operate; Resolution Service is a new SPOF

#### Candidate 3: A4+B4 (Resolve-at-Creation + Cache Ledger) — "The Balanced One"

```
Fulfillment Service                          Quota Service
┌──────────────────────────┐                ┌──────────────────────┐
│ Resolves template at     │                │ Stores limits        │
│ creation, stores in      │◀── periodic ───│ Cache ledger         │
│ request.resolved_resources│   reconcile   │ (rebuilt on startup) │
│ Updates on scale events  │                │ Usage analytics      │
└──────────────────────────┘                └──────────────────────┘
```

- Fast approvals (cache hit), self-healing, supports analytics
- Best for: production robustness with usage reporting needs
- Risk: Moderate complexity; cache can be temporarily stale between reconciliation cycles

#### Candidate 4: A1+B4 (Resolution API + Cache Ledger) — "The Proposal's Intent, Hardened"

```
Fulfillment Service                          Quota Service
┌──────────────────────────┐                ┌──────────────────────┐
│ Exposes /resolve API     │◀── calls ──────│ Stores limits        │
│                          │                │ Cache ledger         │
│                          │◀── periodic ───│ (rebuilt on startup) │
│                          │   reconcile    │                      │
└──────────────────────────┘                └──────────────────────┘
```

- Closest to the original proposal but with mandatory reconciliation
- Best for: if the team prefers Fulfillment Service to own resolution as an API
- Risk: New API + cache + reconciliation = most operational complexity

### Comparison Matrix of Top Candidates

| Criterion | A4+B3 Simple | A3+B3 Clean | A4+B4 Balanced | A1+B4 Proposal+ |
|-----------|:------------:|:-----------:|:--------------:|:---------------:|
| Implementation effort | Low | High | Medium | Medium-High |
| Operational complexity | Lowest | Medium | Medium | Highest |
| Accuracy | Perfect | Perfect | Good (cache lag) | Good (cache lag) |
| Approval latency | Low | Medium | Lowest | Medium |
| Drift risk | None | None | Low (self-healing) | Low (self-healing) |
| Handles scale events | Auto | Auto | Auto + cache update | Manual + reconcile |
| Multiple consumers | Partial | Full | Partial | Partial |
| Usage analytics | No | No | Yes | Yes |
| New services to build | 0 | 1 | 0 | 0 (new API) |
| SPOFs added | 0 | 1 | 0 | 0 |
| Fulfillment Svc dependency | Full | Moderate | Moderate | Full |
| Late-binding resources | Problematic | Handled | Problematic | Handled |
| Survives Fulfillment outage | No | No | Yes (cache) | Yes (cache) |

### Late-Binding Resource Problem (affects A4)

One concern specific to A4 (Resolve-at-Creation) that hasn't been fully explored:

When a tenant requests "5 GPU nodes," the exact resource class might not be known at request time. ESI node selection happens during provisioning — the system might assign h100 or a100 depending on availability. If the template says "give me 5 GPU nodes" without specifying the exact class, the resolved footprint at creation time would be ambiguous.

```
Request time:   template says "5 GPU nodes" → resolved_resources = {nodes.gpu: 5}  ???
Provisioning:   ESI assigns 3x h100 + 2x a100 → actual = {nodes.h100: 3, nodes.a100: 2}
```

If quotas are tracked per specific resource class (nodes.h100, nodes.a100), resolve-at-creation may not have enough information. The Resolution API (A1) or Resolution Service (A3) could query ESI at approval time, but resolve-at-creation (A4) stores whatever is known at request time.

**Counterargument:** OSAC templates currently specify resource classes explicitly (e.g., `resourceClass: fc430`), so this may not be a real problem today. But it's a constraint worth documenting.

### Recommendation

> **UPDATE:** The recommendation below (A4+B3) has been refined further through brainstorming sessions into the K8s-like API model with extensible gating. The final architecture retains B3 (no ledger) but uses `spec` (user's intent, always) + `approved_spec` (DB-internal, last approved state for hub CRs). `desired_spec` was eliminated entirely. QS reads tenant usage from `/v1/usage` usage query endpoint — no cache in the Quota Service. Gate services (v1: quota only) write to their own gate entry; the FS owns state transitions and `approved_spec` updates internally.

**Final architecture: 5 deliverables across 3 layers**
1. `/v1/usage` usage query endpoint
2. Approval workflow — `status.approval` block
3. Gating semaphore
4. `OSAC_APPROVAL_REQUIRED` flag
5. Quota Service

- `spec` = user's intent (always); `approved_spec` = last approved state used for hub CR operations (DB-internal only, not in public API)
- Gate services write only to their own gate entry (`gates.quota.admitted`, `gates.quota.reason`), never to `state`
- FS manages state transitions (pending → gating → approved/rejected/expired) and sets `approved_spec = spec` internally on approval
- Gating semaphore: one resource per tenant in gating at a time, serializes evaluation
- Scale rule: new spec > approved_spec → pending (re-evaluation); <= → approved immediately
- Re-evaluation: on footprint change, FS (deletion/scale-in) or QS (limit increase) sets rejected → pending
- 3-step reconciler: (1) approved_spec empty → skip, (2) approved + changed → update hub + sync, (3) approved_spec non-empty → sync status from hub (covers rejected/expired with existing CRs)
- No footprint cache in QS — reads tenant usage from `/v1/usage` usage query endpoint on FS
- Fewest moving parts, no drift, no reconciliation
- Limitation: no usage analytics, Fulfillment Service dependency
- Acceptable because: OSAC's scale is small, analytics can come later

**For OSAC v2 (production-hardened):** Evolve to add cache ledger (B4) if usage analytics are needed, or extract Resolution Service (A3) if multiple resolution consumers emerge.

## Gap Analysis

### Gaps in the Proposal

| Gap | Description | Severity |
|-----|-------------|----------|
| **No template resolution mechanism exists** | Quota Service cannot determine resource footprint of a request today | Blocker |
| **No test plan** | Proposal says "TBD" | High |
| **No graduation criteria** | Proposal says "TBD" | High |
| **No support procedures** | Proposal says "TBD" | Medium |
| **No UI components** | Explicitly out of scope, but tenants need to see quotas somewhere eventually | Medium |
| **No error UX design** | How does a rejected request surface to the user in CLI/UI? | Medium |
| **No CLI/UI workflow for pending/rejected states** | Does CLI poll for approval? How does tenant check quota before submitting? Can they see rejected requests in `get clusters`? How does osac-ui display pending/rejected? None of this is designed. | Medium |
| **~~Template change vs. ledger integrity~~** | ~~If a template is updated after provisioning, ledger would decrement wrong amount.~~ **RESOLVED:** No-ledger design eliminates this — `spec` always reflects the current approved state. | Medium |
| **No migration/rollout plan** | How do existing deployments adopt quotas? What happens to existing resources without approval state? **Resolution:** DB migration sets existing resources to `status.approval.state = "approved"` with `approved_spec = spec`. No ledger initialization needed. Use `OSAC_APPROVAL_REQUIRED` flag for gradual rollout. | High |
| **No scale/update workflow** | Proposal only covers create and delete. Scaling a cluster (adding/removing workers) needs approval for scale-up. **RESOLVED:** The scale rule handles this — if new spec > approved_spec, state resets to pending for re-evaluation; if <= approved_spec, stays approved immediately. | High |
| **No quota reduction policy** | What happens when admin reduces quota below current usage? Proposal doesn't say. | Medium |
| **VM quota granularity undefined** | Cluster quotas count nodes by resource class, but VM quotas (vCPUs? memory? GPU passthrough?) not specified | Medium |
| **No capacity planning guidance** | How does a service provider decide what quota limits to set? | Low |
| **Risks and Drawbacks say "N/A"** | There are clearly risks — these sections need to be filled | Medium |

### Technical Concerns Not Addressed

| Concern | Details |
|---------|---------|
| **Race conditions** | Two requests from same tenant arrive simultaneously. Both pass quota check before either is recorded. Both get approved. Tenant exceeds quota. **Mitigation:** Gating semaphore — only one resource per tenant can be in the `gating` state at a time. The FS serializes transitions from `pending` to `gating`, eliminating concurrent evaluation races without database-level locking in the Quota Service. |
| **Consistency under failure** | Quota Service approves request, but provisioning fails (e.g., ESI has no nodes). With the no-ledger design, failed resources still exist in DB and count against quota until the tenant explicitly deletes them. This is correct because failures can be partial (e.g., 3 of 5 nodes allocated). No ledger revert needed. |
| **~~Ledger drift~~** | ~~Over time, if deletion events are missed, the ledger drifts from reality.~~ **RESOLVED:** No-ledger design eliminates this concern entirely. Usage is always computed from current resource specs via Fulfillment Service API. |
| **Performance at scale** | Quota Service polls for pending requests across all tenants. Polling-based for v1 (not Events API) because the Fulfillment Service Events API only supports Cluster/ClusterTemplate payloads. Will migrate to Events API when it is extended to cover all resource types. |
| **Security** | Quota Service has write access to its gate entry (`gates.quota`) on all resources. Compromise = admit anything through the quota gate. **Mitigations:** Dedicated Keycloak service account with narrow `gate-writer` role (least privilege). ColdFront plugin needs separate `quota-admin` role. Defense in depth: audit logging, rate limiting, change validation (reject impossibly large quotas), network policies, alerting on threshold changes. |
| **Optional deployment** | Once the `status.approval` block is added to the API schema, all requests default to "pending." Without a Quota Service running, all requests stuck forever. **Mitigation:** Configuration flag `OSAC_APPROVAL_REQUIRED` (default false for backwards compatibility). When false, requests default to "approved" with `approved_spec = spec`, and the gating workflow is skipped entirely. |
| **Data architecture** | What database for limits? Schema design? Backup/restore? HA? (Simplified by no-ledger, no-cache design — only quota limits need to be stored.) |
| **Quota Service availability** | If Quota Service is down, gating resources are never evaluated (stuck in gating state forever). v1 uses single replica (consistent with all OSAC components at `replicas: 1`). No HA for v1. |
| **Observability** | Prometheus metrics: `quota_gate_decisions_total` (counter by decision), `quota_gating_resources` (gauge of resources in gating state), `quota_utilization_ratio` (gauge per tenant per resource key), `quota_decision_duration_seconds` (histogram). Alerts: `GatingBacklog` (gating resources not processed), `ServiceDown` (quota service unavailable), `TenantNearLimit` (tenant approaching quota). |

---

## Stakeholder Positions (from PR Discussion)

| Stakeholder | Position |
|-------------|----------|
| **larsks** (author) | Generic approval workflow; OSAC stays simple; quota logic in pluggable external service |
| **avishayt** | OSAC should be the source of truth for quotas and resource tracking |
| **okrieg** | Acknowledges multi-service reality (storage, OpenShift, OpenStack, SLURM quotas); prefers OSAC-integrated but accepts external approach |
| **mhrivnak** | Fulfillment Service should resolve requests into measurable resources; quotas should apply to nodes regardless of how they're used |
| **knikolla** | Suggests multi-party approval (approved_by list) |
| **oourfali** | Questions about template resolution, control plane accounting, ColdFront integration details |

---

## Action Items / TODO

### Decisions to Make

- [x] **Choose resource resolution approach** — DECIDED: spec-based computation using `spec` + `approved_spec` (DB-internal). No separate resolution API, service, or resource tracking fields needed. QS reads usage from `/v1/usage` usage query endpoint.
- [x] **Decide on multi-approval extensibility** — DECIDED: Extensible gates structure in `status.approval.gates`. v1 has a single gate (`quota`). Multi-gate coordination semantics (reservation, rollback, ordering) deferred to v2.
- [ ] **Define VM quota granularity** — What keys? `compute_instances`? `vcpus`? `memory_gb`? `gpus`? (Remains open — cluster quotas are well-defined but VM quotas need further discussion.)
- [x] **Mandatory vs. optional reconciliation** — DECIDED: No reconciliation needed. No-ledger design (B3) means usage is always computed from source of truth (resource specs via Fulfillment Service API).
- [x] **Quota Service HA requirements** — DECIDED: Single replica (`replicas: 1`), consistent with all OSAC components. No HA for v1.
- [x] **Polling vs. Events API** — DECIDED: Polling-based for v1. Events API only supports Cluster/ClusterTemplate payloads; will migrate when extended.
- [x] **Quota scope** — DECIDED: Global-per-organization, not per-hub. Natural consequence of central Fulfillment Service DB.
- [x] **Processing order** — DECIDED: No guaranteed ordering. FIFO was considered and dropped.
- [x] **~~desired_spec representation~~** — SUPERSEDED: `desired_spec` eliminated entirely. `spec` = user's intent (always); `approved_spec` (DB-internal) = last approved state for hub CRs.

### Enhancement Proposal Review Comments to Post

> **HISTORICAL:** These comments were drafted for the original PR #8. The new proposal on branch `enhancement/quota-management-v2` addresses all of these concerns. These are retained for reference only.

- [x] ~~Post analysis of Option 3 (Template Resolution as independent capability) to PR #8~~ — addressed in new proposal
- [x] ~~Comment on race condition risk — two concurrent requests from same tenant~~ — addressed in new proposal
- [x] ~~Comment on failure consistency — approval recorded but provisioning fails~~ — addressed in new proposal
- [x] ~~Request the Risks/Drawbacks sections be filled in (currently "N/A")~~ — addressed in new proposal
- [x] ~~Request clarification on Quota Service watching mechanism (push vs. pull)~~ — DECIDED: polling-based for v1
- [x] ~~Suggest adding a migration/rollout section for existing deployments~~ — addressed in new proposal
- [x] ~~Ask about Quota Service security model (it has powerful write access)~~ — addressed in new proposal
- [x] ~~Raise missing scale/update workflow — proposal only covers create/delete~~ — addressed in new proposal
- [x] ~~Raise missing CLI/UI workflow — how do pending/rejected states surface to users?~~ — addressed in new proposal
- [x] ~~Raise template change vs. ledger integrity concern~~ — resolved by no-ledger design
- [x] ~~Suggest `OSAC_APPROVAL_REQUIRED` flag for optional deployment~~ — addressed in new proposal
- [x] ~~Raise quota reduction policy — what happens when quota drops below current usage?~~ — addressed in new proposal

### Research Needed

- [ ] **ColdFront deep dive** — Understand the plugin model, how the OpenShift/OpenStack plugins work, to inform the OSAC plugin design
- [x] **Template resolution current state** — RESOLVED: spec-based computation eliminates the need for a separate resolution API. Template enrichment uses optional `countParameter` and `quotable` fields in `meta/osac.yaml`.
- [x] **Fulfillment Service API** — RESOLVED: `status.approval` block (with `state` and `gates` map) to be added to proto definitions. `approved_spec` is DB-internal only, not in proto. `/v1/usage` usage query endpoint added. `desired_spec` eliminated.
- [ ] **Existing quota systems** — Study how OpenShift ResourceQuota, OpenStack quota APIs, and Kubernetes LimitRange work for inspiration
- [x] **"Service Unit" concept** — ELABORATED: Service Units (SUs) are an abstract currency for resource accounting. MOC/NERC uses SUs with exchange rates (e.g., 1 GPU-hour = N SUs, 1 CPU-hour = M SUs). The Quota Service supports arbitrary key/value quota limits, so SU-based quotas can be expressed as a quota key (e.g., `service_units: 10000`). Exchange rates are deployment-specific configuration, not built into the Quota Service.

### Implementation Prerequisites (before quota work starts)

- [ ] `/v1/usage` usage query endpoint on Fulfillment Service — SQL aggregation from `approved_spec`, `exclude` parameter, tenant-scoped authz (tenants see own, privileged see all)
- [ ] Fulfillment API proto definitions must be extended with `status.approval` block (`state`, `gates` map) — note: `approved_spec` is DB-internal only, not in proto
- [ ] Template enrichment: add optional `countParameter` and `quotable` fields to `meta/osac.yaml` format
- [ ] Fulfillment Service gating semaphore logic (one resource per tenant in gating at a time)
- [ ] Fulfillment Service 5-state machine (pending → gating → approved/rejected/expired) and `approved_spec` lifecycle
- [ ] Fulfillment Service scale rule (spec > approved_spec → pending; <= → approved immediately)
- [ ] Quota Service database schema must be designed (limits only — no usage ledger, no footprint cache)
- [ ] Security model for Quota Service must be defined
- [ ] **ComputeInstance inMapper parity fix** — ensure ComputeInstance inMapper handles all fields consistently with other resource types
- [ ] **Field-level write protection on all public inMappers** — prevent tenants from writing fields they should not control (e.g., `status.approval` fields)
- [ ] **Immutability enforcement for `spec.template` and `spec.template_parameters`** — these fields must be immutable after creation to prevent quota circumvention
- [ ] **Field-level authorization in Fulfillment Service** — use `X-Roles` header to distinguish service-account writes (Quota Service writing gate entries) from tenant writes
- [ ] **Cross-tenant read access for Quota Service identity** — the Quota Service service account must be able to read `/v1/usage` for any tenant

---

## Implementation Roadmap

### Phase 0: Proposal Finalization (NEAR-COMPLETE)
- ~~Post review comments to PR #8 (all gaps, security, scaling)~~ Superseded by new proposal on branch `enhancement/quota-management-v2`
- ~~Drive decisions on open questions (resolution approach, reconciliation)~~ Resolved through multiple self-review rounds
- Proposal on branch `enhancement/quota-management-v2` in fork `zszabo-rh/enhancement-proposals`, ready for team PR creation
- Remaining: create PR against `osac-project/enhancement-proposals`, get team review and approval
- **Risk: Low technical, alignment effort focused on team review**

### Phase 1: Prerequisites (no quota code yet)
- Implement `/v1/usage` usage query endpoint on Fulfillment Service (SQL aggregation from `approved_spec`, `exclude` parameter, tenant-scoped authz)
- Add `status.approval` block to Fulfillment API proto definitions (`state`, `gates` map) — note: `approved_spec` is DB-internal only, not in proto
- Implement 5-state machine in Fulfillment Service (pending → gating → approved / rejected / expired)
- Implement gating semaphore logic (one resource per tenant in gating at a time)
- Implement scale rule (spec > approved_spec → pending; <= → approved immediately)
- Implement `approved_spec` lifecycle (FS sets `approved_spec = spec` internally when all gates admit)
- Template enrichment: add optional `countParameter` and `quotable` fields to existing `default_node_request` format in `meta/osac.yaml`
- `OSAC_APPROVAL_REQUIRED` config flag in Fulfillment Service
- Database migration for existing resources (set `status.approval.state = "approved"`, `approved_spec = spec` internally)
- 3-step reconciler: (1) approved_spec empty → skip, (2) approved + changed → update hub + sync, (3) approved_spec non-empty → sync status from hub
- ComputeInstance inMapper parity fix
- Field-level write protection on all public inMappers
- Immutability enforcement for `spec.template` and `spec.template_parameters`
- Field-level authorization in Fulfillment Service (using `X-Roles` header)
- Cross-tenant read access for Quota Service identity
- **Risk: The /v1/usage endpoint, gating semaphore, 5-state machine, and field-level authorization in Fulfillment Service are the main implementation efforts**

### Phase 2: Core Quota Service
- Quota Service skeleton (Go service with PostgreSQL for limits only — no usage ledger, no footprint cache)
- Quota CRUD API (create, read, update, delete limits)
- Watch for gating resources (not pending — the FS manages the pending → gating transition via the semaphore)
- Read tenant usage from `/v1/usage` usage query endpoint (with `exclude` parameter for the gated resource)
- Gate evaluation: `/v1/usage(tenant, exclude=gated_resource) + spec_of_gated_resource <= limits` → write `gates.quota.admitted` (bool) + `gates.quota.reason` (string)
- Re-evaluation trigger: on footprint change, set rejected (non-expired, non-deleted) resources back to pending
- **Risk: Medium — well-understood patterns, simplified by no-ledger design and gating semaphore (no need for QS-side locking)**

### Phase 3: Integration and Hardening
- Keycloak service accounts (`gate-writer`, `quota-admin` roles)
- Failure handling (no ledger to revert — failed resources still exist in DB and count against quota until explicitly deleted, which is correct for partial failures)
- CLI updates (show pending/rejected states, `get quota` commands)
- Observability:
  - Prometheus metrics: `quota_gate_decisions_total` (counter by decision type), `quota_gating_resources` (gauge of resources in gating state), `quota_utilization_ratio` (gauge per tenant per resource key), `quota_decision_duration_seconds` (histogram of decision latency)
  - Alerts: `GatingBacklog` (gating resources not evaluated within SLA), `ServiceDown` (quota service unavailable), `TenantNearLimit` (tenant approaching quota threshold)
- **Risk: Medium — failure handling simplified by no-ledger design**

### Phase 4: MOC-Specific Integration
- ColdFront OSAC plugin
- E2E testing on hypershift1
- Migration of existing MOC tenants (DB migration sets `status.approval.state = "approved"`, `approved_spec = spec` — no ledger initialization needed)
- **Risk: HIGH — breaking existing MOC tenants would compromise real research workloads**

### Phase 5: Polish
- UI updates in osac-ui (quota display, denial messages, usage dashboard)
- Documentation and training materials
- Graduation criteria met
- **Risk: Low**

### Stakeholder Map

| Decision | Key Stakeholders |
|----------|-----------------|
| Resource resolution approach | larsks, mhrivnak, oourfali |
| OSAC vs. ColdFront source of truth | avishayt, okrieg, larsks |
| Template system changes | larsks |
| Fulfillment API changes | mhrivnak, larsks |
| ColdFront plugin | okrieg, MOC/NERC contacts |
| Security model | avishayt |

### Success Criteria

1. Set quota limits for a tenant (via API or ColdFront)
2. Tenant requests cluster → approved if within quota, rejected with `decision_reason` if not
3. Tenant scales cluster up → approved or rejected based on delta
4. Tenant deletes cluster → quota freed
5. Tenant can view their limits and usage via CLI
6. Admin can view all tenants' limits and usage
7. System recovers cleanly from Quota Service restarts (stateless — no ledger or cache to recover)
8. Existing OSAC deployments upgrade without disruption

---

### Draft PR Review Comments (HISTORICAL — drafted for PR #8, now superseded by new proposal)

**Comment 1 — Resource Resolution (on the Resource Resolution section):**
> The proposal presents two options, but consider a simpler path: spec-based computation with a metering endpoint. The `/v1/usage` endpoint on the Fulfillment Service computes per-tenant usage from `approved_spec` (DB-internal) via SQL aggregation. The Quota Service reads usage from this endpoint and applies the formula: `/v1/usage(tenant, exclude=gated_resource) + spec_of_gated_resource <= limits`. No separate `resolved_resources` field, no resolution API needed.
>
> This requires enriching `meta/osac.yaml` with optional `countParameter` and `quotable` fields on `default_node_request` entries. This is additive and backwards compatible.

**Comment 2 — Usage Tracking (on the Quota Service section):**
> The usage ledger is unnecessary. The Quota Service stores only limits and reads tenant usage from the `/v1/usage` usage query endpoint on the Fulfillment Service. Formula: `/v1/usage(tenant, exclude=gated_resource) + spec_of_gated_resource <= limits`. This eliminates drift, reconciliation, and missed-event bugs entirely. At OSAC's current scale, a query per approval is trivially fast.

**Comment 3 — Scaling (on the Workflow Description):**
> The proposal covers create and delete but not scaling. Adding workers (scale-out) or vCPUs to a VM (scale-up) is new resource consumption that must go through approval. Scale-in/down frees resources and doesn't need approval but must update usage. This needs first-class support in the approval workflow — the Quota Service must understand delta changes, not just new resource creation.

**Comment 4 — Optional Deployment and Missing States (on the API Extensions section):**
> 1. Once `approval_state` defaults to `"pending"`, deployments without a Quota Service will have all requests stuck. Suggest an `OSAC_APPROVAL_REQUIRED` config flag (default `false`). When false, requests default to `"approved"` — preserving existing behavior.
> 2. What happens when provisioning fails after approval? With the no-ledger approach this resolves naturally — failed resources still exist in DB and count against quota until the tenant explicitly deletes them. This is correct because failures can be partial (e.g., 3 of 5 nodes allocated before failure). No new approval states needed. Worth documenting this lifecycle explicitly.

**Comment 5 — Risks (on the Risks and Mitigations section):**
> This section says "N/A" but there are risks worth documenting:
> - **Race conditions:** Two concurrent requests from the same tenant can both pass quota check. Needs per-tenant locking.
> - **Security:** Quota Service has write access to `approval_state` on all resources. Needs a narrow Keycloak service account with least-privilege `approval-writer` role. ColdFront needs a separate `quota-admin` role.
> - **Availability:** Quota Service down = all requests blocked. What's the HA story?

**Comment 6 — Gaps (general comment):**
> Gaps to address before merging:
> - **Migration:** Existing resources should get `approval_state = "approved"`. All states (READY, PROGRESSING, FAILED) — they were implicitly approved.
> - **Quota reduction:** Suggest: existing resources unaffected, new requests rejected until usage drops below new limit.
> - **CLI/UI:** How do pending/rejected states surface? Can tenants check limits before submitting?

**Comment 7 — Data Integrity (on the Quota Service section):**
> With the no-ledger approach (spec-based computation), template versioning is a non-issue. Current `approved_spec` (DB-internal) always reflects the committed state. The quota formula `/v1/usage(tenant, exclude=gated_resource) + spec_of_gated_resource <= limits` always uses current data.

**Comment 8 — ColdFront Auth (on the MOC/ColdFront section):**
> How does the ColdFront plugin authenticate to the Quota Service API? Suggest a `quota-admin` Keycloak role, separate from the `approval-writer` role the Quota Service uses for setting approval status.

---

### Design Decisions Made During Brainstorming

- [x] **K8s-like API model.** `spec` = user's intent (always written by FS on behalf of tenant). `approved_spec` (DB-internal, not in public API) = last approved state, used by reconciler for hub CR operations. Reconciler never reads `spec` directly. This mirrors the Kubernetes spec/status contract.
- [x] **No `desired_spec`.** Eliminated entirely. `spec` always represents intent; `approved_spec` tracks what has been approved. No need for a separate "desired" field.
- [x] **Extensible gates structure.** `status.approval.gates` is a map of gate entries. v1 has one gate (`quota`). Each gate entry has `state` (pending/admitted/rejected), `reason` (string), and `timestamp`. Gate-level `state` is set to `pending` by the FS when the resource enters gating; the gate service writes `admitted` or `rejected`. Gate services write only to their own gate entry, never to `state` or `approved_spec`.
- [x] **5 approval states.** `pending` (waiting for gating semaphore), `gating` (being evaluated by gate services), `approved` (all gates admitted), `rejected` (a gate rejected), `expired` (approval timed out or resource expired).
- [x] **Gating semaphore.** One resource per tenant in `gating` at a time. FS manages pending → gating transitions. Serializes gate evaluation per tenant, eliminating concurrent evaluation races without QS-side locking.
- [x] **Scale rule.** New spec > approved_spec → state resets to pending (re-evaluation required). New spec <= approved_spec → stays approved immediately (shrinking or unchanged, no re-gating needed).
- [x] **Re-evaluation trigger.** On footprint change: FS triggers for deletions/scale-ins, QS triggers for quota limit increases. Rejected (non-expired, non-deleted) resources set back to pending. Normal gating flow re-evaluates.
- [x] **No footprint cache in QS.** QS reads tenant usage from `/v1/usage` usage query endpoint on FS. No cache, no drift, no reconciliation.
- [x] **Gate service minimum contract.** A gate service watches for gating resources, evaluates its gate, writes `admitted` + `reason` to its own gate entry. Never writes `state` or `approved_spec`. This is the entire contract for adding new gate types.
- [x] **Multi-gate coordination deferred to v2.** v1 has a single gate. Multi-gate semantics (reservation, rollback, ordering across gates) are future work.
- [x] **No resource tracking fields needed.** `approved_resources`, `pending_resources`, and `resolved_resources` concepts were all eliminated. Usage is computed from resource specs on demand.
- [x] **QS writes `gates.quota.admitted=false` for rejection** (the approval state is `rejected`, not `denied`). Gate services never write the `state` field — FS sets state based on gate outcomes.
- [x] **3-step reconciler logic.** (1) approved_spec empty: skip, (2) approved + spec != approved_spec: update hub CR, (3) approved_spec non-empty: sync status from hub (ensures rejected/expired resources with existing CRs still get status updates).
- [x] **Template enrichment is backwards compatible.** Two optional fields (`countParameter` and `quotable`) added to existing `default_node_request` format in `meta/osac.yaml`. This is additive — templates without these fields work as before.
- [x] **Pending/gating resources are frozen.** No modifications allowed while a resource is in pending or gating state. This avoids races and simplifies computation.
- [x] **Tenants don't write `spec` directly.** The FS manages `spec` on behalf of tenant requests.
- [x] **Migration strategy:** Existing resources get `status.approval.state = "approved"` and `approved_spec = spec` via DB migration. In-flight (PROGRESSING) resources also treated as approved.
- [x] **Quota reduction policy:** Quota changes do NOT affect existing resources. Tenants must voluntarily reduce usage. New requests rejected until usage drops below new quota.
- [x] **Scale operations:** Scale-up (spec > approved_spec) goes through gating workflow. Scale-down (spec <= approved_spec) stays approved immediately.
- [x] **Optional deployment:** `OSAC_APPROVAL_REQUIRED` config flag (default false). When false, requests default to "approved" with `approved_spec = spec` — no Quota Service needed.
- [x] **Single replica deployment:** Consistent with all OSAC components at `replicas: 1`. No HA complexity for v1.
- [x] **Polling-based for v1:** Events API only supports Cluster/ClusterTemplate payloads. Quota Service uses polling; will migrate to Events API when extended.
- [x] **Global-per-organization quotas:** Not per-hub. Natural consequence of central Fulfillment Service DB.
- [x] **v1 independently shippable:** Quota feature does not depend on the Organizations proposal and ships before it.
- [x] **Idempotent reconciliation:** The Quota Service evaluation is idempotent. Re-evaluating a resource produces the same gate result.
- [x] **Deletion of pending/gating resources is allowed:** Only modifications are blocked.
- [x] **Processing order not guaranteed:** FIFO ordering was considered and dropped.
- [x] **Auto-approve drain:** When `OSAC_APPROVAL_REQUIRED` changes from `true` to `false`, all pending resources are automatically approved.

### Future Work (out of scope for v1 but track)

- [ ] UI for quota visibility (tenant view: my quotas and usage)
- [ ] Admin UI for quota management
- [ ] Billing integration
- [ ] Capacity planning / predictive quota management
- [ ] Cross-hub quota enforcement -- note that the no-ledger design (B3) naturally supports cross-hub since the central PostgreSQL has all resources from all hubs, so this is less of a concern than originally anticipated
- [x] **~~Per-tenant usage aggregate endpoint~~** — Now part of v1 as the `/v1/usage` usage query endpoint. No longer future work.
- [ ] **Scale-out approval UX** — moved from open question to future work. How does the UI/CLI present scale approval decisions? What is the tenant experience when a scale-out is rejected?
- [ ] **Events API migration** — when the Fulfillment Service Events API is extended beyond Cluster/ClusterTemplate payloads, migrate Quota Service from polling to event-driven processing
- [ ] **Multi-gate coordination semantics** — v1 has a single gate (`quota`). Future versions may add additional gates (e.g., manual admin approval, compliance checks). Multi-gate coordination (reservation, rollback, ordering across gates) needs design work.
- [ ] **Gateway-routed access** — when the Organizations proposal (Gateway/Kuadrant/Authorino architecture) is implemented, migrate Quota Service from direct Fulfillment Service access to Gateway-routed access. Network policy should be designed with this migration path in mind.

### Organizations Proposal Interaction

The Organizations proposal (PR #14) has been merged and introduces a Gateway/Kuadrant/Authorino architecture for multi-tenant access control.

**Key interaction points:**
- **Quota v1 ships before Organizations** — quota feature uses direct Fulfillment Service gRPC access, not Gateway-routed
- **Migration path:** When Organizations is implemented, the Quota Service will migrate to Gateway-routed access. The v1 network policy should be designed to allow this transition (e.g., allow both direct and Gateway-routed access during migration)
- **Identity model:** v1 uses a Keycloak service account for the Quota Service. Organizations may introduce a different identity model (Authorino-managed). The `X-Roles` header approach for field-level authorization is compatible with both models
- **Tenant scoping:** v1 quotas are global-per-organization. Organizations may introduce sub-organization scoping. The quota key/value model is extensible to support hierarchical quotas in the future

---

## Key Learnings from Tutoring Session

1. **Hub worker nodes are heavily loaded** — they host tenant cluster control planes (HyperShift pods), tenant VMs (OCP-Virt), and all OSAC infrastructure. This is relevant for VM quota design.
2. **Cluster control planes don't consume separate machines** — only worker nodes count. This simplifies cluster quota accounting.
3. **Bare metal hosts from ESI ARE the cluster worker nodes** — same pool, not separate. Quota keys like `nodes.h100` apply whether the node is in a cluster or standalone.
4. **Template resolution is simpler than initially expected** — spec-based computation using `spec` + `approved_spec` (DB-internal) eliminates the need for a separate resolution API or service. Template enrichment with optional `countParameter` and `quotable` fields is sufficient. The `/v1/usage` usage query endpoint provides server-side usage aggregation.
5. **The approval/gating pattern is more general than quotas** — extensible gates structure can support manual approval, compliance checks, etc. v1 has a single gate (`quota`); new gate types can be added by implementing the gate service minimum contract.
6. **Provisioning failure handling is simplified by no-ledger design** — failed resources still exist in DB and count against quota until explicitly deleted. This is correct because failures can be partial. No ledger revert needed.
7. **Reconciliation is unnecessary with spec-based computation** — usage is always computed from the source of truth (resource specs via Fulfillment Service API). No ledger means no drift.
8. **Race conditions solved by gating semaphore** — one resource per tenant in gating at a time. The FS serializes pending → gating transitions, eliminating concurrent evaluation races without database-level locking in the Quota Service.
9. **Fulfillment Service already has a database of tenant resources** — it tracks ClusterOrders, ComputeInstances, etc. in PostgreSQL. The Quota Service queries this via gRPC API to compute footprint on demand (no cache).
10. **K8s-like spec/approved_spec model** — `spec` = user's intent (always); `approved_spec` = last approved state for hub CRs. Scale rule: spec > approved_spec → pending; <= → approved immediately.
11. **Clear responsibility separation** — Gate services write only to their own gate entry (e.g., `gates.quota`). FS owns state transitions and `approved_spec` updates. Re-evaluation trigger: FS (deletion/scale-in) or QS (limit increase) sets rejected → pending.
