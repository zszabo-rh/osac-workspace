# Demo Plan: OSAC-3011 — Automatic Local Storage for Dev/CI

**Audience:** Internal team  
**Format:** Pre-recorded terminal (asciinema) + live narration  
**Target length:** 5-7 min recording, ~10 min with narration and Q&A  
**Date:** Monday 2026-08-03  
**Environment:** edge-17, cluster `osac-3011-demo`, namespace `osac-e2e-ci`

---

## What the cluster contains (vmaas-4-22 snapshot)

- OCP 4.22 SNO with LVMS pre-installed (`lvms-vg1` default StorageClass)
- OSAC stack pre-installed but **scaled to 0** (snapshot taken 13 days ago)
- `shared` and `system` tenants exist from the snapshot
- No StorageBackend / StorageTier CRDs yet — those ship with our updated images

**Demo approach:** `helm upgrade` with test images brings everything up, installs new CRDs, fires the register-local-storage hook, and transitions the cluster to the OSAC-3011 state. After upgrade we create a fresh `demo` tenant on camera to show the onboarding flow.

---

## Intro Speech (~2 min, spoken before recording starts)

> "I want to show you OSAC-3011 — automatic local storage provisioning for dev and CI environments.
>
> Two APIs that haven't been formally demoed yet: **StorageBackend** and **StorageTier**.
> StorageBackend represents a registered storage provider — VAST, Ceph, or in today's case LVMS, the local volume manager. StorageTier sits above it and defines what tenants see — it links one or more backends with a protocol and gives them a name like 'local'.
>
> The problem: dev and CI clusters have LVMS but nothing connects it to OSAC. After install an admin had to manually register a StorageBackend, create a StorageTier, and wait for the operator to provision StorageClasses for each tenant.
>
> OSAC-3011 eliminates all of that. A post-install hook registers everything automatically. And when a new tenant is onboarded, they get a StorageClass without any manual steps.
>
> Let me show you."

---

## Pre-Demo Setup (not shown in recording)

```bash
# edge-17
export KUBECONFIG=/root/.kube/osac-3011-demo.kubeconfig
cd /tmp/osac-installer
git fetch upstream && git rebase upstream/main   # ensure latest main

# Confirm clean state (no StorageBackend/Tier/demo-tenant yet)
oc get storagebackend,storagetier -n osac-e2e-ci 2>/dev/null || echo "clean ✓"
oc get tenant -n osac-e2e-ci --no-headers | grep -v shared | grep -v system || echo "no extra tenants ✓"
```

---

## Standard Developer Flow (cluster-tool)

```
1. cluster-tool boot vmaas-4-22 osac-3011-demo
2. VALUES_FILE=values/vmaas-ci/values.yaml python3 scripts/refresh-after-snapshot.py
3. Record demo (this script)
```

`refresh-after-snapshot.py` is the standard post-boot step for any cluster-tool cluster. It handles stale routes, cert SANs, Keycloak realm sync, secrets, TLS, then runs `helm upgrade` and waits for healthy pods. The `register-local-storage` Helm hook fires during the upgrade and auto-registers the StorageBackend + StorageTier.

**WIP:** Before running step 2, temporarily edit `values/vmaas-ci/values.yaml`:
```yaml
operator:
  image:
    repository: quay.io/rh-ee-zszabo/osac-operator
    tag: osac-3011-test
aap:
  configAsCode:
    projectGitUri: https://github.com/zszabo-rh/osac-aap.git
    projectGitBranch: test/OSAC-3011-combined
```
After PRs #397/#454/#474 merge: run step 2 with unmodified values. No edits needed.

---

## Recording Flow

### Scene 1 — Starting state (30s)

**What to show:** Cluster up, LVMS ready. Note that OSAC was already refreshed via `refresh-after-snapshot.py` before the recording started.

**Narrative:**
> "We have an OCP 4.22 SNO cluster that was booted from a cluster-tool snapshot. LVMS is pre-installed. After booting, we ran `refresh-after-snapshot.py` — the standard cluster-tool step — which brought OSAC up and fired the install hooks."

```bash
oc get lvmcluster -A --no-headers
oc get storageclass lvms-vg1 --no-headers
```

---

### Scene 2 — StorageBackend + StorageTier auto-registered (45s)

**What to show:** The `register-local-storage` Helm hook already fired during the refresh. Show both resources via the REST API.

**Narrative:**
> "The `register-local-storage` hook ran as part of the Helm upgrade. It called the fulfillment API and registered two resources: a StorageBackend with provider `local_lvms`, and a StorageTier named `local`. No admin did this manually."

*(WIP note in recording: "Values file temporarily has test operator image. After PRs merge: plain refresh, no edits.")*

---

### Scene 3 — StorageBackend + StorageTier auto-registered (45s)

**What to show:** The register-local-storage hook already ran as part of the upgrade. Show the two resources via the fulfillment REST API.

**Narrative:**
> "The installer hook fired during the upgrade and called the fulfillment API. Two new resources appeared automatically: a StorageBackend with provider `local_lvms`, and a StorageTier named `local`. These are the platform-level objects that connect LVMS to OSAC."

```bash
TOKEN=$(kubectl create token -n osac-e2e-ci admin)
ROUTE=$(oc get route -n osac-e2e-ci fulfillment-api -o jsonpath='{.spec.host}')

# StorageBackend
curl -sk -H "Authorization: Bearer $TOKEN" \
  https://$ROUTE/api/private/v1/storage_backends \
  | python3 -c "
import sys, json
for b in json.load(sys.stdin).get('items', []):
    print(f'  name:     {b[\"metadata\"][\"name\"]}')
    print(f'  provider: {b[\"spec\"][\"provider\"]}')
    print(f'  state:    {b[\"status\"][\"state\"]}')
"

# StorageTier
curl -sk -H "Authorization: Bearer $TOKEN" \
  https://$ROUTE/api/private/v1/storage_tiers \
  | python3 -c "
import sys, json
for t in json.load(sys.stdin).get('items', []):
    print(f'  name:  {t[\"metadata\"][\"name\"]}')
    print(f'  state: {t[\"status\"][\"state\"]}')
"
```

---

### Scene 4 — Onboard a new tenant (60s)

**What to show:** Create a `demo` tenant via the fulfillment API. Watch the operator detect it, trigger an AAP job, and flip all conditions to True. Then show the StorageClass that appeared.

**Narrative:**
> "Now let's onboard a tenant. I'll call the fulfillment API to create one named 'demo' and watch what happens."

```bash
# Create tenant
curl -sk -X POST -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  https://$ROUTE/api/private/v1/tenants \
  -d '{"metadata":{"name":"demo"},"spec":{}}' \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print('created:', d['metadata']['name'])"

# Watch conditions (poll every 5s until all True)
until oc get tenant -n osac-e2e-ci demo \
    -o jsonpath='{.status.conditions}' 2>/dev/null \
  | python3 -c "
import sys, json
cs = json.load(sys.stdin)
for c in cs:
    mark = '✓' if c['status'] == 'True' else '○'
    print(f'  {mark}  {c[\"type\"]}: {c[\"reason\"]}')
all_true = all(c['status'] == 'True' for c in cs)
exit(0 if all_true else 1)
" 2>/dev/null; do
  sleep 5
  echo "  waiting..."
done
echo "  All conditions True ✓"
```

---

### Scene 5 — StorageClass created, PVC works (30s)

**What to show:** The `osac-demo-local` StorageClass exists. Create a PVC from it.

**Narrative:**
> "All conditions True. The operator triggered AAP, AAP ran the `local_lvms_storage` role, and the StorageClass appeared. No admin touched anything."

```bash
oc get storageclass -l osac.openshift.io/tenant=demo --no-headers

# Create a PVC
oc apply -n osac-e2e-ci -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: demo-pvc
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: osac-demo-local
  resources:
    requests:
      storage: 1Gi
EOF

oc get pvc -n osac-e2e-ci demo-pvc
```

> "Pending — correct. LVMS uses WaitForFirstConsumer: the volume provisions when a workload schedules. The StorageClass is fully functional."

---

## Summary (spoken, 30s)

> "To recap: upgrade OSAC, get storage. The hook registered the backend and tier. Every tenant — existing or new — gets a per-tenant StorageClass automatically. Same operator dispatch pattern as VAST, different role.
>
> PRs: osac-operator#397, osac-aap#454, osac-installer#474. Targeting merge by end of this week."

---

## Q&A Guide

**Q: What about clusters without LVMS?**
> The hook is guarded by `lvms.enabled` in the installer values — it doesn't run if LVMS isn't present. VAST and other backends have their own registration paths.

**Q: Every new tenant gets a StorageClass?**
> Yes — the operator watches for new tenants and for the StorageBackend being Ready. No per-tenant configuration needed.

**Q: What does `osac-demo-local` mean — where do those names come from?**
> Pattern is `osac-<tenant>-<tier>`. 'demo' is the tenant name, 'local' is the StorageTier name. If you add a 'fast' tier, every tenant gets `osac-<tenant>-fast` too.

**Q: Multi-node clusters?**
> LVMS with WaitForFirstConsumer pins volumes to the scheduling node. For dev/CI SNO that's fine. Multi-node with local storage would use Ceph or VAST instead.

**Q: Relationship to VAST?**
> Same operator dispatch pattern, different AAP role. Provider name in the StorageBackend (`local_lvms` vs `vast`) determines which role AAP runs.

**Q: When do the WIP overrides go away?**
> Once #397, #454, #474 merge. After that: plain `make install-osac`.

---

## Recording Script

`demos_and_workflows/osac-3011-storage/record-demo.sh`

**Pre-recording checklist (edge-17):**
```bash
# 1. Cluster up and API accessible
export KUBECONFIG=/root/.kube/osac-3011-demo.kubeconfig
oc get nodes

# 2. Edit values file with test images (WIP — revert after PRs merge)
vi /tmp/osac-installer/values/vmaas-ci/values.yaml
# set operator.image.repository/tag and aap.configAsCode.projectGitUri/Branch

# 3. Run refresh (standard cluster-tool flow, ~10-15 min)
cd /tmp/osac-installer
VALUES_FILE=values/vmaas-ci/values.yaml python3 scripts/refresh-after-snapshot.py

# 4. Verify clean state for demo
oc get storageclass -l osac.openshift.io/tenant=demo --no-headers 2>/dev/null || echo "clean ✓"

# 5. Record
asciinema rec /tmp/osac-3011-demo.cast \
  --command "bash /home/zszabo/projects/osac-workspace/demos_and_workflows/osac-3011-storage/record-demo.sh" \
  --title "OSAC-3011: Automatic Local Storage"
```
