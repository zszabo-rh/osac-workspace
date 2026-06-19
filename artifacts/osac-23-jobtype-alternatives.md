# OSAC-23: JobType Enum Alternatives

## Problem

The storage controller manages two independent lifecycles (backend + cluster-storage) on the Tenant CR. To distinguish jobs, we added 4 storage-specific values to the shared `JobType` enum. Because `JobStatus` is embedded in all 9 CRDs, these values leak into every CRD schema — Subnet, SecurityGroup, etc. all accept `storage-backend-provision` as a valid job type.

This also doesn't scale for CaaS: multiple clusters per tenant each need their own cluster-storage job tracking, which a flat `Jobs []` array can't model.

Note: after the storage extraction, the Tenant's generic `jobs` field (with `provision`/`deprovision`) is unused — the tenant controller does zero provisioning.

## Proposals

### A: Per-lifecycle CRDs

New CRDs: `TenantStorageBackend` (one per tenant) + `TenantClusterStorage` (one per tenant-cluster pair). Each has its own controller using standard `provision`/`deprovision` + `RunProvisioningLifecycle`.

```yaml
kind: TenantStorageBackend       # one per tenant
status:
  phase: Ready
  jobs: []    # standard provision/deprovision

kind: TenantClusterStorage       # one per tenant-cluster pair
status:
  phase: Ready
  jobs: []    # standard provision/deprovision

kind: Tenant                     # no jobs field
status:
  phase: Ready
  # reads storage readiness from child CRs

kind: Subnet                     # unchanged
status:
  phase: Ready
  jobs: []
```

- Follows Subnet/ClusterOrder pattern
- CaaS-native (one CR per cluster)
- Eliminates current storage controller (~740 lines) in favor of two simpler controllers
- Biggest scope: new types, new controllers, Tenant controller creates child CRs

### B: Sub-objects on Tenant only (recommended)

Replace the flat `jobs` field with per-lifecycle sub-objects:

```yaml
kind: Tenant
status:
  phase: Ready
  storageBackend:
    jobs: []    # uses standard provision/deprovision
  clusterStorage:
    jobs: []    # uses standard provision/deprovision

kind: Subnet    # unchanged
status:
  phase: Ready
  jobs: []
```

- Tenant-only change (~200-250 lines), no cross-CRD impact
- Each sub-object uses standard `provision`/`deprovision` — 4 storage enum values removed
- Per-lifecycle metadata groups naturally with jobs (name, provider, ready already exist as `StorageBackendStatus`/`ClusterStorageStatus`)
- CaaS: `clusterStorage` can become a list keyed by cluster name
- Forward-compatible: if the team later adopts sub-objects across all CRDs, Tenant is already done

### C: Sub-objects on all CRDs

Same as B but applied uniformly — every CRD moves `status.jobs` under `status.provisioning.jobs`:

```yaml
kind: Subnet
status:
  phase: Ready
  provisioning:
    jobs: []
```

- Most consistent pattern across the codebase
- Biggest refactor: all 9 CRDs, all controllers, feedback controllers, fulfillment-service sync, tests

## Comparison

| | A: Per-lifecycle CRDs | B: Tenant sub-objects | C: All CRDs |
|---|---|---|---|
| Enum clean | Yes | Yes | Yes |
| CaaS ready | Yes (native) | Yes (extensible) | Yes |
| Scope | Large (new CRDs + controllers) | Small (Tenant only) | Very large (all 9 CRDs) |
| Cross-team coordination | No | No | Yes |
| Pattern consistency | Follows child-CR pattern | Tenant diverges (justified) | Uniform |
| Reuses RunProvisioningLifecycle | Yes | Possible | Yes |
| Forward-compatible | — | With C | — |

## Recommendation

**B for v0.1** — fixes the enum, scoped to Tenant, CaaS-extensible, no cross-team dependencies. Unblocks merging the implementation PRs.

A or C can be evaluated for v0.2 if the team wants broader architectural alignment.
