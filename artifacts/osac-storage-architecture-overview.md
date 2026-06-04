# OSAC Storage Architecture Overview

**Purpose:** Living architecture document for OSAC storage — VMaaS, CaaS, vendor integration, and open questions.
**Last updated:** 2026-06-04
**Author:** Zoltan Szabo (with Claude Code research assistance)

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Key Decisions (May 14 Storage Meeting)](#key-decisions)
3. [Component Map](#component-map)
4. [Current State Summary](#current-state-summary)
5. [VMaaS Storage Flow (End to End)](#vmaas-storage-flow)
6. [CaaS Storage Flow (What Exists vs What's Missing)](#caas-storage-flow)
7. [Storage Isolation Model](#storage-isolation-model)
8. [Vendor Integration Model](#vendor-integration-model)
9. [Competing Models and Resolution](#competing-models-and-resolution)
10. [Avishay vs Michael Debate (Architectural Direction)](#architectural-direction-debate)
11. [Jira Ticket Landscape](#jira-ticket-landscape)
12. [Enhancement Proposals](#enhancement-proposals)
13. [PR Status](#pr-status)
14. [Open Questions and Decision Points](#open-questions-and-decision-points)
15. [Meeting History and Context](#meeting-history)
16. [Appendix: File Paths](#appendix)

---

## Executive Summary

OSAC storage is currently designed and partially implemented for VMaaS only. The system uses a label-based StorageClass discovery mechanism on the hub/management cluster, with the Tenant controller as the single source of truth for StorageClass resolution.

**The May 14 storage meeting established key architectural principles:**
- Storage provisioning happens at **tenant onboarding time** (not JIT per VM)
- Use **vendor-native CSI drivers** (custom OSAC CSI proxy rejected)
- **Backend storage is source of truth** for quotas (not OSAC)
- **Template-based configuration** for per-tenant StorageClass creation
- **Full automation**, no human-in-the-loop
- Storage tier definitions will eventually **elevate to CRDs** (OSAC-882)

**What exists today (merged in upstream):**
- Multi-tier StorageClass resolution in Tenant controller (PRs #199, #204)
- `tenant_storage_class` Ansible role for tier-aware selection at VM provisioning time (PR #291)
- StorageClasses injection into AAP extra_vars from CI controller (PR #229)
- Label convention: `osac.openshift.io/tenant` + `osac.openshift.io/storage-tier`
- Tenant CRD with `status.storageClasses` list

**What's in PR (not merged):**
- Automated SC provisioning via AAP (operator PR #210 + AAP PR #266) — E2E verified, awaiting harmonization
- VAST vendor integration with storage_provider role (AAP PR #296) — actively reworked by Will

**What's not started:**
- CaaS storage (provisioning storage *inside* child clusters)
- Dedicated VMaaS cluster storage (same gap as CaaS — remote cluster)
- Storage Tier Management APIs (OSAC-882 — epic created, unassigned)
- Storage quota enforcement (backend-native, per meeting decision)
- Multi-hub StorageClass provisioning

---

## Key Decisions (May 14 Storage Meeting)

These decisions were formally aligned on during the "OSAC Storage Provisioning: Unified Model for VMaaS and CaaS" meeting facilitated by Zoltan Szabo.

### Aligned Decisions

| # | Decision | Detail |
|---|----------|--------|
| 1 | **Onboarding-time provisioning** | SC creation triggered by quota allocation during tenant onboarding, NOT per VM/cluster request (JIT rejected for near-term) |
| 2 | **Template-based configuration** | Use template role pattern (`osac.templates.{{ provider }}_storage`) for per-tenant SC creation with vendor-specific credentials and parameters |
| 3 | **Custom CSI proxy rejected** | No custom OSAC CSI controller/proxy. Use vendor-native CSI drivers for both provisioning and mounting |
| 4 | **Backend storage = quota truth** | The storage backend (VAST, Ceph, etc.) is the source of truth for quota enforcement and usage tracking. OSAC does not independently track storage usage |
| 5 | **Vendor-native metering** | Storage usage metering via vendor Prometheus endpoints, not a custom CSI read driver |
| 6 | **Full automation** | All tenant storage setup fully automated, no human-in-the-loop |

### Decisions Needing Further Discussion

| # | Topic | Status |
|---|-------|--------|
| 7 | **Storage tiers as CRDs** | Agreed in principle — elevate from Ansible env vars to OSAC operator CRDs. OSAC-882 now assigned to Akshay |
| 8 | **Global quota object** | Implement quota EP for compute, memory, and storage. Backend reconciliation logic TBD |
| 9 | **CaaS storage model** | Acknowledged as a gap. Will's `provisioning_target: caas` is a starting point but needs design |

### Action Items from Meeting

| Owner | Action | Status |
|-------|--------|--------|
| Akshay | Review and align existing storage epics or create umbrella epic | **In progress** — OSAC-882 assigned to Akshay; reworking epic per May 26 meeting |
| Akshay | Send summary of discussion topics on Slack | **Done** |
| Will, Akshay, Zoltan | Harmonize PR #266 and PR #296 | **Partial** — PR #296 merged May 27. PR #266 still open with CI failure |
| Akshay | Set up recurring storage meeting with Alona | **Done** — Tuesdays 3-4 PM CEST |
| Will | Transfer VAST ownership to Akshay/Zoltan before PTO | **Done** — credentials shared on Slack |
| Akshay | Connect with Avishay to finalize storage tier process + OSAC CLI requirements | Pending (from May 26) |

---

## Component Map

```
                              STORAGE ARCHITECTURE
 ============================================================================

  LAYER 1: ENHANCEMENT PROPOSALS (Design)
  ========================================
  EP #26 (mhrivnak)          EP #32 (akshaynadkarni)
  Tenant-specific SCs        Storage Tiers
  [MERGED]                   [MERGED]
       |                          |
       v                          v

  LAYER 2: OPERATOR (Resolution + Lifecycle)
  ===========================================
  osac-operator/internal/controller/tenant_controller.go
  +----------------------------------------------------+
  | getTenantStorageClasses()                           |
  |   - Lists SCs with osac.openshift.io/tenant label  |
  |   - Groups by osac.openshift.io/storage-tier       |
  |   - Per-tier fallback: tenant-specific -> Default   |
  |   - Populates status.storageClasses[]               |
  +----------------------------------------------------+
  | CI Controller (PR #229, MERGED)                     |
  |   - Reads tenant.status.storageClasses              |
  |   - Injects into AAP extra_vars as                  |
  |     ansible_eda.event.tenant_storage_classes        |
  +----------------------------------------------------+
  | handleStorageProvisioning()  [PR #210, OPEN]        |
  |   - Triggers AAP osac-create-org when no SC found  |
  |   - Polls job status, transitions Tenant to Ready   |
  +----------------------------------------------------+
  | handleStorageDeprovisioning() [PR #210, OPEN]       |
  |   - Triggers AAP osac-delete-org on Tenant delete  |
  |   - Waits for cleanup before removing finalizer     |
  +----------------------------------------------------+
  | StorageClass Watch                                  |
  |   - SC create/delete -> re-reconciles Tenant       |
  |   - Default SC changes -> reconciles ALL Tenants   |
  +----------------------------------------------------+
       |                                    |
       v                                    v

  LAYER 3: AAP ROLES (Provisioning + Selection)
  ==============================================

  PROVISIONING (creates SCs):

  Model A: tenant_storage_provision     Model B: storage_provider
  [PR #266, OPEN]                       [PR #296, OPEN - reworking]
  +----------------------------------+  +----------------------------------+
  | tasks/create.yaml                |  | Dispatcher role                  |
  |   1. Find reference SC          |  |   validates provider allowlist   |
  |   2. configure_backend.yaml     |  |   dispatches to template role:   |
  |      (CSP extension point)      |  |   osac.templates.{{ provider }}  |
  |   3. Create labeled SC per tier |  |   _storage                      |
  |                                  |  |                                  |
  | tasks/delete.yaml               |  | vast_storage template role:      |
  |   1. cleanup_backend.yaml       |  |   tenant_setup                   |
  |      (CSP extension point)      |  |   ensure_storage_class           |
  |   2. Delete all labeled SCs     |  |   teardown                       |
  +----------------------------------+  +----------------------------------+

  SELECTION (chooses SC for a VM):

  osac.service.tenant_storage_class [PR #291, MERGED]
  +----------------------------------+
  | Receives resolved storageClasses |
  | list via extra_vars (from CI     |
  | controller, PR #229)             |
  | Matches requested tier -> SC name|
  | Sets tenant_storage_class_name   |
  +----------------------------------+
       |
       v

  LAYER 4: TEMPLATES (use selected SC)
  =====================================
  ocp_virt_vm/tasks/create_resources.yaml
  +-------------------------------+
  | 1. include_role:              |
  |    tenant_storage_class       |
  |    tier: "default"            |
  | 2. Create DataVolume with     |
  |    resolved storageClassName  |
  | 3. Create VirtualMachine      |
  +-------------------------------+

  LAYER 5: VENDOR INTEGRATION
  ============================
  VAST Provider [PR #296, reworking]
  +---------------------------------------+
  | osac.templates.vast_storage:           |
  |   tenant_setup:                       |
  |     Create VAST Tenant, VIP Pool,     |
  |     View, View Policy, API Token,     |
  |     K8s Secret                        |
  |   ensure_storage_class:               |
  |     Install CSI operator (OLM),       |
  |     Create StorageClass with VAST     |
  |     CSI parameters                    |
  |   teardown:                           |
  |     Reverse of setup                  |
  +---------------------------------------+

  FUTURE: OSAC-882 (Storage Tier Management APIs)
  ================================================
  +-----------------------------------------------+
  | Admin API → StorageTier (DB) → Controller     |
  |   → AAP (reuses #296 roles) → StorageClass    |
  | Tenant API → list tiers, select per disk      |
  | Replaces env var / Ansible var configuration   |
  +-----------------------------------------------+
```

---

## Current State Summary

### What's Merged (in upstream main)

| Component | What | PR/Source | Date |
|-----------|------|-----------|------|
| **Tenant CRD** | `ResolvedStorageClass` type with `name` + `tier` fields | PR #204 | 2026-04-28 |
| **Tenant CRD** | `status.storageClasses` list (map by tier) | PR #204 | 2026-04-28 |
| **Tenant CRD** | `status.storageClass` (singular) removed | PR #269 | 2026-06-01 |
| **Tenant Controller** | `getTenantStorageClasses()` - per-tier resolution with tenant->Default fallback | PR #199 | 2026-05-04 |
| **Tenant Controller** | StorageClass watch - re-reconciles on SC label changes | PR #199 | 2026-05-04 |
| **Tenant Controller** | `StorageClassReady` condition with per-tier detail | PR #199 | 2026-05-04 |
| **CI Controller** | Injects `tenant.status.storageClasses` into AAP extra_vars as `ansible_eda.event.tenant_storage_classes` | PR #229 | 2026-05-16 |
| **AAP** | `tenant_storage_class` role - tier-aware selection from injected list, requires `storage_tier` parameter | PR #291 | 2026-05-13 |
| **AAP** | `ocp_virt_vm` template - calls `tenant_storage_class` with tier `default` | PR #291 | 2026-05-13 |
| **AAP** | VAST vendor integration — `storage_provider` dispatcher + `vast_storage` template role | PR #296 | 2026-05-27 |
| **Tenant Controller** | AAP-driven provisioning/deprovisioning lifecycle (finalizer, job polling, crash recovery) | PR #210 | 2026-05-28 |
| **Labels** | `osac.openshift.io/tenant` (EP #26) | Merged | — |
| **Labels** | `osac.openshift.io/storage-tier` (EP #32) | Merged | — |

**Note on PR #229/#291 dependency:** PR #291 (AAP) was merged first (May 13) without the corresponding operator PR #229. This temporarily broke ComputeInstance creation — the playbook expects `tenant_storage_classes` in extra_vars but the operator wasn't sending it. Akshay reproduced the failure, overrode the failing e2e-vmaas prow job, and merged PR #229 on May 16 to fix the breakage.

### What's in PR

| Component | What | PR | Status | Notes |
|-----------|------|-----|--------|-------|
| **Tenant CRD** | Remove deprecated `status.storageClass` field | osac-operator #269 | Open, CI passing | OSAC-179. All consumers migrated. |

### What's Not Started

| Area | Gap | Ticket | Notes |
|------|-----|--------|-------|
| **Storage Tier APIs** | No user-facing API for tier discovery/selection | OSAC-882 (New, Akshay) | Admin CRUD + tenant APIs. Sub-epic OSAC-1110 for v0.1 |
| **CaaS storage** | No storage provisioning inside child clusters | OSAC-887 (New) | **Elevated to v0.1 priority (June 1).** Roy flagged split CSI won't work. |
| **Dedicated VMaaS** | Same gap as CaaS — remote cluster, not hub | — | Same solution would cover both |
| **Quota enforcement** | Backend-native, but no OSAC integration yet | — | Depends on OSAC-882 and quota EP |
| **Multi-hub** | SC provisioning across multiple hub clusters | OSAC-753 (To Do) | — |
| **Dedicated tenant SA** | Tenant operations use shared `osac-sa` | OSAC-499 (To Do) | — |
| **Multi-cluster client** | `tenantStorageClassExists` uses local client | OSAC-498 (To Do) | — |

---

## VMaaS Storage Flow

### End-to-End: Organization Creation to VM Disk Creation

```
Phase 1: Tenant/Organization Creation
======================================

User/API                 Fulfillment Service          Hub Cluster
   |                           |                          |
   |-- Create Organization --> |                          |
   |                           |-- Create Tenant CR ----->|
   |                           |                          |
   |                           |     Tenant Controller    |
   |                           |     detects new Tenant   |
   |                           |           |              |
   |                           |     [No SC found]        |
   |                           |           |              |
   |                           |     Triggers AAP         |
   |                           |     osac-create-org      |
   |                           |           |              |
   |                           |           v              |
   |                           |     Provisioning role:   |
   |                           |       1. configure_      |
   |                           |          backend (hook)  |
   |                           |       2. Create SC:      |
   |                           |          <tenant>-default|
   |                           |          with labels     |
   |                           |           |              |
   |                           |     SC Watch triggers    |
   |                           |     re-reconcile         |
   |                           |           |              |
   |                           |     getTenantStorage     |
   |                           |     Classes() resolves   |
   |                           |     -> status.storage    |
   |                           |        Classes populated |
   |                           |           |              |
   |                           |     Phase = Ready        |


Phase 2: ComputeInstance Creation
=================================

User/API                 Fulfillment Service          Hub Cluster
   |                           |                          |
   |-- Create VM ------------>|                          |
   |                           |-- Create CI CR --------->|
   |                           |                          |
   |                           |     CI Controller:       |
   |                           |       1. Get Tenant CR   |
   |                           |       2. Check Phase=    |
   |                           |          Ready           |
   |                           |       3. Read tenant.    |
   |                           |          status.storage  |
   |                           |          Classes         |
   |                           |       4. Inject as       |
   |                           |          extra_vars      |
   |                           |       5. Trigger AAP     |
   |                           |          osac-create-    |
   |                           |          compute-instance|
   |                           |           |              |
   |                           |     Playbook:            |
   |                           |       1. tenant_storage_ |
   |                           |          class role:     |
   |                           |          tier="default"  |
   |                           |          -> resolves SC  |
   |                           |       2. ocp_virt_vm     |
   |                           |          template:       |
   |                           |          Create DV with  |
   |                           |          resolved SC     |
   |                           |       3. Create VM       |
```

### Key Data Flow: How Storage Tier Reaches the DataVolume

1. **Tenant Controller** resolves `getTenantStorageClasses()` → stores in `tenant.status.storageClasses[]`
2. **CI Controller** (PR #229, merged) reads the Tenant CR, extracts `storageClasses` list, injects into AAP extra_vars as `ansible_eda.event.tenant_storage_classes`
3. **Playbook** sets `tenant_storage_class_storage_classes` from the injected list
4. **`tenant_storage_class` role** (PR #291, merged) receives the list + `storage_tier` parameter (e.g., `"default"`)
5. **Role** filters the list by tier, outputs `tenant_storage_class_name`
6. **`ocp_virt_vm` template** uses `tenant_storage_class_name` as `storageClassName` in DataVolume spec

---

## CaaS Storage Flow

### Current State: No CaaS-Specific Storage

The CaaS cluster provisioning template (`ocp_4_17_small`) has **zero storage-related code**. The HyperShift HostedCluster template creates HostedCluster CR, NodePool CRs, and Secrets — no storage configuration for either the hub-side control plane or the child cluster.

### Why VMaaS Storage Doesn't Apply to CaaS

```
VMaaS:                                    CaaS:

Hub Cluster                               Hub Cluster        Tenant Cluster
┌─────────────────┐                      ┌──────────────┐   ┌──────────────┐
│ Tenant CR       │                      │ Tenant CR    │   │ Workloads    │
│ StorageClasses  │                      │ HostedCluster│   │ PVCs         │
│ DataVolumes     │                      │              │   │ StorageClass?│
│ VMs (KubeVirt)  │                      │ HCP control  │   │ CSI driver?  │
│                 │                      │ plane (etcd) │   │              │
│ Everything HERE │                      └──────────────┘   └──────────────┘
└─────────────────┘
                                          SC on hub is        SC needed HERE
Storage: on hub ✓                         useless for         but who creates
Our PRs work                              tenant workloads    it?
```

**Dedicated VMaaS clusters have the same gap.** VMs run on a dedicated cluster (not the hub), so hub SCs are equally useless. Any solution for CaaS solves dedicated VMaaS too.

### CaaS Storage Options (from meeting discussion)

| Option | Description | Meeting Status |
|--------|-------------|----------------|
| Post-install hook in cluster template | Deploy CSI + create SCs during post_install.yaml | Not discussed in detail |
| Will's provisioning_target: caas | storage_provider role targets child cluster | Stub exists in PR #296, unimplemented |
| Avishay's split CSI | OSAC controller on hub, vendor node plugin on child | **Rejected** (custom CSI proxy rejected) |
| Leave to tenant | Tenant installs own CSI | Poor UX, can't enforce quotas |
| ACM Policy-driven | Push SC definitions via RHACM policies | Not discussed |

---

## Storage Isolation Model

### Isolation Spectrum

```
Level 0              Level 1              Level 2              Level 3
NO ISOLATION         LABEL ROUTING        BACKEND ISOLATION    PHYSICAL ISOLATION

All tenants →        Each tenant has      Each tenant has       Each tenant has
one SC, one pool     own SC, but same     own SC pointing to    own storage array
                     backend + creds      isolated backend

What OSAC had        What SC cloning      What VAST PR #296     Extreme case,
originally           gives you            gives you             not planned
```

### What Each Level Protects Against

| Threat | L0 | L1 | L2 | L3 |
|--------|----|----|----|----|
| Tenant A's VM uses tenant B's SC | No | **Yes** | **Yes** | **Yes** |
| Tenant A reads tenant B's data | No | No | **Yes** | **Yes** |
| Tenant A exhausts storage, starves B | No | No | **Yes** | **Yes** |
| Tenant A's credentials leak, expose B | No | No | **Yes** | **Yes** |

### Key Insight

**Cloning is the framework, not the isolation mechanism.** Real isolation comes from the backend hooks (configure_backend / vendor template roles). OSAC routing (controller-enforced via fulfillment API) prevents cross-tenant SC usage. The CSP configures actual backend separation.

Per meeting decision: **backend storage is the source of truth for isolation and quotas.** OSAC orchestrates the setup but doesn't independently enforce.

---

## Vendor Integration Model

### VAST as First Implementation (PR #296)

PR #296 implements the `osac.templates.vast_storage` template role with the `osac.service.storage_provider` dispatcher.

**VAST Onboarding Flow:**
```
storage_provider role dispatches to vast_storage:
  tenant_setup:
    1. Authenticate to VAST Management Service (REST API)
    2. Create VAST Tenant with encryption keys + QoS
    3. Create VIP Pool (per-tenant or global, source-based)
    4. Create View + View Policy
    5. Generate per-tenant API Token
    6. Create K8s Secret with VAST credentials
  ensure_storage_class:
    1. Install VAST CSI operator via OLM (if not present)
    2. Create StorageClass with VAST CSI parameters
  teardown:
    Reverse of setup (live queries for current state)
```

**VAST Test Environment (while Will is on PTO May 15-28):**
- VMS Portal: https://10.46.83.15 (admin/123456)
- SSH: 10.46.83.15 (centos/centos)
- VIP Pool NIC: 10.46.83.77
- Mock VMS server for local testing: `tests/integration/mock_vms_server.py`

### VAST Integration Status (as of May 27 — MERGED)

PR #296 **merged** 2026-05-27 by Akshay (via openshift-merge-bot). Approved by akshaynadkarni + wgordon17 (self). `ci/prow/temp` overridden by Akshay to proceed.

**Working (in main):**
- VAST VMS provisioning (tenant, VIP pool, view, view policy, API token)
- PVCs bind correctly
- Full setup and teardown lifecycle works cleanly
- `storage_provider` dispatcher role with extensible pattern for future vendors

**Known open issues (follow-up tickets created):**
- OSAC-1043: Add explicit provider allowlist to storage_provider dispatcher
- OSAC-1044: Surface teardown failures instead of silent ignore_errors (Alona assigned)
- OSAC-1042: Harden pod security context across AAP instance group templates

**Pre-merge known blockers (still relevant):**
- **Per-tenant credentials are cluster-wide** — not scoped per tenant. Suspected VAST CSI driver bug. Writeup: https://docs.google.com/document/d/1MF-1xoxGWJ6tamlvLos_0fwhW3U55tcgB2R6ZroAjcY/edit
- **Volume mounting fails** — network proxy issue (local SNO). Waiting for VAST on Cloud (VoC) access.
- OSAC-885: Follow up on network isolation requirements for VAST storage (Will assigned)
- OSAC-951: Generalize vast-csi plugin to remove OSAC-specific coupling (Alona assigned)

**Demo:** https://drive.google.com/file/d/1llqB8-PQaiLJ5RMEh_o_5asP3TWK48xP/view

### VIP Pool Models

1. **Per-tenant VIP Pool:** Destination IP defines tenant. Each tenant gets an IP range. Network isolation enforces access. Production model for OSAC.
2. **Global VIP Pool (source-based):** Source IP defines tenant. Will is using this due to test environment limitations.

### Extensibility for Other Vendors

Same template role pattern for any vendor:

| Vendor | Template role | Backend setup |
|--------|--------------|---------------|
| VAST | `vast_storage` (PR #296) | Tenant, VIP Pool, View, API Token |
| Ceph | `ceph_storage` (future) | Pool, CRUSH rule, user/key |
| NetApp | `netapp_storage` (future) | vserver, export policy |
| No vendor (default) | N/A | SC cloning from reference (PR #266 default path) |

---

## Competing Models and Resolution

### Three Models Were Proposed

```
Model A: Pre-Provisioning (PRs #210/#266)
  Trigger: Tenant CR created → Operator → AAP → SC
  Extension: configure_backend.yaml task file override
  Self-healing: Yes (SC watch)
  CaaS: No (hub only)

Model B: JIT (PR #296 original)
  Trigger: VM requested → Playbook pre-task → storage_provider → SC
  Extension: osac.templates.{{ provider }}_storage roles
  Self-healing: No
  CaaS: Stub exists

Model C: OSAC-882 (future)
  Trigger: Admin creates StorageTier via API → Controller → AAP → SC
  Extension: Reuses #296 AAP roles
  Self-healing: Yes (controller watches)
  CaaS: Possible
```

### Meeting Resolution

The team chose **onboarding-time provisioning** (closer to Model A's trigger) **with template-based configuration** (Model B's extension pattern). Will is reworking PR #296 to align:

- **Trigger:** At tenant onboarding (not JIT per VM)
- **Extension model:** Template role pattern from #296 (`osac.templates.{{ provider }}_storage`)
- **Operator lifecycle:** Patterns from #210 (watch, self-heal, finalizer) to move to StorageTier controller (OSAC-882)
- **AAP roles:** From #296 (storage_provider dispatcher, vast_storage template)

### Akshay's PR Classification (from group chat May 14)

```
#266: tenant onboarding + SC cloning (Zoltan)
#296: JIT + SC templating from tier definitions (Will)
#295: JIT + SC cloning via #266's hooks (Will, built on Zoltan's branch)

Meeting decision: tenant onboarding + SC templating
→ #296 adjusted to trigger at onboarding time instead of JIT
→ Effectively: #296's implementation with #266's trigger timing
```

The key implementation difference: #266 clones an existing reference SC and relabels it. #296 templates from tier definitions with provider-specific roles — each provider role (vast_storage, etc.) controls exactly what SC parameters are used. The team chose templating.

Will on self-healing: "keep it also in the JIT path, so that if the SC ever gets deleted or missing, it just automatically gets recreated." This provides AAP-level self-healing as a complement to the operator SC watch.

### What Carries Forward from Each PR

| Source | What survives | Where it goes |
|--------|--------------|---------------|
| PR #210 (operator) | Watch, self-heal, crash recovery, finalizer patterns | Future StorageTier controller (OSAC-882) |
| PR #266 (AAP) | configure_backend/cleanup_backend hook concept | Superseded by template role pattern from #296 |
| PR #296 (AAP) | storage_provider dispatcher, vast_storage template role, onboarding-time trigger | Direct reuse in OSAC-882 architecture |
| PR #229 (operator, merged) | StorageClasses injection into extra_vars | Already in upstream |
| PR #291 (AAP, merged) | Tier-aware tenant_storage_class role | Already in upstream |

### PR Approvals

- **PR #210 (operator):** Approved by Akshay (May 14). Reviewed by tzvatot.
- **PR #266 (AAP):** Approved by Akshay (May 14). Reviewed by adriengentil.
- Both PRs have `lgtm` but may need rebase and re-evaluation given the direction toward #296's templating approach.

---

## Architectural Direction Debate

### Avishay vs Michael (May 14 Slack Discussion)

A fundamental debate about OSAC's long-term storage architecture.

**Avishay's Position: OSAC as Storage Control Plane**
- Build custom OSAC CSI Controller Plugin on management cluster
- Vendor CSI Node Plugins on tenant clusters (mount only)
- Central enforcement: RBAC, quotas, billing at single PEP
- Prevent information leakage (no backend URLs/creds in tenant clusters)
- "OSAC should be the control plane, not a billing/metrics collector for other control planes"
- Data flow: Always user → OSAC → storage (OSAC in the path)

**Michael's Position: Leverage Vendor Control Planes**
- Use vendor-native CSI drivers everywhere
- Tenants have root on CaaS nodes — can't fully hide backend
- Storage vendors are eager to implement controls and provide metrics
- Don't rebuild what vendors already offer
- "Embrace each storage vendor, follow their guidance"
- Simpler, less engineering effort

**Resolution:**
- **Custom CSI proxy explicitly rejected** by the team (meeting decision #3)
- **Vendor-native approach wins for near-term and likely long-term**
- Avishay conceded: "fine for short-term but :shrug:"
- Key remaining concern: CaaS flow becomes user → vendor CSI → storage → OSAC reads metrics (reactive, not proactive)

---

## Jira Ticket Landscape

### Epic: OSAC-56 — VMaaS Tenant Storage Setup (Critical, In Progress)
**Assignee:** Zoltan Szabo

| Key | Summary | Status |
|-----|---------|--------|
| OSAC-278 | Ansible: Organization Storage Provisioning Playbook Framework | **Closed** |
| OSAC-394 | Organization Controller: Trigger Storage Provisioning on Lifecycle Events | **Closed** |
| OSAC-326 | Demo: Storage Story | To Do |
| OSAC-737 | VM Templates: Use Storage Tier Selection | **Closed** |
| OSAC-738 | Documentation: Storage Provider Integration Guide | To Do |
| OSAC-498 | Tenant controller: use target cluster client in tenantStorageClassExists | To Do |
| OSAC-499 | Tenant operations: dedicated ServiceAccount with scoped RBAC | To Do |
| OSAC-1143 | Tenant controller: change readiness gate from StorageClass to hub Secret | New |
| OSAC-1144 | Tenant controller: trigger osac-ensure-tenant-storage for VMaaS Phase 2 | New |
| OSAC-1145 | Split AAP storage playbooks into 4 lifecycle actions | New |
| OSAC-1146 | Trigger osac-cleanup-tenant-storage on resource deletion (tenant stays) | New |

### Epic: OSAC-43 — VAST for VMaaS (Critical, In Progress)
**Assignee:** Will Gordon
**Summary renamed** from "VAST Data Tenant Storage Onboarding" (May 29)

| Key | Summary | Status |
|-----|---------|--------|
| OSAC-883 | Initial AAP MVP for VAST tenant storage provisioning | **Closed** |
| OSAC-884 | Record VAST storage MVP demo | **Closed** |
| OSAC-885 | Follow up on network isolation requirements for VAST storage | New |
| OSAC-886 | Expand VIP pool configuration options for VAST storage | New |
| OSAC-887 | CaaS integration for VAST tenant storage | New |
| OSAC-750 | Write enhancement proposal for VAST integration | To Do |
| OSAC-751 | Create Ansible collection for VAST REST API | To Do |
| OSAC-752 | Create orchestration roles for VAST onboarding | To Do |
| OSAC-753 | Support VAST SC provisioning across multiple hubs | To Do |
| OSAC-754 | E2E tests for VAST tenant storage onboarding | To Do |
| OSAC-755 | Integrate VAST SCs with tenant label discovery | To Do |
| OSAC-951 | Generalize vast-csi plugin to remove OSAC-specific coupling | New (Alona Paz) |
| OSAC-1042 | Harden pod security context across all AAP instance group templates | New (Unassigned) |
| OSAC-1043 | Add explicit provider allowlist to storage_provider dispatcher | New (Unassigned) |
| OSAC-1044 | Surface teardown failures in storage_provider instead of silent ignore_errors | New (Alona Paz) |

### Feature Epics

| Key | Summary | Status | Assignee | Notes |
|-----|---------|--------|----------|-------|
| OSAC-917 | Storage Backend Framework | New | WG-Storage | Feature-level. EP PR #49 submitted by Avishay (June 3) |
| OSAC-1110 | Storage Tier Definition & Private API | New | Avishay + Roy | Epic under OSAC-882 for v0.1. Must-have. EP + CRUD API, no Tier CR for v0.1 |
| OSAC-1111 | Storage Backend Definition & Private API | New | Avishay + Roy | Epic under OSAC-917. EP done (PR #49), CRUD API ok to defer post v0.1 |
| OSAC-882 | Tiered Storage Management | New | Akshay Nadkarni | Feature-level |
| OSAC-1001 | Tenant Storage Lifecycle | New | WG-Storage | Feature-level. Owns OSAC-23, OSAC-56 |
| OSAC-23 | Tier-Based Resource Provisioning | In Progress | Akshay Nadkarni | Epic under OSAC-1001 |
| OSAC-1191 | CaaS — Provision and Manage OpenShift Clusters | New | WG-CaaS | Feature-level. Owns OSAC-1123, OSAC-1122 |
| OSAC-1123 | CaaS Tenant Storage Setup | New | Akshay Nadkarni | Epic under OSAC-1191. Depends on Rework Tenant Storage Onboarding |
| OSAC-48 | Independent Storage Volumes | New | Unassigned | Full volume lifecycle API |

### Dependencies

```
OSAC-56 (Tenant Storage and Tiers)
  ├── depends on → OSAC-66 (Organizations)
  ├── depended on by → OSAC-43 (VAST integration)
  └── feeds into → OSAC-882 (Storage Tier APIs)

OSAC-882 (Storage Tier APIs)
  ├── reuses → PR #296 AAP code
  └── feeds into → OSAC-48 (Independent Volumes)
```

---

## Enhancement Proposals

### EP #26: Tenant-Specific StorageClasses (mhrivnak) — MERGED
- Label `osac.openshift.io/tenant` identifies tenant ownership
- `Default` (capitalized) sentinel for shared StorageClasses
- Fallback: tenant-specific → shared Default → error
- CSP Admin responsible for creating SCs and configuring backend

### EP #32: Tenant Storage Tiers (akshaynadkarni) — MERGED
- Second label `osac.openshift.io/storage-tier` (REQUIRED)
- `status.storageClasses` list replaces singular field
- Per-tier resolution with independent fallback
- Tier names freeform; `default` is convention for OSAC templates
- Template-driven tier selection (templates hardcode tier, not users)
- Tenant controller is single source of truth

### EP #49: Storage Backend Import (avishay) — IN REVIEW
- Submitted June 3 for OSAC-917
- StorageBackend registration via private API
- PR: https://github.com/osac-project/enhancement-proposals/pull/49

### Missing EPs
- **VAST integration** — OSAC-750 (To Do, no EP exists)
- **Storage Tier Definition** — OSAC-1110 (Avishay + Roy assigned, EP planned)
- **Split CSI architecture** — rejected at meeting level, no EP needed
- **CaaS storage** — OSAC-1123 (work items populated in Google Doc, no formal EP)

---

## PR Status

### Merged (in upstream main)

| PR | Repo | Title | Merged |
|----|------|-------|--------|
| #204 | osac-operator | Multi-tier CRD types | 2026-04-28 |
| #199 | osac-operator | Per-tier resolution logic | 2026-05-04 |
| #291 | osac-aap | Tier-aware `tenant_storage_class` role | 2026-05-13 |
| #229 | osac-operator | Inject `storageClasses` into AAP extra_vars | 2026-05-16 |
| #296 | osac-aap | VAST provider + `storage_provider` role | 2026-05-27 |
| #210 | osac-operator | Tenant storage provisioning controller | 2026-05-28 |
| #269 | osac-operator | OSAC-179: remove deprecated status.storageClass | 2026-06-03 |

### Closed (superseded)

| PR | Repo | Title | Closed | Reason |
|----|------|-------|--------|--------|
| #266 | osac-aap | Provisioning framework + playbooks | 2026-05-27 | Superseded by merged PR #296 |

### Open

| PR | Repo | Title | Status | Last Updated |
|----|------|-------|--------|--------------|
| (none) | | | | |

### Phase A Complete (May 28)
- All three original storage PRs resolved: #210 merged, #296 merged, #266 closed
- OSAC-394 and OSAC-278 closed
- Stable baseline established for Phase B refactoring

---

## Open Questions and Decision Points

### Resolved (May 14 Meeting)

| Question | Decision |
|----------|----------|
| Pre-provisioning vs JIT? | **Onboarding-time** (triggered by quota allocation) |
| Custom CSI vs vendor-native? | **Vendor-native** (custom CSI rejected) |
| Who enforces quotas? | **Backend storage** (vendor-native enforcement) |
| How to meter usage? | **Vendor Prometheus endpoints** |
| Template-based or direct API config? | **Template-based** (template role pattern) |

### Still Open

| # | Question | Context |
|---|----------|---------|
| 1 | ~~How to harmonize PRs #266 and #296?~~ | **RESOLVED (May 27-28):** PR #296 merged, PR #266 closed (superseded), PR #210 merged. Template-based approach from #296 won. |
| 2 | **CaaS storage architecture?** | **Elevated to v0.1 priority (June 1).** Akshay announced CaaS with VAST now prioritized over VMaaS. Roy Golan flagged split CSI approach won't work (CSI identifier mismatch). |
| 3 | **Storage tier CRD design?** | OSAC-882 assigned to Akshay. New sub-ticket OSAC-1110 (Storage Tier Definition & Private API) created. |
| 4 | ~~Who writes the storage EP?~~ | **RESOLVED:** Akshay is leading feature/epic planning in Google Doc. Jira tickets being created from doc tabs. |
| 5 | **Tenant visibility of storage providers?** | CSP admin decides what to expose — could be generic tiers or vendor labels |
| 6 | **Network connectivity for CaaS storage?** | Even with backend configured, child cluster nodes need network path to storage |
| 7 | **Billing model for storage?** | Pay-per-tier vs pay-as-you-go vs included. Product decision, not engineering. |
| 8 | **X tiers × Y tenants scalability?** | Michael raised: "if we have X tiers and Y tenants, that could be a ton of total StorageClasses." May push some optimization toward lazy creation despite onboarding-time decision. Akshay acknowledged: "we will have to identify what part of the storage configuration can wait until the very end." |
| 9 | **ComputeInstance has no storageTier field?** | Will flagged: no mechanism for users to select storage tier per VM. Currently template-driven only (EP #32). Needs operator PR to add tier field to ComputeInstance or DiskSpec. |
| 10 | **Tier-to-Tenant mapping via Quota?** | Will proposed: no assigned quota = tier not available to tenant. Connects quota feature directly to tier availability. |
| 11 | **Avishay's CaaS CSI proxy EP (PR #43)?** | Despite meeting rejecting custom CSI, Avishay wrote formal EP for CaaS-specific proxy CSI driver. Scoped to CaaS only. May 19: Avishay assigned to PoC the approach. May 26: CaaS installs SCs post-cluster (separate from onboarding), which aligns with proxy model. PoC in progress. |

---

## Meeting History

### May 13, 2026 — Full Team Weekly
- Zoltan presented storage provisioning demo
- Lars raised isolation concern (cloning ≠ isolation)
- Lars raised CaaS gap (hub SCs useless for child clusters)
- Will shared PR #296 as JIT alternative
- Action: schedule dedicated storage meeting

### May 14, 2026 — Storage Provisioning: Unified Model (facilitated by Zoltan)
- Akshay presented 8 questions and Miro diagram
- Team aligned on 6 decisions (see Key Decisions section)
- Custom CSI proxy rejected
- Vendor-native approach confirmed
- Onboarding-time provisioning chosen over JIT
- Action: recurring meeting, EP review, PR harmonization

### May 14, 2026 — Storage: PR#296 + VAST Setup (Akshay + Will)
- Will walked through PR #296 architecture
- Agreed to proceed with current approach for demo
- Decided to elevate tiers to CRDs long-term
- Will handed over VAST test environment before PTO
- Action: Akshay to coordinate merging PR #210, sync with Zoltan

### May 14, 2026 — Slack Discussion (Avishay vs Michael)
- Avishay proposed split CSI model (OSAC controller on hub, vendor node on child)
- Michael challenged: tenant has root, can't hide backend, vendors are eager
- Avishay conceded short-term but argued for central control long-term
- Resolution: vendor-native wins, custom CSI not pursued

### May 15, 2026 — Slack: Oved's check-in + Tier discussion
- Oved asked for storage meeting update. Akshay confirmed decisions and listed open topics.
- Will flagged: ComputeInstance has no storageTier spec — no way for users to select tier per VM.
- Akshay mapped the current flow correctly (template→controller→AAP) and confirmed Tier needs to be first-class.
- Ygal: Tier has two faces — user-facing (name/description) and internal (provider/protocol/QoS/SC params).
- Will: Tier-to-Tenant mapping via Quota — no assigned quota = no available tier.
- Will: If CSP adds new tier after onboarding, needs reconciliation mechanism for existing tenants.
- Akshay: Tier is provider-defined resource. Tier + Tenant together determine which SC gets created.
- Michael answered Akshay's 9 questions in detail. Key: X×Y scalability concern, networking is huge topic, per-tenant storage pools for isolation.
- Akshay found OSAC-882 while organizing storage tickets — confirmed alignment with Avishay's thinking.

### May 17, 2026 — Slack: Avishay posts CaaS storage proxy CSI EP
- Avishay published EP PR #43 formalizing the split CSI proposal for CaaS specifically (VMaaS out of scope).
- Framed as "formalizing my position" and "not looking for in-depth reviews yet — align on direction first."
- Tagged full team (Michael, Will, Akshay, Ygal, Lars, etc.)

### May 18, 2026 — Slack: Will's VAST PR #296 ready for review
- Will announced PR #296 ready with demo recording.
- Two blockers: per-tenant credentials are cluster-wide (suspected CSI bug), volume mounting fails (network issue).
- PVCs bind and lifecycle works cleanly despite blockers.

### May 14, 2026 — Group Chat: Will + Akshay + Zoltan
- Will shared VAST test environment credentials (VMS portal, SSH, VIP pool NIC)
- Will adjusting PR #296 to provision at onboarding time (was JIT)
- Akshay classified PRs: #266 = onboarding+cloning, #296 = JIT+templating, #295 = JIT+cloning
- Akshay confirmed: "we decided to use the templating i.e. what #296 is doing"
- Will: both VIP Pool options need to be supported, CSP's network admin decides
- Will: #296 can self-heal by keeping ensure_storage_class in JIT path too
- Akshay scheduled Friday call with Will (recorded for Zoltan who left early)
- Will shared VAST VM instructions PDF

### May 15, 2026 — DM: Akshay + Zoltan
- Akshay approved both PRs #210 and #266
- Monday 10:30 AM ET call scheduled to connect on WIP
- Monday 3:30 PM CEST call with Avishay on open storage epics
- Zoltan confirmed PR #291 is NOT backward compatible (requires #229)
- Akshay later overrode failing e2e and merged PR #229 to fix the breakage

### May 18, 2026 — Discuss: Storage + Epics (Akshay-led)
- Block storage confirmed as primary scope; generic tier objects abstract backend protocols
- Infrastructure admin vs cloud admin roles clarified for backend setup vs tier management
- Reaffirmed: install SCs during tenant onboarding, not lazy/JIT (avoids premature optimization)
- Preserve existing SCs when integrating new configurations
- Volume management acknowledged as out of scope for the immediate roadmap
- CaaS requires pre-installed SCs for cluster deployment (June release requirement)
- Action (Akshay): present volumes-as-independent-service at next storage meeting

### May 18, 2026 — Zoltan / Akshay 1:1
- Identified 3 key storage areas for epic clarity: onboarding, SC creation, lifecycle
- Agreed to merge existing open PRs promptly to establish stable baseline
- Akshay to assign EDA removal/refactoring ticket to Zoltan as near-term task
- Action: Akshay to coordinate Alona on task assignment

### May 19, 2026 — OSAC Storage (for VMaaS and CaaS)
- Avishay presented CSI proxy model; group explored split OSAC-controller-on-hub / vendor-node-on-child approach
- Defined 3 storage lifecycle phases: onboarding, SC creation, resource creation
- Agreed: single pool per tenant for initial phase; templating for SCs
- etcd: 3 instances with dedicated volumes required for cluster reliability (Lars)
- June delivery target: mandatory initial storage config required for cluster provisioning
- Action (Avishay): PoC the CSI proxy approach for volume provisioning
- Action (Lars): evaluate etcd storage requirements — is one SC sufficient?
- Action (Akshay): update OSAC-56 to incorporate SC templating + multi-tenancy logic
- Action (group): evaluate vendor observability before building custom global views

### May 26, 2026 — OSAC Storage (for VMaaS and CaaS)
- Outlined 3 storage phases including onboarding, tier definition, and provisioning strategy
- **VMaaS decision**: create tenant SCs + install CSI drivers at tenant onboarding time
- **CaaS decision**: create tenant SCs + install CSI drivers post-cluster installation (not at onboarding)
- Discussed long-term need for abstraction layer over vendor-specific drivers
- Reviewed storage roadmap for June milestones
- Action (Akshay): connect with Avishay to finalize storage tier creation process + OSAC CLI requirements
- Action (Akshay): rework storage epic to correctly translate to defined line items + onboarding flow
- Action (group): review shared Google Sheet and provide offline comments
- Action (Akshay): evaluate OpenStack service integration feasibility
- Action (group): refine tier model for multi-backend support and vendor transitions

### May 27, 2026 — DM: Akshay → Zoltan
- Akshay approved and merged Will's PR #296 (VAST provider)
- Key decision from storage meeting: VMaaS SCs + CSI at tenant onboarding; CaaS SCs + CSI post-cluster installation
- Akshay organizing epic structure, expects clearer hierarchy in a few days

### May 28, 2026 — PR #210 Merged
- Akshay approved and merged osac-operator PR #210 (tenant storage provisioning controller)
- Adds AAP-driven provisioning/deprovisioning lifecycle to Tenant controller
- OSAC-394 closed

### May 27, 2026 — PR #266 Closed (superseded)
- Zoltan closed osac-aap PR #266 with comment explaining it's superseded by merged PR #296
- OSAC-278 closed

### May 29, 2026 — Akshay: Storage feature/epic restructuring
- Akshay updated OSAC-56 summary: "Tenant Storage Provisioning using Tiers" → "VMaaS Tenant Storage Setup"
- Agreed to split teardown into two phases (reverse of creation): resource deletion first, then tenant deletion
- New Phase B tickets created under OSAC-56: OSAC-1143, OSAC-1144, OSAC-1145, OSAC-1146

### May 29, 2026 — Akshay: Feature+Epic Planning Update (wg-osac-storage)
- Posted comprehensive storage planning update in wg-osac-storage channel
- Google Doc restructured with Feature+Epic Planning, Docs, Architecture Diagram, Release Roadmap, Planning Status tabs
- v0.1 scope: VAST E2E for VMaaS (and maybe CaaS), StorageBackend + StorageTier CRs with private APIs, two-phase tenant provisioning, template-level tier selection
- Jira tickets being captured from doc tabs (purple dots = captured)
- New epic: OSAC-1110 (Storage Tier Definition & Private API) under OSAC-882, assigned to Akshay
- Feature hierarchy: features span milestones, epics scoped to single milestone

### June 1, 2026 — Akshay: v0.1 scope change (wg-osac-storage)
- **CaaS with VAST now prioritized over VMaaS with VAST** for v0.1
- Milestones updated in Jira
- To be discussed at June 3 storage meeting

### June 1, 2026 — Roy Golan: Split CSI won't work
- Roy told Avishay that the split CSI approach (OSAC controller on tenant, VAST node plugin) won't work
- CSI identifier mismatch: PVC says `csi.osac`, kubelet looks for `csi.osac` node plugin, not `csi.vast`
- Would fail at volume publish unless OSAC also implements the node part with redirection

### June 1, 2026 — PR #269 submitted (OSAC-179)
- Zoltan submitted osac-operator PR #269: remove deprecated status.storageClass field
- All CI checks passing; OSAC-179 moved to Review

### June 2, 2026 — Zoltan: CaaS Tenant Storage doc populated
- Populated the CaaS Tenant Storage tab in Akshay's planning doc (OSAC-1123)
- Covers: user stories, credential security, kubeconfig delivery, goals/non-goals/scope, dependencies, current implementation
- Shared in wg-osac-storage thread for review

### June 3, 2026 — PR #269 Merged (OSAC-179)
- Akshay approved; merge bot merged
- Deprecated `status.storageClass` (singular) field removed from Tenant CRD
- OSAC-179 closed

### June 3, 2026 — Storage WG Meeting: v0.1 Scope Decisions
- **CaaS with VAST is the primary v0.1 focus** (VMaaS is stretch)
- v0.1 milestone: end of June 2026
- Avishay posted StorageBackend EP (PR #49 on enhancement-proposals, OSAC-917)
- Roy Golan + Avishay assigned to Storage Tier Definition & Private API (OSAC-1110) and StorageBackend API (OSAC-1111)

**Agreed v0.1 scope:**
- Storage Onboarding: VAST virtual appliance, basic Tier API in fulfillment-service (stored in DB, no Tier CR for v0.1)
- Tenant Onboarding: Tenant CR creation triggers VAST backend config (VIP pool, credentials, views per tier)
- Resource Creation: cluster ready → install SCs + CSI on CaaS target cluster; tier info from fulfillment-service DB; etcd/control plane use local storage for v0.1
- Storage readiness tracked on Cluster CR

**New architectural direction: TenantStorage CR**
- Move storage-related information out of Tenant CR into a new TenantStorage CR
- Move storage logic out of tenant controller into tenant-storage controller
- Akshay + Zoltan assigned to "Rework Tenant Storage Onboarding" epic

**Work assignments (from Akshay's post-meeting breakdown):**
- Storage Tier Definition & Private API: Avishay + Roy (must-have for v0.1, EP + CRUD API, no Tier CR)
- Storage Backend Definition & Private API: Avishay + Roy (EP done, CRUD API ok to defer post v0.1)
- Rework Tenant Storage Onboarding: Akshay + Zoltan (TenantStorage CR, new controller)
- VMaaS Tenant Storage Setup: stretch for v0.1
- CaaS Tenant Storage Setup: depends on Rework Tenant Storage Onboarding
- VAST for CaaS: Will + Dylan (playbooks, QoS, VIP pools, VLAN isolation, VAST appliance upgrade/VoC)

**Open items from meeting:**
- How to upgrade VAST virtual appliance v5.3 → v5.4? (Roy/Will)
- VoC (VAST on Cloud) access and cost? (Roy/Will)
- Trigger point for cluster storage configuration during Resource Creation? (Akshay)
- Networked storage for etcd/control plane post v0.1? (Avishay)
- Will flagged QoS enforcement issue with VAST for CaaS (thread in wg-osac-storage)

### June 3, 2026 — Akshay DM: OSAC-1145 confirmed as next task
- "For tomorrow, yes, work on OSAC-1145" (playbook split into 4 lifecycle actions)

### June 3, 2026 — Storage WG Meeting (second session)
- Tier API is the development priority — needed for VM service functionality
- Per-provider proxy model selected for control plane routing of storage operations
- Storage readiness tracking decoupled from cluster status for cleaner separation
- PRD (product requirements documents) will formalize development workflows before implementation
- v0.1 scope confirmed: attach network storage and validate PVCs
- Dylan onboarding — new team member, collaborating with Will on VAST integration
- Action (Avishay): contact Eran about PRD skills for documentation standardization
- Action (Will): manage VAST integration, transition from env vars to Tier API when available

### June 4, 2026 — Akshay: fix version 0.1 assigned to features
- All features targeted for Milestone 1.0 assigned `Fix Version: 0.1` in Jira
- Epics to be reviewed and broken down into tasks by assignees
- Akshay commuting to Boston, rescheduled 1:1 with Zoltan to June 5
- Asked Zoltan about time allocation (fully on OSAC or divided)
- Roy setting up VAST 5.4 template instance

### Recurring Meeting Established
- **OSAC Storage (for VMaaS and CaaS)** — Tuesdays 9-10 AM ET (4-5 PM Israel, 3-4 PM CEST)
- Organized by Akshay via Alona
- Dedicated channel: wg-osac-storage (C0B6USDQ85S)
- Additional meeting scheduled June 4 at 10 AM EDT (5 PM IDT)

---

## Appendix: File Paths

### Enhancement Proposals
- `enhancement-proposals/enhancements/tenant-specific-storageclasses/README.md`
- `enhancement-proposals/enhancements/tenant-storage-tiers/README.md`

### Operator Code
- `osac-operator/api/v1alpha1/tenant_types.go`
- `osac-operator/internal/controller/tenant_controller.go`
- `osac-operator/pkg/provisioning/aap_provider.go`
- `osac-operator/pkg/provisioning/provision_lifecycle.go`

### AAP Code
- `osac-aap/collections/ansible_collections/osac/service/roles/tenant_storage_class/` (selection, merged)
- `osac-aap/collections/ansible_collections/osac/service/roles/tenant_storage_provision/` (provisioning, PR #266)
- `osac-aap/collections/ansible_collections/osac/service/roles/storage_provider/` (dispatcher, PR #296)
- `osac-aap/collections/ansible_collections/osac/templates/roles/vast_storage/` (VAST, PR #296)
- `osac-aap/collections/ansible_collections/osac/templates/roles/ocp_virt_vm/tasks/create_resources.yaml`
- `osac-aap/playbook_osac_create_compute_instance.yml`

### CaaS Template (No Storage)
- `osac-aap/collections/ansible_collections/osac/templates/roles/ocp_4_17_small/tasks/install.yaml`
- `osac-aap/collections/ansible_collections/osac/service/roles/hosted_cluster/tasks/create_hosted_cluster.yaml`
