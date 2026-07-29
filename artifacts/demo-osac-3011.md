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

**What to show:** Clean cluster, no OSAC namespace, LVMS already present.

**Narration:**
> "Fresh cluster — OSAC not yet installed. LVMS is already set up on this node, you can see the LVMCluster is Ready and there's an existing `lvms-vg1` StorageClass. That's our raw material. Now, make install."

```bash
# LVMS is ready - raw material is here
oc get lvmcluster -A
oc get storageclass lvms-vg1
```

---

### Scene 2 — Run the Install (30s shown, ~15 min cut)

**What to show:** The install command, then jump-cut to completion.

**Narration (before cut):**
> "Running Phase 3 install. [Note to audience: we're using a pre-release test image and a fork branch here because the PRs aren't merged yet — after merge this will be a standard `make install` with no extra parameters.]"

**Narration (after cut, over hook logs):**
> "The install completed. You can see the `register-local-storage` hook ran — it called the fulfillment API, created the StorageBackend, linked it to a StorageTier. This is the new hook in the installer that fires automatically whenever LVMS is enabled."

```bash
# THE INSTALL COMMAND (⚠️ WIP: extra --set flags needed until PRs merge)
# After PR #397 (operator) and #454 (aap) merge → plain `make install-osac`
make install-osac VALUES_FILE=values/vmaas-ci/values.yaml \
  --set operator.image.repository=quay.io/rh-ee-zszabo/osac-operator \
  --set operator.image.tag=osac-3011-test \
  --set aap.configAsCode.projectGitUri=https://github.com/zszabo-rh/osac-aap.git \
  --set aap.configAsCode.projectGitBranch=test/OSAC-3011-combined

# [--- CUT: ~15 min wait ---]

# Show the hook log (already completed)
oc logs -n osac-e2e-ci job/register-local-storage 2>/dev/null || \
  echo "(hook completed and cleaned up — this is expected)"
```

---

### Scene 3 — StorageBackend and StorageTier Registered (45s)

**Narration:**
> "Let's look at what the hook created. Through the fulfillment API: a StorageBackend named 'local' with provider type local_lvms, and a StorageTier also named 'local' that references it. These are the two new resources that hadn't been shown before. The installer wired them up automatically."

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

### Scene 4 — Operator Triggers AAP, StorageClass Appears (60s)

**Narration:**
> "Now watch what the operator does. It saw the StorageBackend become Ready and immediately triggered an AAP job to provision storage for the 'shared' bootstrap tenant. The job ran the new `local_lvms_storage` role — which creates a StorageClass backed by topolvm.io, the LVMS CSI driver."

```bash
# Tenant conditions — operator already acted
oc get tenant -n osac-e2e-ci shared -o jsonpath='{.status.conditions}' \
  | python3 -c "
import sys,json
for c in json.load(sys.stdin):
    status = '✓' if c['status'] == 'True' else '✗'
    print(f\"  {status} {c['type']}: {c['reason']}\")
"

# The StorageClass that was created automatically
oc get storageclass -l osac.openshift.io/tenant=shared
```

**Narration:**
> "Three conditions True: StorageBackendReady, ClusterStorageReady, NamespaceReady. And the StorageClass `osac-shared-local` is there — with the topolvm.io provisioner, labelled to the 'shared' tenant and 'local' tier. A developer can use this immediately."

---

### Scene 5 — Developer Creates a PVC (30s)

**Narration:**
> "Let's verify a tenant can actually use it."

```bash
# Create a PVC using the auto-provisioned StorageClass
cat <<EOF | oc apply -n osac-e2e-ci -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: osac-demo-pvc
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: osac-shared-local
  resources:
    requests:
      storage: 1Gi
EOF

oc get pvc -n osac-e2e-ci osac-demo-pvc
```

**Narration:**
> "Status is Pending — that's correct and expected. LVMS uses `WaitForFirstConsumer` binding, which means the volume is provisioned when a pod actually schedules. The StorageClass works. No admin had to create it — the installer handled everything."

---

### Scene 6 — Wrap-up (15s)

**Narration:**
> "To recap: install OSAC on a node with LVMS, and storage is ready for tenants automatically. No manual StorageBackend registration, no StorageTier setup, no StorageClass creation. The same AAP dispatcher pattern that VAST and other storage providers use — just with a local LVMS role."

```bash
# Clean up the test PVC
oc delete pvc -n osac-e2e-ci osac-demo-pvc
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
