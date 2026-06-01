# Demo Plan: Org Storage Provisioning Feature

## Context

The Org Storage Provisioning feature (MGMT-23828/23826) automates StorageClass lifecycle for OSAC tenants/organizations. When a Tenant CR is created, the operator triggers an AAP job that provisions tenant-specific StorageClasses. On deletion, a cleanup job removes them.

**Demo audience:** Mixed (engineering + leadership). 10-minute target, 15 with Q&A.

**Demo environment:** hypershift1 dev cluster, namespace `osac-zszabo`.

---

## Screen Layout

- **Left:** Terminal for `oc` commands
- **Right:** Terminal running the live monitor script

Start the monitor in the right terminal before the demo:
```bash
bash /home/zszabo/projects/claude-workspace-osac/artifacts/demo-monitor.sh
```

It shows: Tenant phase, conditions, provisioning jobs, and StorageClasses — all updating live.

---

## Pre-Demo Preparation (not shown)

1. Deploy custom operator image with our code
2. Ensure AAP project points to our fork branch with tenant playbooks
3. Ensure AAP templates exist (`osac-create-org`, `osac-delete-org`)
4. Ensure operator has `OSAC_PROVISIONING_PROVIDER=aap` and `OSAC_ENABLE_TENANT_CONTROLLER=true`
5. Clean up any leftover test resources (SCs, namespaces, Tenants)
6. Pre-create the namespace `demo-acme` (upstream prerequisite)
7. Start the monitor script in the right terminal

---

## Demo Flow

### 1. Intro (1-2 min) — Narration only

> "Today I'll show the automated storage provisioning feature for OSAC organizations. Currently, when a new organization is onboarded, an admin has to manually create a Kubernetes StorageClass with the right labels for the tenant. This is error-prone and doesn't scale.
>
> With this feature, the operator detects when a Tenant CR has no StorageClass and automatically triggers an AAP job to create one. By default it clones the cluster's default StorageClass, but CSPs can override which StorageClass to clone, add multiple storage tiers with different provisioners and parameters, and hook in custom backends — for example, to create a tenant project on a VAST storage array alongside the StorageClass.
>
> On deletion, everything is cleaned up automatically. Let me show you the end-to-end flow."

### 2. Show the Starting State (30 sec)

**Terminal:**
```bash
oc get sc -l "osac.openshift.io/tenant=demo-acme"
# → No resources found

oc get sc -o custom-columns='NAME:.metadata.name,PROVISIONER:.provisioner,DEFAULT:.metadata.annotations.storageclass\.kubernetes\.io/is-default-class'
```

**Narration:**
> "No StorageClasses exist for our demo org yet. The provisioning role will find the cluster's default StorageClass — the Ceph RBD one — and clone it with tenant-specific labels."

### 3. Create Tenant CR (1 min)

**Terminal:**
```bash
cat <<EOF | oc apply -n osac-zszabo --as system:admin -f -
apiVersion: osac.openshift.io/v1alpha1
kind: Tenant
metadata:
  name: demo-acme
  namespace: osac-zszabo
spec: {}
EOF
```

**Narration:**
> "I've created a Tenant CR for 'demo-acme'. Watch the monitor on the right — the operator will detect no StorageClass exists and trigger an AAP job."

### 4. Watch Provisioning (2-3 min) — Monitor focus

**Monitor (right terminal)** will show the progression:
- Phase: Progressing
- Conditions: NamespaceReady ✓, StorageClassReady ✗ (NotFound)
- Jobs: provision Running with AAP job ID
- StorageClasses: (none)

Then after ~30-60s:
- Phase: Ready
- Jobs: provision Succeeded
- StorageClasses: demo-acme-default appears

**Narration:**
> "You can see the Tenant is in Progressing phase. The conditions show the namespace was found on the cluster, but no StorageClass exists yet.
>
> The operator triggered an AAP job — you can see the job ID in the Jobs section. AAP is running the playbook that clones the cluster's default StorageClass with tenant-specific labels.
>
> [when phase changes to Ready] The job succeeded. The StorageClass appeared and the Tenant transitioned to Ready."

### 5. Verify StorageClass (30 sec)

**Terminal:**
```bash
oc get sc -l "osac.openshift.io/tenant=demo-acme" --show-labels
```

**Narration:**
> "The StorageClass 'demo-acme-default' was created with the correct labels — `osac.openshift.io/tenant=demo-acme` and `osac.openshift.io/storage-tier=default`. It inherited the Ceph RBD provisioner from the cluster default."

### 6. Show Extensibility Points (2 min) — File walk-through

**Terminal:**
```bash
cat collections/ansible_collections/osac/service/roles/tenant_storage_provision/defaults/main.yaml
```

**Narration:**
> "These are the two configuration knobs CSPs control through AAP extra variables or inventory — no code changes needed.
>
> `reference_sc` — which existing StorageClass to clone from. Empty means use the cluster default, which is what we just saw.
>
> `tiers` — the list of StorageClasses to create per tenant. Right now it's a single 'default' tier. A CSP offering tiered storage would add entries here — each can override the provisioner and parameters independently."

```bash
cat collections/ansible_collections/osac/service/roles/tenant_storage_provision/tasks/configure_backend.yaml
```

**Narration:**
> "For CSPs that need more than just a StorageClass — for example, creating a tenant project on a VAST array, setting quotas on Ceph — there's a backend extension point. CSPs override this file in their own fork or Ansible collection. Will Gordon is working on the first VAST backend integration."

### 7. Self-Healing — Delete the StorageClass (1-2 min)

**Terminal:**
```bash
oc delete sc demo-acme-default --as system:admin
```

**Monitor:** Watch phase drop to Progressing, new provision job appear, then Ready again.

**Narration:**
> "What if someone accidentally deletes the StorageClass? The operator watches for StorageClass changes. Watch the monitor — phase drops to Progressing, a new provision job is triggered automatically.
>
> [when Ready again] Self-healed. The StorageClass is back. No manual intervention needed."

### 8. Delete Tenant CR (1-2 min)

**Terminal:**
```bash
oc delete tenant.osac.openshift.io demo-acme -n osac-zszabo --as system:admin --wait=false
```

**Monitor:** Watch phase change to Deleting, deprovision job appear and run, SC disappear, then "Tenant deleted — cleanup complete."

**Terminal (after monitor shows deleted):**
```bash
oc get sc -l "osac.openshift.io/tenant=demo-acme" --no-headers
# → No resources found
```

**Narration:**
> "Deleting the tenant. The operator has a finalizer — it triggers a deprovisioning AAP job first to clean up the StorageClass.
>
> [watching monitor] You can see the Deleting phase and the deprovision job running. The StorageClass disappears... and the Tenant is fully deleted. Clean deletion, no orphaned resources."

### 9. Wrap-up (30 sec)

> "To recap: the operator automates the full StorageClass lifecycle — create on onboarding, self-heal on drift, clean up on deletion. CSPs customize through AAP variables and backend hooks. This integrates with Will's VAST work and the multi-tier StorageClass resolution."

---

## Deep Dive Topics (if questions extend to 15 min)

### Multi-tier storage
> "The operator already supports multi-tier StorageClass resolution — PR #199 just merged. It resolves multiple SCs per tenant, each with a `storage-tier` label. The Ansible role also supports a tier list. For example, a CSP could offer 'fast' on VAST CSI and 'standard' on Ceph, both provisioned automatically."

### VAST integration (Will's work)
> "Will is building the VAST backend that hooks into our `configure_backend.yaml` extension point. His playbook would call the VAST REST API to create tenant projects, VIP pools, and views. Our role handles the K8s StorageClass lifecycle, his handles the storage array lifecycle."

### Crash recovery
> "If the operator restarts during provisioning, the job ID is persisted in status.jobs. On restart, it picks up where it left off — polls the existing AAP job instead of creating a duplicate. Failed deprovisioning jobs block deletion to prevent orphaned storage."

### Why AAP and not just K8s controllers?
> "StorageClass creation is simple enough for a controller, but the real value is in the backend hooks. VAST, NetApp, Ceph — each needs different API calls, credentials, and error handling. Ansible is the right tool for that, and AAP gives us job tracking, audit trails, and crash recovery."

---

## Q&A Guide

**Q: What happens if the AAP job fails?**
> Tenant stays in Failed phase. Failed jobs don't auto-retry. A manual intervention (fixing the backend, then updating the CR) triggers a re-reconcile.

**Q: What if someone manually deletes the StorageClass after provisioning?**
> We just showed this — the SC watch triggers re-reconcile, operator detects missing SC, triggers new provision job. Self-healing.

**Q: What if there are zero or multiple default StorageClasses?**
> Zero: the role fails explicitly. Multiple: picks one (API-order dependent) — but multiple defaults is a Kubernetes misconfiguration.

**Q: Why does provisioning take 30-60 seconds?**
> The cloning itself is instant. Most time is AAP pod startup (~15s for scheduling + image pull) and the polling interval (up to 30s). Not the actual work.

**Q: The demo created a Ceph SC — what if the admin wants something different?**
> Two options: set `tenant_storage_provision_reference_sc` to a specific SC, or override per-tier provisioner/parameters in `tenant_storage_provision_tiers`. Configured via AAP extra_vars, no code changes.

**Q: Does this work with the EDA provider?**
> EDA doesn't support tenant provisioning. With EDA, the controller waits for manual SC creation. AAP Direct enables automation.

**Q: How does this interact with quotas?**
> Quotas are enforced at the backend level. The `configure_backend.yaml` hook is where CSPs set VAST/Ceph quotas. The StorageClass is a provisioner config, not a policy object.

**Q: When will multi-tier be ready?**
> The operator resolution is merged (PR #199+#204). The Ansible role already supports tier lists. They work end-to-end today.

**Q: Where does the tier list come from?**
> Ansible configuration — inventory or AAP extra_vars. CSPs define tiers at the platform level, not per-org.

**Q: What about the tenant → organization rename?**
> AAP templates already use 'org' names. CRD rename is part of the broader Organizations initiative.

**Q: How does Will's VAST work integrate?**
> Two hooks: override tier list for VAST CSI params, override `configure_backend.yaml` for VAST API calls. Our framework handles K8s, his handles the array.

---

## Cleanup (post-demo)

```bash
oc delete tenant.osac.openshift.io demo-acme -n osac-zszabo --as system:admin 2>/dev/null
oc delete namespace demo-acme --as system:admin 2>/dev/null
oc delete sc -l "osac.openshift.io/tenant=demo-acme" --as system:admin 2>/dev/null
```
