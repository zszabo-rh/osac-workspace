# OSAC-1123: CaaS Tenant Storage Setup — Work Items

**Epic:** OSAC-1123 (CaaS Tenant Storage Setup)
**Parent Feature:** OSAC-1191 (CaaS — Provision and Manage OpenShift Clusters)
**Fix Version:** 0.1 (reprioritized from 0.2 on June 1)
**Author:** Zoltan Szabo
**Date:** 2026-06-02

---

## Google Doc Content (for tab: Epic: CaaS Tenant Storage (v0.2))

The following is formatted to match the VMaaS tab structure exactly. Copy into the Google Doc tab `t.i4gwzk8vu3sf`.

---

### CaaS Tenant Storage

**Target Milestone:** v0.1 (reprioritized June 1, was v0.2)
**Ticket:** https://redhat.atlassian.net/browse/OSAC-1123

#### Summary

Implement post-cluster-provision storage setup for CaaS tenants. Phase 1 (backend provisioning) is shared with VMaaS and runs at tenant creation. Phase 2 (CSI driver + StorageClasses) runs on the newly provisioned guest cluster after HyperShift reports the cluster as ready. The ClusterOrder is only marked Ready when storage setup completes.

#### Motivation

CaaS tenants face a timing difference compared to VMaaS: the target cluster does not exist at tenant creation time.

For VMaaS, the target cluster (hub/management cluster) exists from day one. Phase 2 runs at tenant onboarding — immediately after Phase 1, because the cluster is already there.

For CaaS, the target cluster (guest cluster) is provisioned later via HyperShift. Phase 2 can only run after the cluster exists and nodes are ready. The ClusterOrder controller must integrate Phase 2 into the cluster provisioning lifecycle and gate cluster readiness on storage availability.

The two-phase model (designed in the Tenant Storage Provisioning design doc) explicitly accommodates this:

```
VMaaS:
  Phase 1 → at tenant onboarding
  Phase 2 → at tenant onboarding (mgmt cluster already exists)

CaaS:
  Phase 1 → at tenant onboarding (same)
  Phase 2 → after cluster provisioned (guest cluster now exists)
```

Same Phase 1, same Phase 2 AAP job, different trigger point.

#### Prerequisites (Step 0): Storage Backend Setup

Before any OSAC-managed automation, the Cloud Infrastructure Admin must:
- Establish network connectivity between OpenShift and the storage backend (VAST management + data interfaces)
- Configure shared VIP pool on the storage backend
- Create a Kubernetes Secret with backend admin credentials

This is identical for VMaaS and CaaS — the same backend serves both. For CaaS there is an additional networking consideration: guest cluster nodes (bare metal or VMs on potentially different network segments) need network connectivity to the storage backend data interfaces. This is an infra admin responsibility and should be validated before tenant onboarding.

The Cloud Provider Admin then registers the backend in OSAC:
- Register backend as `StorageBackend` CR via the private API
- Define storage tiers (e.g., fast/block, standard/nfs) as `StorageTier` CRs

#### User Stories

**Phase 1: Backend Provisioning (at Tenant creation — shared with VMaaS)**

Identical to VMaaS. The Tenant controller handles this:
- Tenant CR created → operator checks: hub Secret exists for this tenant?
- NO → triggers `osac-create-org` AAP job
  - Storage provider dispatcher reads StorageBackend and StorageTier CRs
  - Dispatches to provider (e.g., VAST): creates backend tenant, views, quotas, QoS
  - Stores per-tenant credentials in hub Secret
- YES → skip (idempotent, Secret already exists)
- Tenant Ready when: namespace exists AND hub Secret(s) exist for ALL configured tiers

No CaaS-specific work needed for Phase 1.

**Phase 2: Cluster-Side Setup (after cluster provisioned — CaaS-specific trigger)**

- ClusterOrder CR created for a tenant → HyperShift provisions the cluster
- Cluster becomes available (HostedCluster Ready, nodes ready, ClusterVersion succeeding, not degraded)
- ClusterOrder controller checks: Tenant Ready? (Phase 1 complete)
  - NO → requeue (wait for Phase 1)
  - YES → check: SCs exist on guest cluster for this tenant?
    - NO → trigger `osac-ensure-tenant-storage` AAP job with guest kubeconfig
    - YES → skip (idempotent, SCs already installed)
- Phase 2 job:
  - Reads hub Secret (credentials from Phase 1)
  - Installs CSI operator on guest cluster via OLM (idempotent)
  - Creates CSI Secret in tenant namespace on guest cluster
  - Creates StorageClasses per tier per protocol on guest cluster (e.g., `vast-block-acme-fast`)
  - Creates VolumeSnapshotClasses per tier (snapshot equivalents of StorageClasses, enabling `VolumeSnapshot` creation for backup/clone use cases)
- ClusterOrder transitions to Ready only after Phase 2 succeeds

**Cleanup (cluster deleted, tenant stays)**

- ClusterOrder deletion triggers `osac-cleanup-tenant-storage` AAP job
- Removes StorageClasses, VolumeSnapshotClasses, CSI Secret from guest cluster
- Backend resources and hub Secret are UNTOUCHED (tenant still exists, may have other clusters)
- Cleanup runs BEFORE namespace deletion in the ClusterOrder deletion flow
- Edge case: if the guest cluster is already unreachable (HyperShift tear-down in progress), cleanup is skipped gracefully — cluster resources are destroyed with the cluster anyway

**Teardown (tenant deletion)**

No CaaS-specific teardown work. The Tenant controller's `osac-delete-org` job handles full teardown. Tenant deletion naturally triggers ClusterOrder deletions first (standard Kubernetes owner-reference cascade or fulfillment-service orchestration), each of which runs its own storage cleanup. Then the Tenant teardown removes backend resources and hub Secret.

Tenant teardown orchestration (knowing which clusters belong to a tenant) is a general tenant lifecycle concern, not storage-specific. All OSAC resources carry `osac.openshift.io/tenant` annotations. If this orchestration doesn't exist yet, it should be created as a separate work item outside this epic.

#### Credential Security

Same three-credential model as VMaaS:
- **Admin credentials:** ephemeral, Phase 1 only. Mounted as env vars on AAP pod, cleared after use, never persisted to Kubernetes.
- **Hub Secret:** hub cluster (`osac-system` namespace), tenant lifetime. Stores per-tenant credentials (tenant ID, endpoint, username, password, backend metadata). Consumed by operator (readiness check) and Phase 2 playbook.
- **CSI Secret:** guest cluster (tenant namespace), created during Phase 2. Contains only what the CSI driver needs (username, password, endpoint) — a subset of the hub Secret.

CaaS-specific consideration: the CSI Secret lives on the guest cluster, which the tenant has root access to. The tenant can read CSI credentials. This is mitigated by VAST tenant isolation — the credentials only grant access to the tenant's own views, quotas, and data paths. Other tenants' data is inaccessible even with the credentials. This is an accepted tradeoff per the May 14 meeting decision (vendor-native CSI, no custom CSI proxy, tenants have root on CaaS).

#### Guest Kubeconfig Delivery

Phase 2 needs to create resources on the guest cluster. The AAP playbook needs a kubeconfig to reach the guest cluster's API server.

An established pattern already exists in OSAC: `playbook_osac_create_hosted_cluster_post_install.yml` receives `admin_kubeconfig` as an extra_var and uses it via the `KUBECONFIG` environment variable with `osac.service.to_temp_file` filter (writes to a temp file on the execution environment, cleaned up after playbook finishes).

The CaaS storage playbook will use the same pattern. The operator retrieves the admin-kubeconfig from the HostedCluster's Secret and passes it as an extra_var.

#### Goals

- ClusterOrder controller triggers Phase 2 after cluster is ready and Tenant is Ready
- New `StorageReady` condition on ClusterOrder gates final Ready transition
- Guest cluster kubeconfig passed to AAP via extra_var (established pattern)
- Same `osac-ensure-tenant-storage` AAP job template used for both VMaaS and CaaS
- Same provider roles work for both (only `provisioning_target` changes: `vmaas` → `hcp_data_plane`)
- Storage cleanup integrated into ClusterOrder deletion flow

#### Non-Goals

- Phase 1 changes (backend provisioning is shared, handled by Tenant controller)
- BMaaS tenant storage (separate epic, backlog)
- Per-cluster tier customization (all clusters for a tenant use the same tiers)
- CSI operator lifecycle management (upgrade, health monitoring)
- Split CSI approach (rejected: CSI identifier mismatch — CSI driver name in StorageClass must match the node plugin registration, per Roy Golan June 1)
- Dedicated VMaaS cluster storage (same mechanism as CaaS — kubeconfig delivery — but scoped under VMaaS epic)
- Tenant teardown orchestration (general tenant lifecycle, not storage-specific)
- Storage observability / metrics collection (separate feature)
- etcd storage for HyperShift control plane (`hcp_control_plane` provisioning target, separate concern)

#### Scope

**In Scope:** Phase 2 trigger from ClusterOrder controller, `StorageReady` condition, guest kubeconfig delivery to AAP, storage cleanup on cluster deletion, `hcp_data_plane` provisioning target implementation in storage_provider role

**Out of Scope:** Phase 1 (shared with VMaaS), provider-specific logic (handled by per-provider roles), tenant-level teardown, storage observability, control plane storage, networking to storage backend (infra admin Step 0)

#### Dependencies

- **OSAC-1145: Split AAP playbooks into 4 lifecycle actions** — critical prerequisite that defines `osac-ensure-tenant-storage` and `osac-cleanup-tenant-storage` as separate playbooks. Shared infrastructure for both VMaaS and CaaS.
- **Epic: VMaaS Tenant Storage Setup (OSAC-56)** — establishes two-phase model, hub Secret readiness gate. Phase 1 implementation is reused directly.
- **HyperShift cluster provisioning** — ClusterOrder controller, HostedCluster lifecycle, admin-kubeconfig Secret
- **StorageBackend + StorageTier CRs (OSAC-882, OSAC-1110)** — tier configuration source. The storage_provider role reads tier definitions from these CRs.
- **Guest cluster network connectivity to storage backend** — infra admin prerequisite (Step 0). Not an OSAC automation dependency, but a deployment prerequisite.

#### Current Implementation

Stubs and patterns that exist today:
- `storage_provider_provisioning_target` enum has `hcp_data_plane` value (reserved, not yet implemented)
- `playbook_osac_create_hosted_cluster_post_install.yml` receives guest kubeconfig via `admin_kubeconfig` extra_var and uses `osac.service.to_temp_file` filter — established pattern for CaaS storage playbook
- ClusterOrder controller has finalizer and deletion handling (no storage awareness yet)
- VAST `ensure_storage_class.yaml` uses `kubernetes.core.k8s` module calls that accept `kubeconfig` parameter — should work with guest kubeconfig, but needs validation
- Tenant controller's `handleStorageProvisioning` / `pollProvisionJob` and `RunProvisioningLifecycle` are the reference implementation for operator-side Phase 2 orchestration
- Multiple clusters per tenant is architecturally supported: Phase 1 runs once per tenant, Phase 2 runs independently per cluster. The hub Secret (shared) is read by each Phase 2 execution.

#### Remaining Work

| Work Item | Repo | Type | Details |
|-----------|------|------|---------|
| Implement `hcp_data_plane` provisioning target | osac-aap | MODIFY | `vast_storage/ensure_storage_class.yaml`: accept guest kubeconfig, target guest cluster for CSI operator, CSI Secret, and SC creation. Validate that existing `kubernetes.core.k8s` calls work with external kubeconfig. |
| Create `playbook_osac_ensure_cluster_storage.yml` | osac-aap | NEW | Phase 2 playbook for CaaS. Uses `admin_kubeconfig` extra_var with `to_temp_file` filter (same pattern as post_install playbook). Calls `storage_provider` with `action: ensure_storage_class`, `provisioning_target: hcp_data_plane`. |
| Create `playbook_osac_cleanup_cluster_storage.yml` | osac-aap | NEW | Cleanup playbook. Removes SCs, VolumeSnapshotClasses, CSI Secret from guest cluster. Backend untouched. Handles unreachable cluster gracefully. |
| Config-as-code: CaaS storage job templates | osac-aap | MODIFY | Add `osac-ensure-cluster-storage` and `osac-cleanup-cluster-storage` templates to `controller.yml`. |
| ClusterOrder controller: trigger Phase 2 | osac-operator | MODIFY | After `hostedClusterIsReady()` + Tenant Ready → trigger `osac-ensure-cluster-storage`. Gate ClusterOrder Ready on storage completion. Use `RunProvisioningLifecycle` pattern from Tenant controller. |
| ClusterOrder CRD: `StorageReady` condition | osac-operator | MODIFY | New condition in `ClusterOrderStatus`. ClusterOrder Ready requires HC ready AND StorageReady. |
| ClusterOrder controller: pass guest kubeconfig to AAP | osac-operator | MODIFY | Retrieve admin-kubeconfig from HostedCluster Secret, include in extra_vars as `admin_kubeconfig`. |
| ClusterOrder controller: storage cleanup on deletion | osac-operator | MODIFY | In `handleDelete`: trigger `osac-cleanup-cluster-storage` before namespace removal. Skip gracefully if guest cluster is unreachable. |
| Unit tests: ClusterOrder storage lifecycle | osac-operator | NEW | Test Phase 2 trigger, `StorageReady` condition, deletion cleanup, unreachable cluster handling, missing Tenant annotation (skip storage). |
| E2E test: CaaS storage provisioning | osac-test-infra | NEW | Full lifecycle: create tenant → create cluster → verify SCs on guest → create PVC → delete cluster → verify cleanup. |

#### Cross-Cutting Concerns

**Networking:**
Guest cluster nodes need network connectivity to the storage backend data interfaces (e.g., VAST VIP pool IPs). For VMaaS this is implicit (VMs run on the hub which already has connectivity). For CaaS, the HyperShift worker nodes may be on different network segments. This is an infra admin responsibility (Step 0) but should be documented and validated before tenant onboarding. Failure to establish connectivity will cause CSI volume operations to fail at runtime, not at provisioning time.

**Observability:**
Storage metrics (usage, IOPS, latency) come from vendor Prometheus endpoints (per May 14 meeting decision). For CaaS, the question of which Prometheus instance scrapes these metrics (per-cluster or central) is unresolved. This is out of scope for this epic — the Storage Observability feature (separate in Akshay's planning doc) covers this.

**Security:**
The tenant has root access on CaaS clusters and can read the CSI Secret. VAST tenant isolation ensures credentials only grant access to the tenant's own data. This is the accepted model. The split CSI approach (which would have kept credentials off the guest cluster) was rejected because of CSI identifier mismatch (Roy Golan, June 1).

**Quotas:**
Storage quotas are enforced by the backend (e.g., VAST quotas per tenant), not by OSAC. A tenant with multiple CaaS clusters shares the same storage quota pool. This is by design (May 14 meeting: "backend storage is source of truth for quotas").

**Dedicated VMaaS clusters:**
If VMs run on a dedicated cluster (not the hub), the storage provisioning faces the same challenge as CaaS — a kubeconfig is needed for the remote cluster. Solving CaaS storage also enables dedicated VMaaS clusters. This is noted here for awareness but scoped under the VMaaS epic.

#### Open Questions

1. **CSI operator installation method:** Should the CSI operator be installed by the Phase 2 AAP playbook (current VAST pattern, consistent with VMaaS) or pushed via ACM Policy to managed clusters (more declarative, handles drift)? Recommend: AAP for v0.1 (consistent, no RHACM dependency). ACM Policy is a potential v0.2 optimization.

2. **Cluster-order-to-tenant association:** ClusterOrder needs to know its tenant. Recommend: `osac.openshift.io/tenant` annotation on ClusterOrder CR (same pattern as ComputeInstance). Need to verify the fulfillment-service already sets this annotation on ClusterOrder CRs.

3. **Phase 2 exact timing:** After `hostedClusterIsReady()` returns true (HC Available + ClusterVersion Succeeding + not Degraded + nodes ready). The CSI operator's DaemonSet needs schedulable nodes, so we must wait for nodes to be ready before triggering Phase 2. `hostedClusterIsReady()` already checks `ClusterVersionSucceeding` which implies nodes are available.

4. **Guest cluster unreachable during cleanup:** If HyperShift is tearing down the cluster concurrently with our cleanup job, the guest API may be gone. The cleanup playbook should handle connection failures gracefully and treat an unreachable cluster as "already cleaned up."
