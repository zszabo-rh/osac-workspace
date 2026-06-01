# Training: Kubernetes Storage Architecture for OSAC CaaS

*Completed: 2026-04-23*
*Audience: OSAC engineers working on storage, quota, or CaaS features*
*Prerequisites: Understanding of OSAC fulfillment service architecture, hub/tenant cluster split*

---

## Training Overview

This training covers Kubernetes storage internals as they relate to OSAC's Cluster-as-a-Service storage design. It was created to prepare for the OSAC storage API coordination meeting (Will Gordon, Avishay Traeger, Zoltan Szabo, Lars Kellogg-Stedman) and to understand how storage quota enforcement connects to the general quota management framework.

**Lessons covered:**
1. Storage Primitives (PV, PVC, StorageClass)
2. CSI Drivers (Controller + Node Plugin architecture)
3. PVC Lifecycle (full request-to-mount flow)
4. HyperShift Architecture (split control plane)
5. Storage in Hosted Clusters (who controls what)
6. Three CaaS Storage Options (deep evaluation)
7. Connecting to Quota Work (positions and decisions)

---

## Lesson 1: Storage Primitives — PV, PVC, StorageClass

### Key Concepts

Three core Kubernetes storage objects:

| Object | What it is | Scope | Created by |
|--------|-----------|-------|------------|
| **PersistentVolume (PV)** | A specific chunk of real storage | Cluster-scoped | CSI driver (dynamic) or admin (static) |
| **PersistentVolumeClaim (PVC)** | A request for storage with requirements | Namespaced | Developer |
| **StorageClass** | A category of storage defining how to provision | Cluster-scoped | Admin (one-time) |

### Analogy: Corporate Parking Garage

- **PV** = a physical parking spot (numbered, specific size)
- **PVC** = a parking request ("I need a spot for an SUV")
- **StorageClass** = parking tier ("covered", "outdoor", "EV-charging")

### Static vs Dynamic Provisioning

**Static:** Admin pre-creates PVs, K8s matches PVCs to existing PVs.
**Dynamic (modern):** Admin creates StorageClasses, CSI driver creates PVs on the fly when PVCs are submitted.

```
Developer creates         StorageClass         CSI Driver         Backend
PVC: 80Gi, vast-ssd  ──▶  "vast-ssd"    ──▶  CreateVolume() ──▶  allocate 80Gi
                          provisioner:               │
                          csi.vastdata.com           ▼
                                              PV auto-created
                                              and bound to PVC
```

### OSAC Mapping

| K8s Concept | OSAC VMaaS | OSAC CaaS |
|-------------|-----------|-----------|
| StorageClass | Resolved per-tenant by osac-operator (labeled) | Installed in tenant clusters by OSAC automation |
| PVC | Created by Ansible (DataVolume) — tenant never sees it | Created by tenant developers via kubectl |
| PV | Dynamically provisioned on hub cluster | Dynamically provisioned by CSI in tenant cluster |

### Knowledge Check (with Answers)

**Q1:** A developer creates a PVC requesting 50 GiB with `storageClassName: vast-ssd`. Who creates the actual PV?
**A1:** The VAST CSI driver (specifically its controller component). The `external-provisioner` sidecar detects the new PVC, calls `CreateVolume()` on the driver, which provisions storage on VAST and creates the PV object.

**Q2:** In VMaaS, tenants never create PVCs — Ansible does. Why doesn't the same approach work for CaaS?
**A2:** In CaaS, OSAC hands the cluster to the tenant with a kubeconfig. From that point, tenants deploy apps and create PVCs directly through kubectl. OSAC can't pre-create storage for workloads it doesn't know about — CaaS storage is a day-2 operation.

**Q3:** StorageClasses are cluster-scoped. If two tenants share a cluster, can they see each other's StorageClasses?
**A3:** Yes — StorageClasses are visible cluster-wide. In OSAC's VMaaS (hub cluster), tenant isolation is achieved through labels (`osac.openshift.io/tenant`). In CaaS, each tenant gets their own cluster, so StorageClass visibility isn't a multi-tenancy concern.

---

## Lesson 2: CSI Drivers — The Bridge to Real Storage

### Key Concepts

CSI (Container Storage Interface) is a standard gRPC interface that decouples Kubernetes from storage vendors. A CSI driver has **two components**:

```
CSI Controller Pod (Deployment, 1 replica, any node):
┌────────────────────────────────────────────────────┐
│  Container 1: external-provisioner (K8s sidecar)   │
│    Watches for PVCs, calls CreateVolume on driver   │
│           │ gRPC (Unix socket)                      │
│           ▼                                        │
│  Container 2: vendor CSI plugin (e.g., VAST)        │
│    Implements CreateVolume, DeleteVolume, etc.      │
│                                                    │
│  Container 3: external-attacher (handles attach)    │
│  Container 4: external-resizer (handles expansion)  │
└────────────────────────────────────────────────────┘

CSI Node Plugin (DaemonSet, one per worker node):
┌────────────────────────────────────────────────────┐
│  Mounts/unmounts volumes on the local node          │
│  "Mount iscsi://vast/lun-42 at /var/lib/kubelet/…" │
└────────────────────────────────────────────────────┘
```

| Component | Job | Analogy |
|-----------|-----|---------|
| CSI Controller | Provisions/deletes volumes on storage backend | Purchasing department — orders equipment |
| CSI Node Plugin | Mounts volumes on local node for pods | Building maintenance — plugs in equipment |

### Sidecars

The CSI Controller pod contains K8s-provided sidecar containers that handle K8s API plumbing. The vendor only implements the CSI gRPC interface. Sidecars communicate with the driver via a shared Unix domain socket.

The **`external-provisioner`** sidecar is what triggers `CreateVolume()` — this is the key interception point for quota enforcement.

### Knowledge Check (with Answers)

**Q1:** To enforce storage quotas, which CSI component would you modify or intercept?
**A1:** The CSI Controller — it's the central point where `CreateVolume` decisions are made. The Node Plugin only mounts already-provisioned volumes; no quota decision needed at mount time.

**Q2:** In an OSAC CSI driver (Option 2), what does the Node Plugin do — go through OSAC or talk to the backend directly?
**A2:** The Node Plugin talks to the storage backend directly. Its job is purely mechanical (mount iSCSI LUN, NFS share, etc.). There's no quota decision at mount time, and the I/O path must be direct for performance.

**Q3:** In HyperShift, where does the `external-provisioner` sidecar run?
**A3:** On the hub cluster, as part of the tenant's control plane. In HyperShift, all control plane components (including CSI controller pods) run as pods on the hub.

---

## Lesson 3: The PVC Lifecycle — From Request to Mounted Volume

### Key Concepts

The PVC lifecycle has four phases with distinct enforcement opportunities:

| Phase | Steps | What happens | Quota enforcement point |
|-------|-------|-------------|----------------------|
| **Request** | 1-2 | Developer creates PVC, K8s stores it | **Webhook here** — reject before storage |
| **Provision** | 3-8 | Sidecar calls CSI Controller to create volume | **CSI Controller here** — reject in CreateVolume |
| **Bind** | 9-10 | PV created, bound to PVC | Too late — volume exists |
| **Mount** | 11-16 | Kubelet asks Node Plugin to mount | Way too late |

### Webhook Interception

A ValidatingAdmissionWebhook intercepts API requests **before** they're stored in etcd:

```
kubectl apply -f pvc.yaml
     │
     ▼
API Server pipeline:
  1. Parse
  2. Authentication
  3. Authorization
  4. Admission webhooks ◀── quota check HERE
  5. Store in etcd      ◀── only if webhook allows
```

Webhook rejection = clean UX (immediate error, no orphan PVC).
CSI rejection = poor UX (PVC stuck in Pending forever).

### Michael's Quote Clarified

"If we've gotten to the Kubernetes layer it's too late" — partially correct. Once past the admission phase (steps 9+, PV bound), enforcement is too late. But the webhook IS in the Kubernetes layer and is the ideal spot. The statement is really about not enforcing quota after storage is already provisioned.

### Knowledge Check (with Answers)

**Q1:** Webhook rejects a PVC with "quota exceeded." Has any storage been consumed?
**A1:** No. The webhook intercepts at steps 1-2, before the PVC reaches etcd. The CSI driver never runs, zero bytes consumed on the backend.

**Q2:** Without a webhook (CSI-only enforcement), what does the tenant see when over quota?
**A2:** PVC stuck in `Pending` state. Developer must run `kubectl describe pvc` and read events to find "ProvisioningFailed: quota exceeded." Poor user experience.

**Q3:** Was Michael right that "the Kubernetes layer is too late"?
**A3:** He was right about steps 9+ (after volume provisioned). But the webhook (steps 1-2) is IN the K8s layer and is the optimal enforcement point. The admission phase is "just in time," everything after is "too late."

---

## Lesson 4: HyperShift Architecture — The Split Control Plane

### Key Concepts

HyperShift splits a Kubernetes cluster into control plane (runs as pods on hub) and workers (separate machines):

```
HUB CLUSTER
┌──────────────────────────────────────────────────────┐
│  Tenant A namespace:                                 │
│  ┌──────┐ ┌────┐ ┌──────────┐ ┌─────────┐          │
│  │ API  │ │etcd│ │ctrl-mgr  │ │scheduler│          │
│  │server│ │    │ │          │ │         │          │
│  └──────┘ └────┘ └──────────┘ └─────────┘          │
│  ┌──────────────┐ ┌──────────────────────┐          │
│  │CSI controller│ │ webhooks, operators  │          │
│  └──────────────┘ └──────────────────────┘          │
│                                                      │
│  Tenant B namespace: (same pattern)                  │
└──────────────────────────┬───────────────────────────┘
                           │ (Konnectivity tunnel)
          ┌────────────────┼────────────────┐
          ▼                ▼                ▼
     ┌──────────┐   ┌──────────┐   ┌──────────┐
     │ Worker 1 │   │ Worker 2 │   │ Worker 3 │
     │(Tenant A)│   │(Tenant A)│   │(Tenant B)│
     │ kubelet  │   │ kubelet  │   │ kubelet  │
     │ CSI node │   │ CSI node │   │ CSI node │
     └──────────┘   └──────────┘   └──────────┘
```

### What Lives Where

| Component | Runs on | Tenant can touch? |
|-----------|---------|-------------------|
| API server, etcd, controllers | Hub (pods) | No |
| CSI Controller + sidecars | Hub (pods) | No |
| Control-plane webhooks | Hub (pods) | No |
| Kubelet, CSI Node Plugin | Workers | Yes |
| Tenant pods | Workers | Yes |

### Why This Matters for Storage

Both enforcement points (webhook and CSI controller) are on the hub, under OSAC's control. The tenant has full kubectl admin access but can't modify control-plane components. OSAC can install webhooks or replace CSI controllers without tenant knowledge.

### Communication

Workers connect to the hub via **Konnectivity** (persistent reverse tunnel). Workers initiate outbound connections — no inbound access required. All API traffic flows through the hub.

### Knowledge Check (with Answers)

**Q1:** Tenant runs `kubectl delete validatingwebhookconfiguration osac-quota-enforcer`. Does this remove the webhook?
**A1:** No. Control-plane-level webhooks are managed by HyperShift at the hub level, injected directly into the API server configuration. The tenant can delete webhook configs in their own cluster's API objects, but HCP-level webhooks are invisible to them.

**Q2:** Why can't the CSI Controller run on workers instead of the hub?
**A2:** The CSI Controller needs fast access to the K8s API server (to watch PVCs, create PVs). In HyperShift, the API server is on the hub. Co-locating the controller with the API server gives fast, local communication. Additionally, running on workers would give tenants access to tamper with it.

**Q3:** Which enforcement point gives the best combination of clean UX and tamper-resistance?
**A3:** The webhook — clean UX (immediate rejection), tamper-proof (HCP-level on hub), and doesn't require building a custom CSI driver. Works with any storage backend.

---

## Lesson 5: Storage in Hosted Clusters — Who Controls What

### Key Concepts: Four Layers of Storage Setup

```
Layer 1: INFRASTRUCTURE — Storage backend exists (VAST, Ceph)
  WHO: Datacenter ops. OSAC's role: none.

Layer 2: CLUSTER SETUP — Install CSI driver + StorageClasses
  WHO: OSAC (via AAP automation during provisioning)

Layer 3: TENANT ONBOARDING — Configure limits, backend namespaces
  WHO: OSAC (automated as part of tenant onboarding)

Layer 4: TENANT USAGE — Create PVCs for workloads
  WHO: Tenant developers (via kubectl)
```

### VMaaS vs CaaS Comparison

| Aspect | VMaaS | CaaS |
|--------|-------|------|
| Who creates storage resources? | OSAC (Ansible) | Tenant (kubectl) |
| Where does CSI driver run? | Hub cluster (shared) | Per-tenant control plane on hub |
| Who installs CSI driver? | Hub admin (one-time) | OSAC automation (per cluster) |
| How does OSAC know storage was consumed? | OSAC created it — in DB | Must observe/meter |
| Quota enforcement? | At fulfillment API level | At backend or webhook level |

### OSAC StorageClass vs K8s StorageClass

These are **different things** with a one-to-many relationship:

```
OSAC Fulfillment Service DB
  StorageClass: "vast-ssd"         ← source of truth (catalog)
        │
        │ AAP projects into:
        ├──▶ Tenant A's K8s cluster: StorageClass "vast-ssd"
        ├──▶ Tenant B's K8s cluster: StorageClass "vast-ssd"
        └──▶ Hub cluster (VMaaS):   StorageClass "vast-ssd"
                                      (derived copies)
```

### Knowledge Check (with Answers)

**Q1:** Does Tenant B get their own CSI driver, or share Tenant A's?
**A1:** Own CSI driver. Each tenant gets a separate HyperShift hosted cluster with its own control plane — separate API servers, etcd, CSI controller pods. Unlike VMaaS where all VMs share the hub's CSI.

**Q2:** Where does the OSAC fulfillment API StorageClass fit vs the K8s StorageClass?
**A2:** The OSAC StorageClass lives in the fulfillment service database (a gRPC/REST resource, like NetworkClass). K8s StorageClasses are derived copies created in individual clusters by OSAC automation. OSAC's catalog is the source of truth.

**Q3:** For quota, which usage tracking option works best with the `/v1/usage` endpoint?
**A3:** All three options (webhook reporting, polling, CSI reporting) can update the fulfillment DB. The webhook gives synchronous, fail-closed behavior. But the key point is: the `/v1/usage` endpoint doesn't care about the ingestion mechanism — it reads the DB regardless of how data got there.

---

## Lesson 6: The Three OSAC CaaS Options — Deep Evaluation

### Requirements

| Requirement | Priority |
|-------------|----------|
| R1: Tenants use standard kubectl | Must have |
| R2: OSAC can enforce storage quotas | Must have |
| R3: OSAC can track usage for metering | Must have |
| R4: Works with multiple backends | Must have |
| R5: Tenant cannot bypass controls | Must have |
| R6: Minimal engineering effort | Should have |
| R7: Admin onboarding is simple | Should have |

### Comparison

```
                 ┌──────────────┬──────────────┬──────────────┐
                 │  Option 1    │  Option 2    │  Option 3    │
                 │  Provider    │  OSAC CSI    │  Provider +  │
                 │  CSI only    │  (custom)    │  HCP Webhook │
──────────────── ┼──────────────┼──────────────┼──────────────┤
 Quota enforce   │      No      │     Yes      │     Yes      │
 Usage tracking  │      No      │     Yes      │     Yes      │
 Backend agnostic│     Yes      │   Partial    │     Yes      │
 Tamper-proof    │     N/A      │     Yes      │     Yes      │
 Standard kubectl│     Yes      │     Yes      │     Yes      │
 Engineering cost│     Tiny     │     Huge     │    Small     │
 Proven at scale │     Yes      │      No      │  Yes (ROSA)  │
──────────────── ┼──────────────┼──────────────┼──────────────┤
 Verdict         │  Use as base │    Avoid     │  Recommended │
                 └──────────────┴──────────────┴──────────────┘
```

### Knowledge Check (with Answers)

**Q1:** Why is Option 2 (OSAC CSI) NOT backend-agnostic?
**A1:** Because the OSAC CSI controller replaces vendor drivers, so it must implement `CreateVolume` for each backend — backend-specific provisioning code. The learner also noted a valid alternative: a CSI proxy pattern that wraps the vendor driver. This reduces backend-specific code but adds operational complexity (two CSI controllers per cluster).

**Q2:** Should the webhook maintain a local usage counter or query the OSAC API?
**A2:** Query the OSAC API. Local counters get out of sync. Single source of truth. If OSAC API is down, fail-closed (reject PVCs until recovery). Consistent with the existing quota model.

**Q3:** Can VMaaS and CaaS quota enforcement coexist?
**A3:** Yes. VMaaS quota: fulfillment API gating (before CR creation). CaaS quota: webhook or backend enforcement (during PVC creation). Different enforcement points, same quota backend. The webhook/backend reports to the same `/v1/usage` data store.

---

## Lesson 7: Connecting to Quota Work — Updated with Apr 22 Decisions

### What the Team Decided (Apr 22)

The HCP webhook approach (Option 3) was **rejected for CaaS** because:
- HCP webhooks don't cover sovereign/SNO deployments
- CSI proxy can be disabled by tenants in some configurations

**Instead: Provider-level enforcement (Option 4)**
- Push quotas INTO the storage backend (e.g., VAST soft/hard limits per tenant project)
- Ansible sets limits via provider APIs
- Multi-tenancy handled at backend level (encryption, QoS, quotas)
- Infrastructure-agnostic — works regardless of K8s distribution or deployment model

For **VMaaS** (hub cluster, OSAC-controlled): CSI proxy, admission webhook, or eventual consistency — TBD per deployment.

### Provider-Level Enforcement Flow

```
Tenant: kubectl create pvc 50Gi
    │
    ▼
CSI Controller (vendor, unmodified) ──▶ VAST API
                                           │
                                    ┌──────┴──────┐
                                    │ Tenant A    │
                                    │ Hard limit: │
                                    │ 500Gi       │ ◀── set by OSAC
                                    │ Used: 450Gi │     via Ansible
                                    │             │
                                    │ 450+50=500  │
                                    │ → ALLOW     │
                                    └─────────────┘
```

### Ansible-First Strategy

- Phase 1 (MVP): Ansible playbooks for storage setup/provisioning. No API endpoints.
- Phase 2: Formal StorageClass/StorageTier API endpoints (following NetworkClass pattern) once e2e workflow proven.

### Impact on Quota Design

- Quota v1 (VMaaS) is **not blocked** by any storage decisions
- CaaS storage quota is v2, depends on: Ansible Phase 1 → metering → Storage API
- `/v1/usage` will eventually need to aggregate OSAC-created resources + backend-reported usage
- Metering (Michael's proposal) is the prerequisite for CaaS storage usage tracking

### Knowledge Check (with Answers)

**Q1:** Explain VMaaS vs CaaS storage quota enforcement in one sentence.
**A1:** "VMaaS storage quota is enforced by OSAC at resource creation time (day 1), while CaaS storage quota is enforced by the storage backend itself when tenants create PVCs (day 2)."

**Q2:** The team rejected HCP webhooks for CaaS. Where are webhooks still applicable?
**A2:** VMaaS on the hub cluster. VMs run on the hub, which is always a full OpenShift cluster regardless of deployment model. Admission webhooks work universally on the hub — the HCP limitation only applies to hosted cluster control planes.

**Q3:** Does the Ansible-first strategy (no API endpoints initially) block quota v1?
**A3:** No. Quota v1 covers VMaaS resources (CPU, memory, disk) where OSAC controls the lifecycle via approved_spec. CaaS storage depends on Ansible Phase 1 proving out, then metering, then API — none of which block VMaaS quota.

---

## Clarifications and Detours

### Pre-Training Q&A (important context)

Before the formal training, several foundational questions were addressed:

1. **"How do we prevent tenants from circumventing the fulfillment API?"**
   - Tenants never have kubeconfig to the hub cluster. VMaaS tenants get SSH/console to their VMs. CaaS tenants get kubeconfig to their own cluster (not the hub). There's nothing to circumvent — the fulfillment API manages infrastructure, kubectl manages workloads inside the cluster.

2. **"Does OSAC need to re-implement the K8s API?"**
   - No. OSAC manages infrastructure (create clusters, VMs, storage backends). Tenants use standard kubectl inside their clusters. Enforcement is underneath (CSI drivers, webhooks, backend limits).

3. **"Where do PVs physically live for CaaS clusters?"**
   - On tenant worker nodes (local storage) or on external storage arrays (VAST, Ceph) accessed over the network. NOT on the hub cluster. The hub stores control plane data (etcd), not application data.

### Learner's CSI Proxy Insight (Lesson 6)

The learner proposed an intermediate option: an OSAC CSI proxy that wraps the vendor driver — checks quota first, then forwards to the original driver. This is architecturally valid (CSI proxy pattern exists) but was noted as more operationally complex than a webhook while converging toward the same goal.

---

## Key Takeaways (Ranked by Importance)

1. **VMaaS and CaaS have fundamentally different storage control models.** VMaaS: OSAC creates all storage (day 1). CaaS: tenants create their own storage (day 2). This drives every other decision.

2. **Provider-level enforcement was chosen for CaaS** because it works regardless of K8s distribution, deployment model (HyperShift, sovereign, SNO), and doesn't require custom K8s components.

3. **The quota architecture doesn't need to change for CaaS storage.** The `/v1/usage` endpoint just needs a new data source (backend-reported usage). The gating model, quota service contract, and enforcement logic are unchanged.

4. **CSI drivers have two components** (Controller and Node Plugin). Quota enforcement targets the Controller; the Node Plugin just does mounts. In HyperShift, the Controller runs on the hub (tamper-proof).

5. **Admission webhooks intercept PVC requests before storage is provisioned** — clean UX, immediate rejection. This is the optimal enforcement point for VMaaS on the hub cluster, even though it was rejected for CaaS broadly.

6. **OSAC StorageClass (fulfillment DB) and K8s StorageClass (cluster object) are different things** with a one-to-many relationship. The OSAC catalog is the source of truth; K8s objects are derived copies.

7. **Metering is the prerequisite for CaaS storage quota.** Without usage data flowing back from storage backends, quota can't be enforced. Michael's metering proposal is critical.

---

## Further Reading / Next Steps

1. **CSI Specification:** https://github.com/container-storage-interface/spec — the full gRPC interface definition
2. **HyperShift documentation:** https://hypershift-docs.netlify.app/ — how hosted clusters work
3. **Kubernetes Storage Concepts:** https://kubernetes.io/docs/concepts/storage/ — official K8s docs
4. **OSAC NetworkClass proto:** `fulfillment-service/proto/public/osac/public/v1/network_class_type.proto` — the pattern StorageClass API will follow
5. **OSAC Tenant controller:** `osac-operator/internal/controller/tenant_controller.go` (lines 221-304) — current storage class resolution logic
6. **Akshay's storage tier EP:** MGMT-23669 — the active enhancement proposal for multi-tier storage
7. **Will Gordon's storage investigation:** Track his findings on reusing the general quota framework for storage
