# OSAC-3011 E2E Flow — Local/Dev Storage Setup

**Purpose:** Reference for repeating the OSAC-3011 E2E verification and for the demo.  
**Last run:** 2026-07-29, edge-17, cluster `demo`, namespace `osac-e2e-ci`  
**Status:** ✅ Complete — all tenant conditions True, `osac-shared-local` StorageClass created

---

## What the test verifies

The full OSAC-3011 flow:
```
make install (with lvms.enabled=true)
  → configure-lvms.sh (idempotent: skips if lvms-vg1 exists)
  → register-local-storage.yaml hook
      → StorageBackend "local" (provider: local_lvms) registered → READY
      → StorageTier "local" (backend_id linked) registered → ACTIVE
  → operator detects backend → triggers AAP job osac-create-tenant-cluster-storage
  → AAP runs local_lvms_storage/tasks/ensure_storage_class.yaml
      → creates osac-<tenant>-local StorageClass (provisioner: topolvm.io)
  → operator: ClusterStorageReady=True
```

Expected end state:
- `StorageBackend "local"` → `STORAGE_BACKEND_STATE_READY`
- `StorageTier "local"` → `STORAGE_TIER_STATE_ACTIVE`
- `Tenant "shared"` conditions: `StorageBackendReady=True`, `ClusterStorageReady=True`, `NamespaceReady=True`
- StorageClass `osac-shared-local` exists with labels `osac.openshift.io/tenant=shared`, `osac.openshift.io/storage-tier=local`
- PVC with `storageClassName: osac-shared-local` creatable (stays Pending until pod scheduled — WaitForFirstConsumer)

---

## Prerequisites

- Test operator image built from integration branch (main + sentinel removal + #354 + #375):
  ```
  quay.io/rh-ee-zszabo/osac-operator:osac-3011-test
  ```
- AAP fork branch `zszabo-rh/osac-aap:test/OSAC-3011-combined`:
  = main + local_lvms_storage role + provider validation fix + OSAC-3013 event tier definitions fix
- osac-operator#354 and #375 merged (now on main)

---

## Standard flow (clean install)

### 1. Boot cluster (edge-17 / Beaker)

```bash
# On edge-17 host
python3 /usr/local/bin/cluster-tool boot \
  --flavor vmaas-4-22 \
  --name osac-3011 \
  --pull-secret /root/pull-secret.json
export KUBECONFIG=/root/.kube/osac-3011.kubeconfig
```

### 2. Deploy OSAC with test image and fork branch

```bash
cd /tmp/osac-installer
make install VALUES_FILE=values/vmaas-ci/values.yaml \
  --set operator.image.repository=quay.io/rh-ee-zszabo/osac-operator \
  --set operator.image.tag=osac-3011-test \
  --set aap.configAsCode.projectGitUri=https://github.com/zszabo-rh/osac-aap.git \
  --set aap.configAsCode.projectGitBranch=test/OSAC-3011-combined
```

`make install` runs three phases:
- Phase 1: install OLM operators (cert-manager, AAP, LVMS)
- Phase 2: configure prerequisites (ClusterIssuer, LVMCluster, Keycloak)
- Phase 3: deploy OSAC stack (fulfillment-service, operator, AAP bootstrap)

Phase 3 includes the `register-local-storage.yaml` post-install hook which registers StorageBackend + StorageTier automatically.

Wait ~15 minutes for all pods to be Running and AAP config-as-code to sync.

### 3. Verify operator is running with test image

```bash
oc get deploy -n <namespace> osac-operator \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
# Expected: quay.io/rh-ee-zszabo/osac-operator:osac-3011-test
```

### 4. Watch for StorageBackend and StorageTier registration

```bash
oc get tenant -n <namespace> shared -o jsonpath='{.status.conditions}' \
  | python3 -c 'import sys,json; [print(c["type"],":",c["status"],"-",c["reason"]) for c in json.load(sys.stdin)]'
# Expected: StorageBackendReady: True - Found
```

### 5. Watch StorageClass creation

```bash
oc get storageclass -l osac.openshift.io/tenant=shared -w
# Expected: osac-shared-local   topolvm.io   Delete   WaitForFirstConsumer
```

### 6. Verify PVC creation

```bash
oc apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: osac-test-pvc
  namespace: <namespace>
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: osac-shared-local
  resources:
    requests:
      storage: 1Gi
EOF
oc get pvc -n <namespace> osac-test-pvc
# Status: Pending — EXPECTED (WaitForFirstConsumer, binds when pod uses it)
oc delete pvc -n <namespace> osac-test-pvc
```

---

## Workarounds applied on 2026-07-29 (WIP status)

These were needed because some dependencies were not yet merged or the cluster was partially configured. They are **not needed** for a standard clean install once all PRs merge.

### WA-1: Helm upgrade on existing cluster instead of fresh install

**Why:** edge-17 cluster `demo` was already deployed from a snapshot (cluster booted from a cold image, not a fresh `make install`). The cluster had OSAC pre-installed with a stale AAP project configuration pointing to upstream main.

**What was done:** Ran `helm upgrade` on the existing Helm release (revision 4) instead of `make install`. The `register-local-storage.yaml` hook was already processed.

**Standard flow:** Run `make install` on a fresh cluster — hook runs automatically.

---

### WA-2: AAP project patched via API to use fork branch

**Why:** The cluster was booted from a snapshot where `vmaas-ci/values.yaml` pinned the AAP project to upstream osac-aap main, which has no `local_lvms_storage` role. The Helm upgrade did not re-run the config-as-code job (idempotent).

**What was done:**
```bash
export KUBECONFIG=/root/.kube/demo.kubeconfig
kubectl port-forward -n osac-e2e-ci svc/osac-aap 8054:80 &
TOKEN=$(oc get secret -n osac-e2e-ci osac-aap-api-token -o jsonpath='{.data.token}' | base64 -d)

# Find project ID
curl -s -H "Authorization: Bearer $TOKEN" \
  http://localhost:8054/api/controller/v2/projects/ \
  | python3 -c 'import sys,json; [print(p["id"],p["name"],p.get("scm_url",""),p.get("scm_branch","")) for p in json.load(sys.stdin).get("results",[])]'

# Patch project (replace <ID>)
curl -s -X PATCH -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"scm_url":"https://github.com/zszabo-rh/osac-aap","scm_branch":"test/OSAC-3011-combined"}' \
  http://localhost:8054/api/controller/v2/projects/<ID>/
curl -s -X POST -H "Authorization: Bearer $TOKEN" \
  http://localhost:8054/api/controller/v2/projects/<ID>/update/
```

Note: Port-forward uses `svc/osac-aap` (gateway), not `svc/osac-aap-controller-service`. Auth is Bearer token from secret `osac-aap-api-token`, key `token`.

**Standard flow:** With `aap.configAsCode.projectGitUri/Branch` set correctly in `make install`, the config-as-code job syncs the right branch automatically.

---

### WA-3: Tenant `clusterStorageJobs` cleared manually (multiple times)

**Why:** The operator enters a backoff/requeue loop after a failed job and won't retrigger until the backoff expires. During debugging iterations we cleared the status field directly to force immediate retrigger rather than wait.

**What was done (repeated ~5 times during debugging):**
```bash
oc patch tenant -n osac-e2e-ci shared --type=json \
  -p '[{"op":"replace","path":"/status/clusterStorageJobs","value":[]}]' \
  --subresource=status
```

**Standard flow:** Not needed. Operator will eventually retrigger after backoff. During clean install the initial trigger succeeds on first attempt.

---

### WA-4: AAP fork branch force-pushed mid-session (two bug fixes)

**Why:** During E2E two bugs were discovered in the code being tested, requiring fixes pushed to the fork branch and AAP project re-synced.

**Bug 1 — Provider name validator rejected underscores:**
The `osac.service.storage_provider` validation regex `^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$` rejected `local_lvms` because underscores are not DNS label characters. But provider names map to Ansible role names (`osac.templates.local_lvms_storage`) which use underscores. Fixed: `[a-z0-9_-]`.

**Bug 2 — Playbooks ignored operator event tier definitions:**
After PR #375 merged, the operator sends `storage_tier_definitions` in the AAP event extra_vars. The playbooks still read only from `STORAGE_TIERS` env var and failed with "STORAGE_TIERS must be set". Fixed by cherry-picking the OSAC-3013 AAP event tier definitions commit onto the test branch.

After each fix:
```bash
# Trigger project sync
curl -s -X POST -H "Authorization: Bearer $TOKEN" \
  http://localhost:8054/api/controller/v2/projects/8/update/
sleep 20

# Verify sync picked up the new commit
curl -s -H "Authorization: Bearer $TOKEN" \
  http://localhost:8054/api/controller/v2/projects/8/ \
  | python3 -c 'import sys,json; d=json.load(sys.stdin); print("status:",d.get("status"),"rev:",d.get("scm_revision","")[:12])'

# Clear tenant status and retrigger (WA-3)
oc patch tenant -n osac-e2e-ci shared --type=json \
  -p '[{"op":"replace","path":"/status/clusterStorageJobs","value":[]}]' \
  --subresource=status
```

**Standard flow:** Both fixes are now committed to the PR branches. No manual patching needed.

---

### WA-5: `osac.openshift.io/tenant` annotation added to bootstrap tenant

**Why:** The `shared` tenant was created during cluster bootstrapping without the `osac.openshift.io/tenant` annotation. The Stage 2 playbooks were reading `tenant_name` from this annotation instead of `metadata.name`.

**What was done:**
```bash
oc annotate tenant -n osac-e2e-ci shared osac.openshift.io/tenant=shared --overwrite
```

**Fixed (2026-07-29, commit c8360480):** Both Stage 2 playbooks (`create/delete_tenant_cluster_storage`) now fall back to `metadata.name` when the annotation is absent. The annotation read is correct for ClusterOrder payloads (where `metadata.name` is the cluster name, not the tenant name) but redundant and incorrect for Tenant payloads (where `metadata.name` IS the tenant name). **This WA is no longer needed.**

---

## Demo script (post-merge, clean cluster)

For the Monday August 3 demo:

1. Boot fresh cluster with `cluster-tool`
2. `make install` with test image + fork branch overrides (or once PRs merge: just `make install` with upstream images)
3. Show StorageBackend + StorageTier auto-registered (no manual steps)
4. Onboard a tenant via the fulfillment API (`grpcurl ... Tenants/Create`)
5. Watch operator trigger AAP job automatically
6. Show `osac-<tenant>-local` StorageClass appears
7. Create a PVC, launch a pod, verify volume mounted

---

## Debugging tips

**Check AAP job output:**
```bash
TOKEN=$(oc get secret -n <ns> osac-aap-api-token -o jsonpath='{.data.token}' | base64 -d)
# Port-forward first (svc/osac-aap port 80 → localhost:8054)
curl -s -H "Authorization: Bearer $TOKEN" \
  http://localhost:8054/api/controller/v2/jobs/<ID>/stdout/?format=txt | tail -50
```

**Watch operator logs:**
```bash
oc logs -n <ns> deploy/osac-operator -f --since=30s \
  | grep -E 'storage|StorageClass|job|trigger|provision|clusterStorage'
```

**Check tenant conditions:**
```bash
oc get tenant -n <ns> <name> -o jsonpath='{.status.conditions}' \
  | python3 -c 'import sys,json; [print(c["type"],":",c["status"],"-",c["reason"]) for c in json.load(sys.stdin)]'
```

**Check recent AAP jobs:**
```bash
curl -s -H "Authorization: Bearer $TOKEN" \
  http://localhost:8054/api/controller/v2/jobs/?order_by=-id&page_size=5 \
  | python3 -c 'import sys,json; d=json.load(sys.stdin); [print(j["id"],"|",j["status"],"|",j.get("name",""),"|",str(j.get("started",""))[:19]) for j in d.get("results",[])]'
```
