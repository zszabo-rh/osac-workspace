# Demo Plan: OSAC-3011 — Automatic Local Storage for Dev/CI

**Audience:** Internal team  
**Format:** Pre-recorded terminal (asciinema) + live narration  
**Target length:** 5-7 min recording, ~10 min with narration and Q&A  
**Date:** Monday 2026-08-03  
**Environment:** edge-17, cluster `osac-3011-demo`, namespace `osac-e2e-ci`

---

## Intro Speech (~2 min, spoken before recording starts)

> "I want to show you OSAC-3011 — automatic local storage provisioning for dev and CI environments.
>
> First, a bit of background on two APIs that haven't been formally demoed yet, even though they've been in the platform for a while: **StorageBackend** and **StorageTier**.
>
> StorageBackend represents a registered storage provider — VAST, Ceph, or in today's case, LVMS, the local volume manager. It holds the endpoint, credentials, and provider type. StorageTier sits above it and defines what tenants see — it links one or more backends with a protocol (block, file) and gives them a name like 'local' or 'fast'.
>
> The problem we're solving: dev and CI environments running on bare metal have LVMS available, but today nothing connects that to OSAC. After install, an admin had to manually register a StorageBackend, create a StorageTier, and wait for the operator to provision StorageClasses for each tenant. That's 3 manual steps before storage works.
>
> The solution in OSAC-3011: a post-install hook in the installer that automatically registers a 'local' StorageBackend and StorageTier when LVMS is present. From that point on, any tenant that exists or gets created receives an `osac-<tenant>-local` StorageClass automatically — no manual steps.
>
> Let me show you what this looks like end to end."

---

## Screen Layout

- **Single terminal** — the recording script drives everything
- Optionally split: left for commands, right for a live monitor watching tenant conditions

---

## Pre-Demo Setup (not shown in recording)

```bash
# On edge-17
export KUBECONFIG=/root/.kube/osac-3011-demo.kubeconfig
cd /tmp/osac-installer

# Confirm clean state
oc get namespace osac-e2e-ci 2>/dev/null || echo "namespace clear ✓"
oc get storageclass | grep osac || echo "no OSAC storage classes ✓"
```

---

## Recording Flow

### Scene 1 — The Starting State (20s)

**What to show:** After install — LVMS ready, StorageBackend and StorageTier already registered by the hook, but no tenant StorageClasses yet.

**Narration:**
> "OSAC is installed, LVMS is running. The install hook already fired and registered a 'local' StorageBackend and StorageTier. Let me show you those."

```bash
# LVMS is ready
oc get lvmcluster -A --no-headers
oc get storageclass lvms-vg1 --no-headers
```

---

### Scene 2 — StorageBackend and StorageTier Registered (45s)

**Narration:**
> "The installer hook called the fulfillment API and registered two resources automatically: a StorageBackend with provider `local_lvms`, and a StorageTier that references it. These are the platform-level objects that didn't exist before and hadn't been shown yet."

```bash
# Auth
TOKEN=$(kubectl create token -n osac-e2e-ci admin)
ROUTE=$(oc get route -n osac-e2e-ci fulfillment-api -o jsonpath='{.spec.host}')

# StorageBackend — the registered LVMS provider
curl -sk -H "Authorization: Bearer $TOKEN" \
  https://$ROUTE/api/private/v1/storage_backends \
  | python3 -c "
import sys,json
items = json.load(sys.stdin).get('items',[])
for b in items:
    print(f\"  name:     {b['metadata']['name']}\")
    print(f\"  provider: {b['spec']['provider']}\")
    print(f\"  state:    {b['status']['state']}\")
"

# StorageTier — what tenants see
curl -sk -H "Authorization: Bearer $TOKEN" \
  https://$ROUTE/api/private/v1/storage_tiers \
  | python3 -c "
import sys,json
items = json.load(sys.stdin).get('items',[])
for t in items:
    print(f\"  name:  {t['metadata']['name']}\")
    print(f\"  state: {t['status']['state']}\")
"
```

---

### Scene 3 — No Tenant StorageClasses Yet (10s)

**Narration:**
> "The backend is registered, but no tenant StorageClasses exist yet — because no tenant has been onboarded. That's next."

```bash
# No OSAC storage classes yet
oc get storageclass -l app.kubernetes.io/managed-by=osac-aap --no-headers \
  2>/dev/null || echo "No tenant StorageClasses yet."
```

---

### Scene 4 — Onboard a Tenant (60s)

**Narration:**
> "Onboarding a tenant via the fulfillment API. The operator will detect the new tenant, see the 'local' StorageBackend is Ready, and trigger an AAP job to create the per-tenant StorageClass."

```bash
# Create a tenant via the fulfillment API
curl -sk -X POST -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  https://$ROUTE/api/private/v1/tenants \
  -d '{"metadata":{"name":"demo"},"spec":{}}' \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print('tenant:', d.get('metadata',{}).get('name'))"

# Watch operator trigger AAP and tenant conditions update
watch -n 3 "
  oc get tenant -n osac-e2e-ci demo -o jsonpath='{.status.conditions}' 2>/dev/null \
    | python3 -c \"import sys,json; [print(f'  {\\\"✓\\\" if c[\\\"status\\\"]==\\\"True\\\" else \\\"○\\\"}  {c[\\\"type\\\"]}: {c[\\\"reason\\\"]}') for c in json.load(sys.stdin)]\" 2>/dev/null
"
```

---

### Scene 5 — StorageClass Created Automatically (20s)

**Narration:**
> "All conditions True. And there's the StorageClass — `osac-demo-local`, topolvm.io provisioner, labeled to the 'demo' tenant and 'local' tier. Created automatically. No admin had to touch anything after install."

```bash
oc get storageclass -l osac.openshift.io/tenant=demo
```

---

### Scene 6 — Create a PVC and a VM (90s)

**Narration:**
> "Let's use it. First a PVC to verify the StorageClass works, then a VM with a boot disk from LVMS-backed storage."

```bash
# PVC
cat <<EOF | oc apply -n osac-e2e-ci -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: osac-demo-pvc
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: osac-demo-local
  resources:
    requests:
      storage: 5Gi
EOF
oc get pvc -n osac-e2e-ci osac-demo-pvc
```

**Narration:**
> "PVC is Pending — correct, LVMS uses WaitForFirstConsumer. The volume provisions when a pod schedules. Let's boot a VM and watch the volume bind."

```bash
# VM using LVMS-backed storage (DataVolume from existing Fedora image)
cat <<EOF | oc apply -n osac-e2e-ci -f -
apiVersion: kubevirt.io/v1
kind: VirtualMachine
metadata:
  name: demo-vm
  labels:
    osac.openshift.io/tenant: demo
spec:
  running: true
  template:
    spec:
      domain:
        cpu:
          cores: 1
        memory:
          guest: 1Gi
        devices:
          disks:
          - name: boot
            disk:
              bus: virtio
      volumes:
      - name: boot
        persistentVolumeClaim:
          claimName: osac-demo-pvc
EOF

# Watch PVC bind as VM schedules
oc get pvc -n osac-e2e-ci osac-demo-pvc -w
```

**Narration:**
> "PVC bound — LVMS provisioned the volume when the VM pod scheduled. The VM is booting from local storage."

---

### Scene 7 — Wrap-up (15s)

**Narration:**
> "To recap: install OSAC, get storage. No manual steps. The same dispatcher pattern as VAST, just a local LVMS role. Backend, tier, StorageClass, PVC, VM — all wired up automatically."

```bash
# Cleanup
oc delete vm -n osac-e2e-ci demo-vm
oc delete pvc -n osac-e2e-ci osac-demo-pvc
oc delete tenant -n osac-e2e-ci demo 2>/dev/null || true
```

---

## Q&A Guide

**Q: What about nodes without LVMS?**
> The hook is guarded by `lvms.enabled` in the installer values — it simply doesn't run if LVMS isn't enabled. VAST and other backends have their own registration paths.

**Q: Will every new tenant get a StorageClass?**
> Yes — the operator watches for new tenants and for the StorageBackend becoming Ready. Any tenant created after install, or existing tenants (like 'shared'), get provisioned automatically. There's no per-tenant configuration needed.

**Q: The StorageClass is `osac-shared-local` — what about other tenants?**
> Each tenant gets `osac-<tenant-name>-local`. The 'local' part comes from the StorageTier name. If you add more tiers (e.g., 'fast', 'archive'), each tenant gets one StorageClass per tier.

**Q: What happens on a multi-node cluster?**
> LVMS with `WaitForFirstConsumer` pins volumes to the node where the pod schedules. For single-node dev/CI that's fine. For multi-node with local storage you'd want a different backend (Ceph/VAST). This feature targets dev/CI explicitly.

**Q: What's the relationship to the VAST work?**
> Same operator pattern, different AAP role. The operator dispatches based on the provider name — `local_lvms` → `local_lvms_storage` role, `vast` → `vast_storage` role. Adding a new storage backend is adding an AAP role and a StorageBackend registration.

**Q: The WIP flags in the install command — when will those be gone?**
> Once PRs #397 (operator), #454 (aap), and #474 (installer) merge — targeting end of July. After that it's a plain `make install`.

---

## Recording Script

The actual recording script is at:
`/home/zszabo/projects/osac-workspace/demos_and_workflows/osac-3011-storage/record-demo.sh`

Run on edge-17:
```bash
export KUBECONFIG=/root/.kube/osac-3011-demo.kubeconfig
cd /tmp/osac-installer
asciinema rec /tmp/osac-3011-demo.cast \
  --command "/home/zszabo/projects/osac-workspace/demos_and_workflows/osac-3011-storage/record-demo.sh" \
  --title "OSAC-3011: Automatic Local Storage"
```
