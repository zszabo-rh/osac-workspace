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

CaaS tenants face a timing difference compared to VMaaS: the target cluster does not exist at tenant creation time. Phase 1 (backend provisioning) runs at tenant creation — identical to VMaaS. But Phase 2 (CSI + StorageClass installation) can only run after the HyperShift cluster is provisioned and nodes are ready. The ClusterOrder controller must integrate Phase 2 into the cluster provisioning lifecycle and gate cluster readiness on storage availability.

The two-phase model (designed in the Tenant Storage Provisioning design doc) explicitly accommodates this:

```
VMaaS: Phase 2 runs at first CI creation (mgmt cluster exists)
CaaS:  Phase 2 runs after cluster provisioned (guest cluster now exists)
```

Same Phase 1, same Phase 2 AAP job, different trigger point.

#### User Stories

**Phase 1: Backend Provisioning (at Tenant creation — shared with VMaaS)**

Identical to VMaaS. The Tenant controller handles this:
- Tenant CR created → operator checks: hub Secret exists?
- NO → triggers `osac-create-org` AAP job (creates backend tenant, views, quotas, credentials, hub Secret)
- YES → skip (idempotent)
- Tenant becomes Ready when: namespace exists AND hub Secret(s) exist for all configured tiers

No CaaS-specific work needed for Phase 1.

**Phase 2: Cluster-Side Setup (after cluster provisioned — CaaS-specific trigger)**

- ClusterOrder CR created for a tenant → HyperShift provisions the cluster
- Cluster becomes available (HostedCluster Ready, nodes ready, cluster operators healthy)
- ClusterOrder controller checks: Tenant Ready? (Phase 1 complete)
  - NO → requeue (wait for Phase 1)
  - YES → check: SCs exist on guest cluster for this tenant?
    - NO → trigger `osac-ensure-tenant-storage` AAP job with guest kubeconfig
    - YES → skip (idempotent, SCs already installed)
- Phase 2 job:
  - Reads hub Secret (credentials from Phase 1)
  - Installs CSI operator on guest cluster via OLM (idempotent)
  - Creates CSI Secret in tenant namespace on guest cluster
  - Creates StorageClasses per tier per protocol on guest cluster
  - Creates VolumeSnapshotClasses on guest cluster
- ClusterOrder transitions to Ready only after Phase 2 succeeds

**Cleanup (cluster deleted, tenant stays)**

- ClusterOrder deletion triggers `osac-cleanup-tenant-storage` AAP job
- Removes StorageClasses, VolumeSnapshotClasses, CSI Secret from guest cluster
- Backend resources and hub Secret are UNTOUCHED (tenant still exists, may have other clusters)
- Cleanup runs BEFORE namespace deletion in the ClusterOrder deletion flow

**Teardown (tenant deletion)**

No CaaS-specific teardown. The Tenant controller's `osac-delete-org` job handles full teardown across ALL target clusters (VMaaS and CaaS), then removes backend resources and hub Secret.

#### Credential Security

Same three-credential model as VMaaS:
- **Admin credentials:** ephemeral, Phase 1 only (already handled by Tenant controller)
- **Hub Secret:** hub cluster, tenant lifetime, read by Phase 2 to create CSI Secret
- **CSI Secret:** guest cluster, created during Phase 2, consumed by CSI driver

CaaS-specific consideration: the CSI Secret lives on the guest cluster, which the tenant has root access to. This means the tenant can read CSI credentials. This is an accepted tradeoff per the May 14 meeting decision (vendor-native CSI, tenants have root on CaaS).

#### Goals

- ClusterOrder controller triggers Phase 2 after cluster is ready and Tenant is Ready
- New `StorageReady` condition on ClusterOrder gates final Ready transition
- Guest cluster kubeconfig passed to AAP for Phase 2 execution
- Same `osac-ensure-tenant-storage` AAP job template used for both VMaaS and CaaS
- Same provider roles work for both (only `provisioning_target` changes: `vmaas` → `hcp_data_plane`)
- Storage cleanup integrated into ClusterOrder deletion flow

#### Non-Goals

- Phase 1 changes (backend provisioning is shared, handled by Tenant controller)
- BMaaS tenant storage (separate epic, backlog)
- Per-cluster tier customization (all clusters for a tenant use the same tiers)
- CSI operator lifecycle management (upgrade, health monitoring)
- Split CSI approach (rejected: CSI identifier mismatch, per Roy Golan June 1)

#### Scope

**In Scope:** Phase 2 trigger from ClusterOrder controller, `StorageReady` condition, guest kubeconfig delivery to AAP, storage cleanup on cluster deletion, `hcp_data_plane` provisioning target implementation

**Out of Scope:** Phase 1 (shared with VMaaS), provider-specific logic (handled by per-provider roles), tenant-level teardown (handled by Tenant controller)

#### Dependencies

- **Epic: VMaaS Tenant Storage Setup (v0.1)** — establishes two-phase model, hub Secret readiness gate, 4-action AAP playbook structure
- **OSAC-1145: Split AAP playbooks into 4 lifecycle actions** — defines `osac-ensure-tenant-storage` as separate playbook (critical prerequisite)
- **HyperShift cluster provisioning** — ClusterOrder controller, HostedCluster lifecycle
- **StorageBackend + StorageTier CRs** — tier configuration source (OSAC-882, OSAC-1110)

#### Current Implementation

Stubs and patterns that exist:
- `storage_provider_provisioning_target` enum has `hcp_data_plane` value (reserved, not implemented)
- `playbook_osac_create_hosted_cluster.yml` has post_install hook (currently cert-manager only)
- ClusterOrder controller has finalizer and deletion handling (no storage awareness)
- VAST `ensure_storage_class.yaml` already accepts kubeconfig parameters (used for hub, reusable for guest)
- Tenant controller Phase 2 pattern (`handleStorageProvisioning`, `pollProvisionJob`) is the reference implementation

#### Remaining Work

| Work Item | Repo | Type | Details |
|-----------|------|------|---------|
| Implement `hcp_data_plane` provisioning target | osac-aap | MODIFY | `vast_storage/ensure_storage_class.yaml`: accept guest kubeconfig, install CSI on guest cluster |
| Create `playbook_osac_ensure_cluster_storage.yml` | osac-aap | NEW | Phase 2 playbook for CaaS — calls `storage_provider` with `action: ensure_storage_class`, `provisioning_target: hcp_data_plane` |
| Create `playbook_osac_cleanup_cluster_storage.yml` | osac-aap | NEW | Cleanup playbook — removes SCs, VSCs, CSI Secret from guest cluster. Backend untouched. |
| Config-as-code: CaaS storage job templates | osac-aap | MODIFY | Add `osac-ensure-cluster-storage` and `osac-cleanup-cluster-storage` templates to `controller.yml` |
| ClusterOrder controller: trigger Phase 2 | osac-operator | MODIFY | After HC ready + Tenant Ready → trigger `osac-ensure-cluster-storage`. Gate ClusterOrder Ready on storage completion. |
| ClusterOrder CRD: `StorageReady` condition | osac-operator | MODIFY | New condition in `ClusterOrderStatus`. ClusterOrder Ready requires HC ready AND StorageReady. |
| ClusterOrder controller: storage cleanup on deletion | osac-operator | MODIFY | In `handleDelete`: trigger `osac-cleanup-cluster-storage` before namespace removal. |
| Guest kubeconfig delivery to AAP | osac-operator | MODIFY | Retrieve admin-kubeconfig from HostedCluster Secret, pass to AAP as extra_var or credential. |
| Unit tests: ClusterOrder storage lifecycle | osac-operator | NEW | Test Phase 2 trigger, `StorageReady` condition, deletion cleanup, edge cases. |
| E2E test: CaaS storage provisioning | osac-test-infra | NEW | Full lifecycle: create tenant → create cluster → verify SCs on guest → create PVC → delete cluster → verify cleanup |

#### Open Questions

1. **Kubeconfig delivery mechanism:** Pass guest kubeconfig as extra_var (simple, in-memory only) or as AAP credential type (more secure, file-mounted)? Extra_var is consistent with how we pass other data today.

2. **CSI operator installation:** Should the CSI operator be installed by Phase 2 (current VAST pattern) or pushed via ACM Policy to all managed clusters? ACM Policy is more declarative but couples us to RHACM. Recommend: Phase 2 (consistent with VMaaS, no RHACM dependency).

3. **Multiple clusters per tenant:** A tenant can create multiple CaaS clusters. Phase 2 runs independently for each. The cleanup action must only remove resources from the specific cluster being deleted, not all clusters. The `osac-cleanup-tenant-storage` playbook already accepts a `target_cluster` parameter.

4. **Cluster-order-to-tenant association:** ClusterOrder needs to know its tenant. Options: `osac.openshift.io/tenant` annotation on ClusterOrder CR (already used for CI), or lookup via fulfillment-service Organization→Tenant mapping. Recommend: annotation (simpler, already established pattern).

5. **Timing: when exactly does Phase 2 run?** After `hostedClusterIsReady()` returns true (HC Available + ClusterVersion Succeeding + not Degraded), but before ClusterOrder transitions to Ready. This is a new step inserted between "cluster ready" and "order ready".

6. **v0.1 scope with CaaS prioritization:** Akshay moved CaaS to v0.1 but VMaaS two-phase model (OSAC-1145) is a prerequisite. Should we implement OSAC-1145 first (blocking), or do a CaaS-specific minimal path (e.g., post_install hook in cluster template)?
