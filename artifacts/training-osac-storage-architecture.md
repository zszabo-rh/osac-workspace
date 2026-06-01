# Training: OSAC Storage Architecture

**Topic:** End-to-end storage architecture for OSAC — VMaaS, CaaS, vendor integration, and open architectural questions
**Date:** 2026-05-14
**Context:** Preparation for the cross-team storage meeting. The learner implemented the storage provisioning framework (PRs #210/#266) and needed to understand the full landscape to facilitate the meeting.

---

## Training Overview

10 lessons covering K8s fundamentals through meeting strategy, with emphasis on the competing provisioning models (pre-provisioning vs JIT), storage isolation spectrum, CaaS gap, and the Avishay vs Michael architectural debate.

---

## Lesson Summaries

### Lesson 1: K8s StorageClass Fundamentals
- SCs are cluster-scoped "menu items" — they describe how storage is provisioned, not the storage itself
- CSI driver must be installed for the SC's provisioner to work
- Parameters are opaque to K8s, passed verbatim to CSI driver
- Multi-tenancy is hard: SCs are cluster-scoped, any PVC can reference any SC, no RBAC on SC usage
- Default SC annotation: `storageclass.kubernetes.io/is-default-class: "true"`

### Lesson 2: OSAC Label-Based Discovery
- Two labels: `osac.openshift.io/tenant` (who) + `osac.openshift.io/storage-tier` (what kind)
- Both labels required (EP #32) — SCs missing either are invisible to controller
- Resolution: per-tier, tenant-specific first → shared Default fallback
- `Default` (capital D) sentinel for shared SCs
- Tenant controller is single source of truth — Ansible roles consume pre-resolved list via extra_vars
- SC watch: tenant-specific changes reconcile one tenant, Default changes reconcile ALL tenants

### Lesson 3: Storage Isolation Spectrum
```
Level 0: No isolation (shared SC)
Level 1: Label routing (cloned SC, same backend) ← our default
Level 2: Backend isolation (per-tenant pools/creds) ← VAST PR #295
Level 3: Physical isolation (dedicated hardware)
```
- Key insight: cloning is the framework, not the isolation mechanism
- Real isolation comes from configure_backend.yaml CSP hook
- Lars's concern: "cloning offers no benefit without customization" — valid for production
- OSAC routing (controller-enforced) prevents cross-tenant SC usage at API level

### Lesson 4: Model A — Pre-Provisioning (PRs #210/#266)
- Trigger: Tenant controller detects no SC → AAP job → SC created
- Strengths: self-healing (SC watch), crash recovery (job IDs in status), clean deletion (finalizer)
- Assumptions that break: tenant=storage lifecycle, hub-only, one-time provisioning, static config
- Can't serve CaaS (hub SCs useless for child clusters)

### Lesson 5: Model B — JIT Provisioning (Will's PR #296)
- Trigger: VM/cluster playbook pre-task → storage_provider role → template role dispatch
- Template role pattern: `osac.templates.{{ provider }}_storage` (same as networking)
- Security: hardcoded provider allowlist prevents injection
- `provisioning_target: vmaas | caas` — CaaS stub exists
- Strengths: serves both services, follows OSAC patterns, OSAC-882 reusable
- Weaknesses: no self-healing, no operator lifecycle, config via env vars

### Lesson 6: Model C — Hybrid (Will's PR #295)
- Will pivoted from #296 to build on our framework's configure_backend.yaml hook
- Uses our pre-provisioning trigger + our role structure, fills in the VAST backend
- Proves the extension model works
- Avishay still prefers #296 — template role pattern, CaaS support, OSAC-882 alignment

### Lesson 7: VMaaS End-to-End Flow
- Full chain: platform setup → tenant onboarding → SC resolution → VM creation → DataVolume
- Two roles at different times: `tenant_storage_provision` (creates SCs) vs `tenant_storage_class` (selects SC for a VM)
- CI controller injects resolved storageClasses list into AAP extra_vars
- Template hardcodes tier name (e.g., "default") — EP #32 template-driven selection

### Lesson 8: CaaS Storage Gap
- Zero implementation today — HCP template has no storage references
- Three layers: HCP control plane (HyperShift handles), child cluster infra (the gap), tenant workloads (self-service)
- Dedicated VMaaS clusters have the SAME gap as CaaS — remote cluster, not hub
- Options: post-install hook, JIT (#296), split CSI (Avishay), leave to tenant

### Lesson 9: Meeting Strategy
- Five stakeholders with different positions (Avishay, Michael, Will, Lars, Akshay)
- Three tensions: custom CSI vs vendor-native, pre-provisioning vs JIT, VMaaS-only vs unified
- Minimum outcome: who writes the storage EP and what's its scope
- Facilitator role: surface tensions, don't advocate, push for decisions

### Lesson 10: Opening Speech
- Under 90 seconds, acknowledge Slack discussion moved things forward
- Propose minimal outcome (EP ownership)
- Hand control to domain experts immediately

---

## Key Debates

### Avishay vs Michael: Custom CSI vs Vendor-Native

| | Avishay | Michael |
|---|---------|---------|
| Vision | OSAC IS the storage control plane | OSAC orchestrates vendor control planes |
| CSI | Custom OSAC controller on hub | Standard vendor drivers everywhere |
| Credentials | Node plugin shouldn't need control plane creds | Tenant has root on nodes, can't fully hide |
| Quotas | Single PEP in OSAC, proactive enforcement | Distributed across vendors, may be reactive |
| Data flow | Always: user → OSAC → storage | CaaS: user → vendor CSI → storage → OSAC reads metrics |
| Core argument | "OSAC should be the control plane, not a billing collector" | "Embrace vendors, they're eager to implement controls" |
| Short-term | Concedes vendor-native for now | This IS his position |

### Pre-Provisioning vs JIT

| | Pre-Provisioning (#266) | JIT (#296) |
|---|------------------------|------------|
| Trigger | Tenant CR creation | VM/cluster request |
| CaaS | Can't serve (hub only) | Stub exists |
| Self-healing | Yes (SC watch) | No |
| Lifecycle | Yes (finalizer) | No |
| OSAC-882 reuse | Partially | Explicitly stated |
| Avishay preference | No | Yes ("more robust") |

---

## OSAC-882: Storage Tier Management APIs

The future direction that combines elements of both models:
- StorageTier as first-class API resource (admin creates/manages via API)
- StorageTier controller reconciles DB state to K8s StorageClasses
- Tenants can list available tiers and select per disk
- Reuses PR #296 AAP code for backend provisioning
- Controller provides self-healing (from our model)

---

## Key Takeaways (ranked by importance)

1. **Cloning is the framework, not the isolation.** Real isolation comes from backend hooks. This is by design, not a gap.

2. **Two competing long-term visions exist.** Avishay wants OSAC as the storage control plane (custom CSI). Michael wants to leverage vendor control planes. Short-term alignment exists; long-term needs an EP.

3. **CaaS and dedicated VMaaS share the same storage gap.** Any solution for one solves the other. Our hub-only pre-provisioning can't serve either.

4. **OSAC-882 is the convergence point.** StorageTier as API resource, controller-driven lifecycle, reuses JIT AAP code. Both Avishay and Will's approaches feed into this.

5. **Our PRs are stepping stones, not the destination.** The operator-side patterns (watch, self-heal, crash recovery, finalizer) carry forward. The triggering model and AAP-side code may change.

6. **The minimum meeting outcome is EP ownership.** Everything else flows from the storage architecture EP.

---

## Further Reading

- Architecture doc: `artifacts/osac-storage-architecture-overview.md`
- EP #26: `enhancement-proposals/enhancements/tenant-specific-storageclasses/README.md`
- EP #32: `enhancement-proposals/enhancements/tenant-storage-tiers/README.md`
- OSAC-882: Storage Tier Management APIs (Jira)
- OSAC-48: Independent Storage Volumes (Jira)
- PR #210: osac-operator (tenant storage provisioning controller)
- PR #266: osac-aap (provisioning framework + playbooks)
- PR #295: osac-aap (VAST integration via configure_backend)
- PR #296: osac-aap (JIT model with storage_provider role)
