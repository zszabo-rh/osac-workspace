# OSAC Storage Architecture Overview

**Purpose:** Living architecture document for OSAC storage — VMaaS, CaaS, vendor integration, and open questions.
**Last updated:** 2026-06-25
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
| **Operator** | Storage Controller + Option C (`provisioningJobs` rename, lifecycle-specific arrays, shared lifecycle helpers) | PR #299 | 2026-06-23 |
| **AAP** | Storage playbook split: 4 lifecycle actions + `teardown_backend` + renames | PR #338 | 2026-06-24 |
| **Labels** | `osac.openshift.io/tenant` (EP #26) | Merged | — |
| **Labels** | `osac.openshift.io/storage-tier` (EP #32) | Merged | — |

**Note on PR #229/#291 dependency:** PR #291 (AAP) was merged first (May 13) without the corresponding operator PR #229. This temporarily broke ComputeInstance creation — the playbook expects `tenant_storage_classes` in extra_vars but the operator wasn't sending it. Akshay reproduced the failure, overrode the failing e2e-vmaas prow job, and merged PR #229 on May 16 to fix the breakage.

### What's in PR

| Component | What | PR | Status | Notes |
|-----------|------|-----|--------|-------|
| **Fulfillment** | StorageBackend CRUD API | fulfillment-service #728 | **Merged** (June 24) | spec/status pattern, credential redaction, migration #62 |

### What's Merged (EPs/PRDs)

| Component | What | PR | Merged |
|-----------|------|-----|--------|
| **PRD** | OSAC-23 PRD v3 (condition ownership, no TenantStorage CRD) | EP #52 | 2026-06-15 |
| **EP** | OSAC-1111 StorageBackend enhancement proposal | EP #51 | 2026-06-15 |
| **Design** | OSAC-23 design (Akshay's version) — ClusterStorageReady, two-stage model | EP #58 | 2026-06-17 |
| **Design** | OSAC-1111 StorageBackend API design | EP #60 | 2026-06-17 |

### What's Not Started

| Area | Gap | Ticket | Notes |
|------|-----|--------|-------|
| **Storage Tier APIs** | No user-facing API for tier discovery/selection | OSAC-882 (New) | Roy+Will collaborating on Tier API PRD (June 16 action item) |
| **CaaS storage** | No storage provisioning inside child clusters | OSAC-1123 (New) | Akshay working on CaaS PRD. Depends on OSAC-23 |
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
| OSAC-326 | Demo: Tenant storage onboarding lifecycle | New (Zoltan) — v0.1/v0.2 TBD |
| OSAC-737 | VM Templates: Use Storage Tier Selection | **Closed** |
| OSAC-738 | Documentation: Storage Provider Integration Guide | New — v0.1/v0.2 TBD |
| OSAC-498 | Tenant controller: use target cluster client in tenantStorageClassExists | **Closed** |
| OSAC-499 | Tenant operations: dedicated ServiceAccount with scoped RBAC | New (Zoltan) — v0.1/v0.2 TBD |
| OSAC-1143 | Tenant controller: change readiness gate from StorageClass to hub Secret | **Closed** (superseded by OSAC-23 storage controller) |
| OSAC-1144 | Tenant controller: trigger osac-ensure-tenant-storage for VMaaS Phase 2 | **Closed** (done in PR #299) |
| OSAC-1145 | Split AAP storage playbooks into 4 lifecycle actions | **Closed** (done in PR #338) |
| OSAC-1146 | Trigger osac-cleanup-tenant-storage on resource deletion (tenant stays) | **Closed** (done in PRs #299 + #338) |

### Epic: OSAC-43 — VAST for VMaaS (Critical, Backlog)
**Assignee:** Will Gordon
**Summary renamed** from "VAST Data Tenant Storage Onboarding" (May 29)

| Key | Summary | Status |
|-----|---------|--------|
| OSAC-883 | Initial AAP MVP for VAST tenant storage provisioning | **Closed** |
| OSAC-884 | Record VAST storage MVP demo | **Closed** |
| OSAC-885 | Follow up on network isolation requirements for VAST storage | New |
| OSAC-886 | Expand VIP pool configuration options for VAST storage | **Closed** |
| OSAC-887 | CaaS integration for VAST tenant storage | **Closed** |
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
| OSAC-917 | Storage Backend Framework | New | WG-Storage | Feature-level. EP PR #51 merged (June 15) |
| OSAC-1110 | Storage Tier Definition & Private API | **In Progress** | Roy Golan | Epic under OSAC-917 for v0.1. Must-have. Updated June 21 |
| OSAC-1111 | Storage Backend Definition & Private API | **In Progress** | Roy Golan | Epic under OSAC-917. EP done (PR #51 merged), CRUD API (PR #728) under review. Updated June 21 |
| OSAC-882 | Tiered Storage Management | New | Unassigned | Feature-level |
| OSAC-1001 | Tenant Storage Lifecycle | New | WG-Storage | Feature-level. Owns OSAC-23, OSAC-56 |
| OSAC-23 | Rework Tenant Storage Onboarding | In Progress | Akshay Nadkarni | Epic under OSAC-1001. PRD+design merged, PRs #299+#338 merged. Only OSAC-77 (E2E tests, assigned to Zoltan) remains. OSAC-308 closed. |
| OSAC-1191 | CaaS — Provision and Manage OpenShift Clusters | New | WG-CaaS | Feature-level. Owns OSAC-1123, OSAC-1122 |
| OSAC-1332 | CaaS Cluster Storage (v0.1) | **In Progress** | Akshay Nadkarni | New parent for OSAC-1123 |
| OSAC-1123 | CaaS Tenant Storage Setup | New | Unassigned | Epic under OSAC-1332. Depends on OSAC-23. Akshay working on CaaS PRD |
| OSAC-48 | Independent Storage Volumes | New | Unassigned | Full volume lifecycle API. Under OSAC-984 |

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
| #299 | osac-operator | OSAC-23: Storage Controller + Option C + lifecycle refactoring | 2026-06-23 |
| #338 | osac-aap | OSAC-23: Rename storage playbooks to match two-stage model | 2026-06-24 |
| #728 | fulfillment-service | OSAC-1111: StorageBackend API (CRUD, spec/status, credential redaction) | 2026-06-24 |

### Closed (superseded)

| PR | Repo | Title | Closed | Reason |
|----|------|-------|--------|--------|
| #266 | osac-aap | Provisioning framework + playbooks | 2026-05-27 | Superseded by merged PR #296 |

### Open

| PR | Repo | Title | Status | Last Updated |
|----|------|-------|--------|--------------|
| #363 | osac-aap | OSAC-1326: VAST RBAC Realm + restricted Role for CSI credential | Open — Will Gordon. No reviews yet. | 2026-06-24 |
| #728 | fulfillment-service | OSAC-1111: StorageBackend API | **MERGED** (June 24). 9 commits. spec/status restructure, credential redaction, migration renumbered to 62. | 2026-06-24 |
| #72 | enhancement-proposals | OSAC-1123: PRD: CaaS Cluster Storage | Open — Akshay. Posted June 23 in wg-osac-storage. | 2026-06-24 |
| #66 | enhancement-proposals | OSAC-1110: PRD: StorageTier API | Open — Roy. Akshay reviewing. | 2026-06-23 |

### Recently Merged

| PR | Repo | Title | Merged |
|----|------|-------|--------|
| #60 | enhancement-proposals | OSAC-1111: StorageBackend API design document | 2026-06-17 |
| #58 | enhancement-proposals | Design: Rework Tenant Storage Onboarding (OSAC-23) | 2026-06-17 |
| #52 | enhancement-proposals | OSAC-23: PRD for Tenant Storage Onboarding Rework | 2026-06-15 |
| #51 | enhancement-proposals | OSAC-1111: StorageBackend enhancement proposal | 2026-06-15 |

Note: Operator PR #299 and AAP PR #338 are the implementation PRs. Merge order: operator first (storage controller disabled by default), then AAP.

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
| 12 | **Roy's alternative CSI model?** | June 10: Roy proposed deploying vendor CSI images without their operator (like OpenShift Cluster Storage Operator), overlaying provisioner sidecar with policy check. No proxy needed. Needs evaluation vs Avishay's proxy approach. |
| 13 | **Object storage (COSI)?** | June 10: Lars raised — MOC working with Pure on COSI driver for OpenShift. Same credential management issues as volume storage. Out of scope for v0.1 but needs tracking. |
| 14 | ~~AAP client launch-by-name bug?~~ | **RESOLVED (June 12):** Fixed by adding `TemplateID` field to launch requests — uses numeric ID when available. Committed on `feat/OSAC-23-storage-controller` branch. |
| 15 | ~~Akshay's design doc (PR #58) vs Zoltan's design?~~ | **RESOLVED (June 15):** Implementation aligned with PR #58 spec — all renames applied (`ClusterStorageReady`, `*-cluster-storage` playbooks, `teardown_cluster_storage` action). E2E re-tested successfully. Awaiting Avishay review for merge. |
| 16 | **StorageBackend lifecycle (soft-delete vs hard-delete)?** | June 16: Roy raised in wg-osac-storage. Will: soft-delete for retiring backends without nuking resources. Akshay: must define backend lifecycle. Consensus: block deletion if in use by any tier. Maintenance is a separate state. |
| 17 | **NVIDIA NCP storage requirements?** | June 16: Rom shared [NVIDIA requirements](https://docs.nvidia.com/dsx/ncp/nvidia-requirements-for-ai-clouds/storage-requirements). June 17: NCP meeting held. Akshay analyzed [NVIDIA ai-cloud-validation](https://github.com/NVIDIA/ai-cloud-validation) — 4 CSI validators + S3 test. Storage tests passed using LVMO. Avishay: "NCP doesn't affect the OSAC storage roadmap much." |
| 18 | ~~JobType enum leaking to all CRDs?~~ | **RESOLVED (June 19):** Option C agreed — rename `status.jobs` → `status.provisioningJobs` on all 9 CRDs, add lifecycle-specific arrays (`storageBackendJobs`, `clusterStorageJobs`) on Tenant and ClusterOrder. Implemented on PR #299, E2E validated. [Alternatives doc](https://docs.google.com/document/d/1obxCZSWvdy42B8Ig55UQbpSQpSsRzTv-gsdkJXYG6UQ). |

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

### June 5, 2026 — Zoltan / Akshay 1:1
- Discussed OSAC-23 scope: single OSAC Storage Controller (not multiple per phase), TenantStorage CRD name stays, controller renamed broader
- Akshay confirmed PRD + design spec required before PRs
- Akshay: OSAC-1145 moved under OSAC-23 as single delivery
- Akshay asked about time allocation (fully on OSAC or divided)

### June 5, 2026 — PRD + Design Doc Published (PR #52)
- Zoltan published PRD + design doc for OSAC-23 to enhancement-proposals repo
- First PR using the split prd.md + design.md format agreed upon by the team
- Posted in wg-osac-storage for review
- Akshay acknowledged but couldn't review before Monday (June 8)

### June 5, 2026 — Akshay + Liat: Storage UX Discussion (wg-osac-storage)
- Akshay and Will provided feedback on Liat Berkovich's (UX designer) storage mockups
- Clarified 3-phase storage model for UX: Storage Onboarding (cloud admin), Tenant Storage Onboarding (cloud admin), Resource Creation (tenant admin/user)
- Key UX distinction: StorageTiers not a CaaS concept for tenant visibility — tenants see clusters, StorageClasses, CSI drivers
- Will explained VAST view-per-tier model and VIP pool scaling

### June 6, 2026 — Roy Golan: StorageBackend EP (PR #51)
- Roy posted StorageBackend enhancement proposal PR #51 on enhancement-proposals
- Tagged Avishay, Akshay, Will for review

### June 7, 2026 — Avishay: StorageTier Definition
- Detailed 5-point StorageTier specification in wg-osac-storage thread:
  1. Created mostly during StorageBackend onboarding, can be added later
  2. Cloud provider admin can deprecate/obsolete tiers (same pattern as VM instance types)
  3. Many-to-many relationship between StorageBackends and StorageTiers
  4. Tier definition: Name, Description, List of StorageBackends, per-backend key-values for configuration
  5. Remove qos class, VIP pool, StorageClass name, tenant availability from tier spec (per Akshay)

### June 7, 2026 — Will: Beaker machine handover
- Will offered his beaker machine to Zoltan for VAST appliance access
- Akshay confirmed: "I've asked Will to hand over his beaker machine to you"
- Coordination for handover Monday June 9

### June 8, 2026 — Akshay: v0.1 delivery plan published (wg-osac-storage)
- Published delivery plan in Google Doc with pre-requisites and workflow
- Requested alignment on StorageBackend and StorageTier object structure for v0.1
- Will shared VAST VM setup script — fully provisions VAST to be OSAC-ready

### June 8, 2026 — Jira reorganization: CaaS Cluster Storage (OSAC-1332)
- New feature created: OSAC-1332 (CaaS Cluster Storage v0.1)
- Placed OSAC-1122 (VAST for CaaS) and OSAC-1123 (CaaS Tenant Storage Setup) under it
- No scope change — purely Jira management

### June 10, 2026 — Storage WG Meeting
- Roy proposed new CSI driver model: deploy vendor CSI without operator, overlay provisioner sidecar with policy check (similar to OpenShift Cluster Storage Operator)
- Lars joined wg-osac-storage channel, raised object storage (COSI) question
- MOC production stats: 597 Filesystem PVCs vs 5 Block — Filesystem is priority
- NFS multi-tenancy risk discussed: single VIP pool with NFS is riskier than block for tenant isolation
- Will shared initial VAST admin config doc (`1fzKMm7gdJ1lYT6zQTnO7BBeFsDLOiQcDzTf6MqAjVKM`)

### June 10-11, 2026 — OSAC-23 PRD v3 finalized
- Akshay rewrote PRD after Avishay's review: dropped TenantStorage CRD, adopted condition ownership on Tenant CR
- Playbook naming finalized: backend/class convention (backend = VAST, class = cluster)
- PRD ready for review on PR #52

### June 11, 2026 — OSAC-23 Implementation
- Design doc rewritten for condition ownership pattern (pushed to fork)
- Storage Controller implemented: 736-line controller, two AAP providers, four job types
- osac-aap playbooks renamed + `teardown_backend` action added
- Deployed on edge-17 SNO: controllers running, conditions visible on `kubectl get tenant -o wide`
- Blocked by pre-existing AAP client bug: `LaunchJobTemplate()` uses template name in URL, AAP 2.5 gateway requires numeric ID

### June 12, 2026 — OSAC-23 E2E Testing on edge-17
- Full E2E test suite executed on edge-17 SNO with VAST appliance (via SSH tunnel)
- Stage 1 (backend provisioning): VAST org + VIP pool + hub Secret creation verified for new and existing tenants
- Stage 2 (class provisioning): AAP created `vast-nfs-{tenant}-default` StorageClasses with VAST CSI, PVC binding confirmed
- Two-stage teardown verified: class cleanup → backend teardown → finalizer removal → tenant deleted
- Controller behavior: management-state skip, restart recovery, no duplicate jobs, condition ownership
- Playbook idempotency: all 4 playbooks (create-backend, create-class, delete-class, delete-backend) handle re-runs gracefully
- ComputeInstance integration: `tenant_storage_classes` correctly injected into AAP extra_vars from Tenant status
- NFS mount blocked by SSH tunnel topology (edge-17 specific, not applicable on routable networks)
- Test summary: `artifacts/osac-23-test-summary.md`

### June 13, 2026 — Akshay: PRD nearly approved + new design PR
- Avishay reviewed PR #52 (PRD): "One small comment + coderabbit and let's merge"
- Akshay addressed both comments (June 15)
- Akshay notified Will of upcoming playbook split changes (osac-aap PR #338)
- Akshay left comment on Will's VAST admin config doc for Orran review
- **New: Akshay created PR #58** — design doc generated via `/design` skill from latest PRD
  - Asked Zoltan to review; wants to share with team after PRD is approved
  - Uses `ClusterStorageReady` condition name (vs `StorageClassReady` in Zoltan's design)

### June 15, 2026 — PRD merged + design review
- **PR #52 (PRD) merged** — Avishay approved, merge bot merged
- Zoltan posted in wg-osac-storage: PRD merged, design PR #58 open for review, implementation testing in parallel
- Zoltan reviewed PR #58: approved with one comment (ClusterOrder watch handler uses `EnqueueRequestForOwner` but ClusterOrder has no tenant association)
- Akshay acknowledged the ClusterOrder comment: "Good catch — ClusterOrder and Tenant live in different namespaces, so `ownerReferences` can't be used"
- Akshay addressed CodeRabbit comments, asked Avishay and Roy for design review
- Avishay posted in wg-osac-storage: "Let's try to have faster turnaround for PRDs/designs. Unless something needs further research we should be merging 1-2 days after initial submission."
- Implementation aligned with PR #58 spec: renamed `StorageClassReady` → `ClusterStorageReady`, playbooks `*-storage-class` → `*-cluster-storage`, dispatcher action `cleanup` → `teardown_cluster_storage`. E2E re-tested on edge-17.

### June 15, 2026 — VLAN discussion (wg-osac-storage)
- Akshay discussed VAST VIP pool VLAN tagging for multi-tenancy with Will
- VAST supports per-tenant VIP pools with VLAN separation — to be explored in next milestone

### June 16, 2026 — WG-OSAC Storage meeting
- **Attendees:** Akshay (lost power mid-meeting), Roy, Ronnie, Rom, Avishay, Will, others
- Storage backend designs published and integrated; tenant storage onboarding refactoring in testing phase
- Resource shortages blocking cluster provisioning — team relying on new cluster tooling for testing
- **Paired reviews adopted** to accelerate design approvals (1-2 day turnaround target)
- **v0.2 planning started:** Akshay shared [v0.2 goals doc](https://docs.google.com/document/d/1-CCfzubTF0cS8ehF82zPc36wrGS19YM5-HQvjE3BbcA/edit?tab=t.4znol3d4jy9q) — multi-backend support, improved secret management for admin credentials
- **StorageBackend soft-delete discussion:** Roy raised whether soft-delete or hard-delete for StorageBackend. Will: soft-delete for retiring backends without nuking resources; maintenance is a separate state/status. Akshay: must define backend lifecycle (delete data vs replicate elsewhere). Ronnie: retention of data is the key difference. Consensus: block deletion if backend in use by any tier.
- Rom shared [NVIDIA NCP storage requirements](https://docs.nvidia.com/dsx/ncp/nvidia-requirements-for-ai-clouds/storage-requirements) — potential future priority
- Avishay removed GSD from osac-workspace (PR #63)
- **Action items:** Roy to review backend storage design + remove draft status; Roy+Will to collaborate on Tier API PRD; team to update PTO in KNI Edge calendar; Roy to share secrets thread in Slack

### June 16-17, 2026 — Akshay DMs
- Akshay will set up VAST appliance connection (tomorrow = June 18)
- Once design PR #58 approved, expects Zoltan to submit upstream PR(s) with implementation
- Akshay working on CaaS support PRD next
- Asked Zoltan to share beaker-to-VAST connectivity guide (guide created: `artifacts/vast-beaker-connectivity-guide.md`)
- Requested PTO update in KNI Edge calendar

### June 17, 2026 — PR submissions + NCP meeting
- Design PR #58 **merged** (Akshay merged after Roy/Will/Zoltan/CodeRabbit approvals)
- Zoltan posted implementation PRs in wg-osac-storage: osac-operator [#299](https://github.com/osac-project/osac-operator/pull/299) + osac-aap [#338](https://github.com/osac-project/osac-aap/pull/338)
- Akshay reviewed both PRs: raised JobType enum concern (storage-specific types leaking to all CRDs), missing unit tests, and AAP `teardown_cluster_storage` target mismatch (`hcp_data_plane` accepted but `teardown_backend` only accepts `vmaas`)
- Roy created storage labs spreadsheet with VAST/NetApp/Pure details, pinned in channel bookmarks
- Roy shared new VAST config doc for Orran/datacenter admins: `1fzKMm7gdJ1lYT6zQTnO7BBeFsDLOiQcDzTf6MqAjVKM`
- NCP meeting: Akshay analyzed NVIDIA ai-cloud-validation repo — 4 CSI validators (block/shared FS/NFS, quotas, tenant-scoped creds, dynamic+static provisioning) + S3. Storage tests passed using LVMO. Avishay: "NCP doesn't affect the OSAC storage roadmap much."
- OSAC got listed on [NVIDIA ISV validation program](https://www.nvidia.com/en-eu/data-center/isv-validation-program/)

### June 18, 2026 — JobType alternatives document circulated
- Akshay posted [Job Tracking Alternatives](https://docs.google.com/document/d/1obxCZSWvdy42B8Ig55UQbpSQpSsRzTv-gsdkJXYG6UQ) in wg-osac-storage with 3 proposals (A: per-lifecycle CRDs, B: separate arrays on Tenant, C: renamed arrays on all CRDs)
- Akshay's recommendation: Option C for long-term consistency
- Roy voted for Option B initially, then agreed with Akshay's suggestion
- Akshay got buy-in from WG-Core (Juan, Crystal) on Option C
- Akshay confirmed: "let's go with Option C"
- PR #728 (StorageBackend API): jhernand left 8 review comments (status message type, unique key design, tenant immutability, inline small functions, DB trigger checks). Akshay flagged credential plaintext in NOTIFY payload.

### June 19, 2026 — Option C implemented + E2E validated
- Rebased both PRs on latest origin/main (operator picked up BareMetalInstance feedback controller)
- Implemented Option C on PR #299: renamed `status.jobs` → `status.provisioningJobs` across all 9 CRDs, added `storageBackendJobs` + `clusterStorageJobs` on Tenant, added `clusterStorageJobs` on ClusterOrder, removed 4 storage-specific JobType enum values
- Additional cleanup: removed 6 unused TenantReason constants, added `TenantReasonNoProvider`, removed dead `GetStatusJobs()` methods, removed Tenant from `GetJobsFromResource()` (returns nil — storage controller manages its own arrays)
- Added 4 new unit tests for job array isolation and failure paths
- E2E tested on edge-17: 16/16 tests pass (CRD migration, upgrade path, lifecycle, deletion, job array routing, ComputeInstance with VAST storage)
- New image: `quay.io/rh-ee-zszabo/osac-operator:osac-23-v3`
- E2E report: `artifacts/osac-23-e2e-option-c-report.md`

### June 20, 2026 — US Holiday (Juneteenth)

### June 22, 2026 — Akshay's review push + approval
- Akshay reviewed PR #299: requested CodeRabbit review, resolved all CodeRabbit comments, pushed 2 additional lint fix commits (commits 14-15: `fix remaining gofmt lint errors`, `fix gofmt in test files`). PR now has 15 commits.
- Akshay ran full e2e-vmaas suite on his beaker (edge22): **46 passed, 1 failed** (test_validation_rejections — single-node resource constraint, passes when re-run individually)
- Prow e2e-vmaas **FAILURE** explained: CRD schema mismatch — operator writes `status.provisioningJobs` but CRDs from osac-installer submodule still have `status.jobs`. Operator logs show `unknown field "status.provisioningJobs"` for every controller, causing infinite AAP job loops.
- Akshay **APPROVED** PR #299 and posted detailed comment to @omer-vishlitzky and @eliorerz requesting `/override` for the Prow e2e failure
- Akshay asked Zoltan to follow up with Omer/Elior during EU hours to get the PR merged (they need to allow bypass of the vmaas suite)
- Akshay will review AAP PR #338 tomorrow (June 24)
- hypershift1 cluster back online (data center maintenance ended June 22)

### June 23, 2026 — Storage meeting + PR #299 merged
- **PR #299 MERGED** — Omer overrode e2e-vmaas, tide auto-merged. Omer also submitted openshift/release PR #80893 (merged same day) to fix the CRD schema mismatch for future operator PRs.
- **Storage meeting** (Tuesday, 3-4 PM CEST):
  - Agreed on OpenStack Cinder/Manila as CaaS translation layer — Avishay + Roy to do PoC end-to-end
  - VAST access: 4000 tenant limit discussed, OpenStack control plane central for quotas/policies
  - Jira tracking: fix-version tags on features only (not epics) for accurate milestone reporting
  - Akshay action items: CaaS PRD, review operator/AAP PRs, VMaaS+tier selection ticket for Ygal, bare metal storage needs with Adrian, UI priorities with Liat
  - Hardware: request powerful machine for CaaS (beaker insufficient)
- Akshay reviewed PR #338: flagged integration test broken (uses deleted `teardown` action), stale comment/task names, CodeRabbit findings
- Zoltan pushed fix commit (integration test split, naming cleanup, STORAGE_TIERS validation)
- Akshay approved PR #338, retested, merged
- **CaaS PRD posted**: enhancement-proposals PR #72 (OSAC-1123: CaaS Cluster Storage) — Akshay authored, posted in wg-osac-storage
- Akshay DM: "After the AAP change is in, what's the next thing on your plate?" — CaaS PRD is next priority

### June 24, 2026 — PR #338 + #728 merged, Jira cleanup, CaaS PRD reviewed
- **PR #338 MERGED** (all CI green)
- **PR #728 MERGED** (StorageBackend API — Roy addressed all feedback: spec/status restructure, credential redaction in events, migration renumbered to 62)
- All three OSAC-23 implementation PRs now in upstream main (#299 operator, #338 AAP, #728 fulfillment-service StorageBackend API)
- **Jira cleanup under OSAC-56**: Closed 5 tickets (OSAC-1145 done, OSAC-104 done, OSAC-1144 done, OSAC-1146 done, OSAC-1143 superseded by storage controller)
- Akshay asked about OSAC-23/OSAC-56 ticket completion in wg-osac-storage channel
- Zoltan responded: OSAC-23 core done (only OSAC-77 E2E tests remain), OSAC-56 cleaned up
- Akshay: will evaluate remaining OSAC-56 tickets for v0.1 vs v0.2 scope (VMaaS-related)
- CaaS PRD (PR #72) reviewed via `/review` skill — 1 critical (persona coverage), several important findings posted
- Akshay acknowledged `/prd-review` and `/review` skills as useful self-review tools
- PR #363 (Will, VAST RBAC): still open, changes requested by CodeRabbit, not draft

### June 25, 2026 — Status
- No storage meeting today (Wednesday)
- Next storage meeting: Tuesday June 30, 3-4 PM CEST

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
