# OSAC-3011: Implementation Plan

**Three PRs, merge in dependency order: osac-aap → osac-installer → osac-operator**  
**STATUS: CODE COMPLETE — all branches committed, tests passing**  
**Branch name:** `feat/OSAC-3011-local-lvms-storage` (each repo)

Dependencies: OSAC-3013 (PR #354 + #375) must merge before OSAC-3011 PRs land. Implementation proceeds in parallel.

---

## PR 1: osac-aap — `local_lvms_storage` role

### Task A1 — Create `meta/osac.yaml`
**File:** `collections/ansible_collections/osac/templates/roles/local_lvms_storage/meta/osac.yaml`

Content modeled on `vast_storage/meta/osac.yaml`:
```yaml
title: Local LVMS Storage Provider
description: >
  Provisions per-tenant StorageClasses on the hub cluster using the LVMS (LVM Storage)
  provisioner. No external backend or credentials required. Hub cluster only.
template_type: storage_provider
implementation_strategy: local_lvms
capabilities:
  provisioning_targets:
    - vmaas
```

### Task A2 — Create `defaults/main.yaml`
**File:** `collections/ansible_collections/osac/templates/roles/local_lvms_storage/defaults/main.yaml`

```yaml
local_lvms_storage_tenant_config_secret_prefix: "local-lvms-tenant-config-"
local_lvms_storage_config_namespace: "{{ lookup('env', 'OSAC_STORAGE_CONFIG_NAMESPACE') | default('osac-system', true) }}"
local_lvms_storage_provisioner: "topolvm.io"
```

### Task A3 — Create `tasks/setup.yaml`
**File:** `collections/ansible_collections/osac/templates/roles/local_lvms_storage/tasks/setup.yaml`

Creates a minimal hub Secret for the tenant (marker for teardown; no credentials).

Steps:
1. Assert `_provider_tiers` defined and non-empty (same guard as vast_storage)
2. Validate `tenant_name` as DNS label
3. Create/update hub Secret `local-lvms-tenant-config-{{ tenant_name }}` in `{{ local_lvms_storage_config_namespace }}`:
   - Data: `provider: bG9jYWwtbHZtcw==` (base64 "local_lvms"), `tenant: <base64 tenant_name>`
   - Labels: `osac.openshift.io/tenant={{ tenant_name }}`, `app.kubernetes.io/managed-by=osac-aap`
4. Set `storage_provider_tenant_config: {}` (dispatcher expects this after setup; empty is fine — no per-provider creds needed downstream)

### Task A4 — Create `tasks/ensure_storage_class.yaml`
**File:** `collections/ansible_collections/osac/templates/roles/local_lvms_storage/tasks/ensure_storage_class.yaml`

Creates a per-tenant labeled StorageClass on the hub cluster. Idempotent.

Steps:
1. Assert `_provider_tiers` defined and non-empty
2. Validate `tenant_name` as DNS label
3. Build expected SC entries:
   - Name pattern: `osac-{{ tenant_name }}-{{ tier.name }}`
   - One SC per tier in `_provider_tiers`
4. Short-circuit check: `kubernetes.core.k8s_info` for SCs with labels `osac.openshift.io/tenant={{ tenant_name }}` + `app.kubernetes.io/managed-by=osac-aap` — skip creation if all expected names already exist
5. For each tier where SC is missing, create StorageClass via `kubernetes.core.k8s`:
   ```yaml
   apiVersion: storage.k8s.io/v1
   kind: StorageClass
   metadata:
     name: "osac-{{ tenant_name }}-{{ tier.name }}"
     labels:
       osac.openshift.io/tenant: "{{ tenant_name }}"
       osac.openshift.io/storage-tier: "{{ tier.name }}"
       app.kubernetes.io/managed-by: osac-aap
   provisioner: topolvm.io
   parameters:
     "topolvm.io/device-class": vg1
   reclaimPolicy: Delete
   volumeBindingMode: WaitForFirstConsumer
   ```
6. Set output: `storage_provider_storage_class_names: [{"name": "osac-{tenant}-{tier}", "tier": "{tier}"}, ...]`

### Task A5 — Create `tasks/teardown_cluster_storage.yaml`
**File:** `collections/ansible_collections/osac/templates/roles/local_lvms_storage/tasks/teardown_cluster_storage.yaml`

Deletes per-tenant SCs by label. Uses rescue block (cluster may be unreachable).

Steps:
1. Validate `tenant_name` as DNS label
2. Find all SCs with labels `osac.openshift.io/tenant={{ tenant_name }}` + `app.kubernetes.io/managed-by=osac-aap`
3. Delete each SC (ignore_errors: true per vast pattern)
4. Debug summary message
5. Rescue: warn about failure (cluster may be destroyed)

### Task A6 — Create `tasks/teardown_backend.yaml`
**File:** `collections/ansible_collections/osac/templates/roles/local_lvms_storage/tasks/teardown_backend.yaml`

Deletes hub Secret. Much simpler than VAST (no VMS API calls, no retry logic).

Steps:
1. Validate `tenant_name` as DNS label
2. Delete Secret `local-lvms-tenant-config-{{ tenant_name }}` from `{{ local_lvms_storage_config_namespace }}` (ignore_errors: true — may already be gone)
3. Debug summary message

### Task A7 — Lint
```bash
cd osac-aap && uv run ansible-lint
```

---

## PR 2: osac-installer — Hook + idempotency + values

### Task I1 — Create `register-local-storage.yaml` hook
**File:** `charts/osac/templates/hooks/register-local-storage.yaml`

Modeled exactly on `seed-cluster-versions.yaml`. Key differences: private API targets `/storage_backends` and `/storage_tiers`; guarded by `lvms.enabled`.

```yaml
{{- if .Values.lvms.enabled }}
apiVersion: batch/v1
kind: Job
metadata:
  name: register-local-storage
  namespace: {{ .Release.Namespace }}
  annotations:
    "helm.sh/hook": post-install,post-upgrade
    "helm.sh/hook-weight": "31"           # after seed-cluster-versions (30)
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
spec:
  backoffLimit: 5
  activeDeadlineSeconds: 300
  template:
    spec:
      serviceAccountName: admin
      initContainers:
      {{- include "osac.waitForFulfillment" . | nindent 6 }}
      containers:
      - name: register-storage
        image: {{ .Values.cliImage }}
        command:
          - /bin/bash
          - -euo
          - pipefail
          - -c
          - |
            AUTH_TOKEN=$(< /var/run/secrets/kubernetes.io/serviceaccount/token)
            BACKEND_API="https://fulfillment-internal-api:8001/api/private/v1/storage_backends"
            TIER_API="https://fulfillment-internal-api:8001/api/private/v1/storage_tiers"

            register() {
              local what="$1" url="$2" payload="$3"
              local code response
              response=$(mktemp)
              code=$(curl -skS -o "${response}" -w '%{http_code}' -X POST \
                --connect-timeout 5 --max-time 30 \
                -H "Authorization: Bearer ${AUTH_TOKEN}" \
                -H "Content-Type: application/json" \
                --data-binary "${payload}" "${url}")
              case "${code}" in
                2??) echo "${what} registered." ;;
                409) echo "${what} already exists, skipping." ;;
                *)   echo "ERROR: Failed to register ${what} (HTTP ${code})" >&2
                     cat "${response}" >&2; return 1 ;;
              esac
              rm -f "${response}"
            }

            register "StorageBackend 'local'" "${BACKEND_API}" \
              '{"metadata":{"name":"local"},"spec":{"provider":"local_lvms","endpoint":"n/a","credentials":"n/a"}}'

            register "StorageTier 'local'" "${TIER_API}" \
              '{"metadata":{"name":"local"},"spec":{"backend":"local"}}'
        # ... (resources, securityContext, volumes same as seed-cluster-versions)
      restartPolicy: OnFailure
{{- end }}
```

### Task I2 — Fix `configure-lvms.sh` idempotency
**File:** `charts/osac-prereqs/files/hooks/configure-lvms.sh`

Wrap the LVMCluster apply step with an existence check. The annotation step always runs.

```bash
if oc get sc lvms-vg1 --ignore-not-found -o name | grep -q lvms-vg1; then
  echo "lvms-vg1 already exists, skipping LVMCluster creation."
else
  echo "Applying LVMCluster configuration..."
  oc apply -f /config/config.yaml

  echo "Waiting for lvms-vg1 StorageClass..."
  until [[ -n "$(oc get sc --ignore-not-found lvms-vg1 -o name)" ]]; do
    sleep 5
  done
fi

echo "Setting lvms-vg1 as default StorageClass..."
oc annotate sc lvms-vg1 storageclass.kubernetes.io/is-default-class=true --overwrite
```

### Task I3 — Update `values/development/values.yaml`
**File:** `values/development/values.yaml`

```yaml
# Before:
lvms:
  enabled: false
# After:
lvms:
  enabled: true
```

### Task I4 — Validate
```bash
cd osac-installer
yamllint --strict .
helm lint charts/osac/
helm template osac charts/osac/ --values values/development/values.yaml > /dev/null
```

---

## PR 3: osac-operator — Sentinel removal

### Task O1 — Remove sentinel from `storage_tier_resolution.go`
**File:** `internal/controller/storage_tier_resolution.go`

In `getTenantStorageClasses()`:
- Remove the `defaultSCList` variable and `targetClient.List(..., defaultSCList, ...)` call
- Remove `defaultByTier := groupByTier(defaultSCList.Items)`
- Remove the `defaultSCs` branch inside the per-tier loop (the `case 0:` fall-through to Default resolution)
- The function now only returns tenant-specific SCs; `case 0:` becomes: add a `NotFound` error message and continue

### Task O2 — Remove sentinel call sites in `storage_controller.go`
**File:** `internal/controller/storage_controller.go`

- **Line ~325:** Remove the `defaultFallback` block — when no tenant-specific SCs exist and no AAP backend is configured, fall directly to `TenantReasonNotFound` (do not call `getTenantStorageClasses` a second time with the sentinel)
- **Line ~938 (`mapStorageClassToTenant`):** Remove the `if tenantName == defaultStorageClassSentinel` branch — Default-labeled SCs no longer trigger global tenant reconciliation

### Task O3 — Remove constant from `tenant_names.go`
**File:** `internal/controller/tenant_names.go`

Remove:
```go
// defaultStorageClassSentinel is the label value that marks a shared StorageClass
// available to all tenants as a fallback when no tenant-specific SC exists.
defaultStorageClassSentinel = "Default"
```

### Task O4 — Update tests in `storage_controller_test.go`
**File:** `internal/controller/storage_controller_test.go`

For each test case that calls `createLabeledStorageClass(ctx, "...", defaultStorageClassSentinel, ...)`:
- Remove the sentinel SC creation
- Update expected outcome: when no tenant-specific SC exists, expect `ClusterStorageReady=False` with `TenantReasonNotFound` (not a fallback to the Default SC)
- Approximately 8 test cases affected (grep confirms: lines 245, 305, 415, 447, 448, 575, 598, 1008, 1036)

### Task O5 — Validate
```bash
cd osac-operator
make lint
make test
```

---

## Acceptance Criteria Coverage

| AC | Tasks |
|----|-------|
| StorageBackend + StorageTier auto-registered | I1 (hook) |
| Storage controller supports dev/CI path | O1-O4 (sentinel removal) + OSAC-3013 dependency |
| CI environments work out-of-the-box | I1 (hook fires on existing `lvms.enabled: true` CI values) |
| cluster-tool dev clusters work | I2 (idempotency) + I3 (values change) + I1 (hook) |
| Tenant onboarding completes with storage conditions | A3-A5 (role actions) |
| No production backend required | All of the above |

---

## Notes

- **No `localStorageFulfillment` IG** — `local_lvms_storage` uses `storage-operations-ig` after OSAC-3013 removes VAST credentials from it. This is a merge-order dependency, not a code dependency.
- **CI values already correct** — vmaas-ci, caas-ci, bmaas-ci already have `lvms.enabled: true`. No changes needed there.
- **OSAC-3012 (MOC)** — The `configure-lvms.sh` idempotency fix (Task I2) is included here because it's required to safely enable LVMS on MOC via the same `development/values.yaml` change.
- **StorageClass `volumeBindingMode: WaitForFirstConsumer`** — Required for topolvm so the PV is provisioned on the correct node when the pod is scheduled.
