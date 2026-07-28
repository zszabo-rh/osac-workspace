# OSAC-3011: Local/Dev/E2E CI Storage Setup — Ingest Context

**Fetched:** 2026-07-27  
**Epic:** OSAC-3011 → parent OSAC-917 (Storage Framework)  
**Status:** In Progress · Assignee: Zoltan Szabo · Target: 0.2-M2 (end of August)

---

## Summary

Register a `local` StorageBackend and StorageTier automatically during hub setup for dev/CI environments using LVMS. No production backend (VAST) required. Covers cluster-tool clusters and CI (vmaas-ci, caas-ci, bmaas-ci). Hub cluster only — CaaS guest cluster storage is out of scope.

## Acceptance Criteria

- [ ] StorageBackend (`local`, `provider: local_lvms`) and StorageTier (`local`) automatically registered during hub setup when `lvms.enabled: true`
- [ ] Storage controller supports the dev/CI provisioning path (depends on OSAC-3013 PR #354 + #375)
- [ ] CI environments (vmaas-ci, caas-ci, bmaas-ci) have working storage out-of-the-box
- [ ] cluster-tool dev clusters have working storage out-of-the-box (`development/values.yaml`)
- [ ] Tenant onboarding completes with `StorageBackendReady` and `ClusterStorageReady` conditions reaching True
- [ ] No production backend required for dev/CI workflows

## Key Design Decisions (from Jira comments + July 24 meeting)

1. **No proto changes.** Provider `local_lvms` registered with `endpoint: n/a`, `credentials: n/a`.
2. **No new IG.** `local_lvms_storage` role uses `storage-operations-ig` after OSAC-3013 removes VAST credentials from it.
3. **AAP dispatcher pattern.** New `local_lvms_storage` role in `osac.templates`, following `vast_storage` structure.
4. **StorageClass naming:** `osac-{tenant_name}-{tier_name}` (Akshay's Saturday proposal, applies to both `local_lvms_storage` and `vast_storage` going forward).
5. **Remove `defaultStorageClassSentinel`** fallback from `getTenantStorageClasses()` in osac-operator.
6. **development/values.yaml**: `lvms.enabled: false` → `true` (CI values already correct).

## Dependencies

- OSAC-3013 operator half (PR #354 + PR #375) must merge before OSAC-3011 PR. Implementation proceeds in parallel.

---

## Affected Components

### osac-aap — New role `local_lvms_storage`

Location: `collections/ansible_collections/osac/templates/roles/local_lvms_storage/`

**Files to create:**

| File | Purpose |
|------|---------|
| `tasks/setup.yaml` | Create minimal hub Secret for tenant (no external API — LVMS has no credentials) |
| `tasks/ensure_storage_class.yaml` | Create per-tenant labeled SC on hub using `lvms.topolvm.io` provisioner |
| `tasks/teardown_cluster_storage.yaml` | Delete per-tenant SC by label selector |
| `tasks/teardown_backend.yaml` | Delete hub Secret |
| `meta/argument_specs.yaml` | (optional, for documentation) |

**Dispatcher integration:** The dispatcher calls `osac.templates.{{ _current_provider }}_storage`. Provider name MUST be `local_lvms` (underscores) to produce valid role name `local_lvms_storage`. **Note:** Jira says `local-lvms` (hyphen) which would fail — must use underscore.

**StorageClass name pattern:** `osac-{{ tenant_name }}-{{ tier_name }}`  
**Labels required:** `osac.openshift.io/tenant={{ tenant_name }}`, `app.kubernetes.io/managed-by=osac-aap`, `osac.openshift.io/storage-tier={{ tier_name }}`  
**Provisioner:** `topolvm.io`  
**No protocol field** — LVMS has no protocol concept (unlike VAST which uses nfs/block).

**Reference role:** `vast_storage` — specifically `ensure_storage_class.yaml` (idempotency pattern) and `teardown_cluster_storage.yaml` (label-based SC cleanup). `teardown_backend.yaml` is much simpler than VAST's (just delete a Secret).

### osac-installer — New post-install hook

**File to create:** `charts/osac/templates/hooks/register-local-storage.yaml`

**Pattern:** Follow `seed-cluster-versions.yaml` exactly:
- `"helm.sh/hook": post-install,post-upgrade`
- `"helm.sh/hook-weight": "30"` (or appropriate weight — after OSAC is up)
- `serviceAccountName: admin`
- `initContainers: {{- include "osac.waitForFulfillment" . | nindent 6 }}`
- Idempotent: HTTP 409 = success

**API calls (private API):**
```
POST /api/private/v1/storage_backends
  {"metadata": {"name": "local"}, "spec": {"provider": "local_lvms", "endpoint": "n/a", "credentials": "n/a"}}

POST /api/private/v1/storage_tiers
  {"metadata": {"name": "local"}, "spec": {"backend": "local"}}
```

**Guard:** `{{- if .Values.lvms.enabled }}`

**File to modify:** `values/development/values.yaml`  
Change: `lvms.enabled: false` → `true`

**CI values (already correct — no change needed):**
- `values/vmaas-ci/values.yaml`: `lvms.enabled: true` ✓
- `values/caas-ci/values.yaml`: `lvms.enabled: true` ✓
- `values/bmaas-ci/values.yaml`: `lvms.enabled: true` ✓

**Also verify:** `charts/osac/values.yaml` has a `clusterVersions.enabled`-style toggle — confirm `lvms.enabled` is a top-level value already propagated to both `osac-operators` and `osac-prereqs` subcharts. (It is — checked in `charts/osac-operators/values.yaml` and `charts/osac-prereqs/values.yaml`.)

### osac-operator — Remove sentinel fallback

**File to modify:** `internal/controller/storage_tier_resolution.go`

**Change:** In `getTenantStorageClasses()`, remove the `defaultSCList` query and all logic that uses `defaultStorageClassSentinel`. The function should return only tenant-specific SCs. The constant in `tenant_names.go` can be removed once no usages remain.

**Test file to update:** `internal/controller/storage_controller_test.go` — multiple tests create `defaultStorageClassSentinel`-labeled SCs as a fallback expectation. Those expectations need to be removed/updated.

**Other sentinel usages to check:**
- `storage_controller.go:325` — the fallback call site (remove)
- `storage_controller.go:938` — `if tenantName == defaultStorageClassSentinel` guard (remove)

---

## Validation Profile

### osac-aap
```bash
cd osac-aap
uv run ansible-lint              # lint
# No unit tests for Ansible roles — validate via ansible-lint only
```

### osac-installer
```bash
cd osac-installer
yamllint --strict .              # YAML lint
helm lint charts/osac/           # Helm chart lint
helm template osac charts/osac/ --values values/development/values.yaml  # dry-run render
```

### osac-operator
```bash
cd osac-operator
make lint                        # golangci-lint
make test                        # unit tests (controller tests cover sentinel removal)
```

### Commit format
`OSAC-3011: <description>`

### PR convention
Fork-based: push to `fork` remote, PR from `fork/<branch>` to `origin/main`.
One PR per repo (osac-aap, osac-installer, osac-operator — 3 PRs total).

---

## Open Questions

1. **Provider name: `local_lvms` or `local-lvms`?** The Jira uses `local-lvms` (hyphen) but the dispatcher constructs `osac.templates.{{ provider }}_storage` — hyphens in Ansible role names are invalid. Must be `local_lvms`. The installer hook's API payload must match whatever the backend is registered with.

2. **StorageClass naming confirmation:** Akshay's Saturday Slack post proposed `osac-{tenant}-{tier}` as the new convention. Confirm this applies to `local_lvms_storage` (not just the CSI driver) before implementing `ensure_storage_class.yaml`.

3. **Hook weight ordering:** `seed-cluster-versions.yaml` uses weight 30. What weight should `register-local-storage.yaml` use? It needs fulfillment-service up (handled by `waitForFulfillment` init container) but no other dependency.

4. **Sentinel tests:** Removing the sentinel changes test expectations for ~8 test cases in `storage_controller_test.go`. Confirm the intent is to simply remove those fallback assertions (not replace with new LVMS-based test expectations).

5. **OSAC-2520 relationship:** OSAC-2520 ("Storage Framework E2E Integration") is assigned to Zoltan and has the same scope. Clarify if OSAC-2520 is a child of OSAC-3011 or will be addressed by the same PRs.
