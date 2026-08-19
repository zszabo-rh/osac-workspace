# OSAC-3702 — Jira ticket drafts (LVMS as CSI backend, Option A)

All under Epic **OSAC-3702**. Owner: Zoltan (all). No personal names in any ticket. Descriptions are
self-contained at the behavior/interface level; file paths, code snippets, and module references live
only in the design doc (handed to implementers separately) and are intentionally absent here.

Legend: **CREATE** = new task · **REPURPOSE** = rewrite existing · **CLOSE** = resolve.

---

## CLOSE — OSAC-3404 (Explore LVMS local storage as an OSAC CSI driver backend)
**Resolution comment:**
> Exploration complete. Decision: **Option A (full chain), VMaaS/single-cluster first.** A tenant PVC
> on the local tier is routed through the OSAC CSI driver → fulfillment (tier resolution, inventory,
> policy) → operator, which provisions a node-local volume on the scheduled node. Implementation is
> decomposed into tasks under OSAC-3702. Closing as done.

---

## CREATE — T1 · Add optional volume topology to the private Volume API
**Component:** Storage / fulfillment-service
**Description:**
Node-local storage tiers must provision a volume on the specific node where the consuming pod is
scheduled, so the Volume API needs to carry that node. Add an **optional** `VolumeTopology` message
with a single `node` field (the scheduler-selected node identifier) to the private `VolumeSpec` and to
the `CreateVolume` request. The field is additive and unset for network backends (no behavior change).
Use a fresh field number (do not reuse any removed field), regenerate code, and update builders/mappers
so the value round-trips through create and read.
**Acceptance criteria:**
- Proto lint passes; generated code compiles.
- `CreateVolume` accepts requests with and without topology; the value persists and is returned on Get.
- Existing network-backend create behavior is unchanged (covered by a regression test).
**Depends on:** —

## CREATE — T2 · Enforce node-local provisioning rules in the Volume API
**Component:** fulfillment-service
**Description:**
With the topology field available, the Volume API must (a) carry the node through to the Volume CR and
(b) guarantee node-local tiers are never asked to provision without a node — which is structurally
impossible for node-local storage. On `CreateVolume`, after tier resolution: if the resolved backend
is node-local and no topology node was supplied, reject with `FailedPrecondition` (this forbids
"provision-in-advance"/API-first for node-local tiers). Otherwise carry the topology value into the
persisted record and into the Volume CR. Determine node-locality from the resolved backend's provider
so the rule is generic, not tied to a specific tier name.
**Acceptance criteria:**
- Node-local tier + no node → `FailedPrecondition` with a clear message.
- Node-local tier + node → record and Volume CR carry the node.
- Network tier is unaffected, with or without a node.
**Depends on:** T1

## CREATE — T3 · Add optional topology to the Volume CRD
**Component:** osac-operator
**Description:**
Mirror the Volume API topology field on the Volume custom resource so the operator's Volume controller
can read the scheduler-selected node. Add an optional topology field (node) to the Volume CRD spec;
additive, no controller-flow change. Regenerate CRD manifests and deepcopy.
**Acceptance criteria:**
- CRD applies; a Volume CR validates with and without topology.
- The field is readable by the Volume controller.
**Depends on:** T1 (shape consistency)

## CREATE — T4 · Add a node-local vendor provisioner to the operator Volume controller
**Component:** osac-operator
**Description:**
The operator provisions volumes by dispatching to a vendor provisioner chosen by the resolved storage
backend's provider. Network backends call a vendor CSI controller over gRPC; node-local storage has no
network-callable controller and no credentials, so it is provisioned directly on the target cluster's
node-local storage subsystem. Add a new vendor provisioner, selected when the backend provider
indicates node-local storage (LVMS).

Implementation plan (current — the create mechanism is pending a final call between direct resource
creation and proxying; keep the provisioner interface stable either way): the provisioner **creates a
node-local LogicalVolume resource** on the target cluster, targeting the node from the Volume topology
and the device class carried in the volume parameters, polls until the volume is ready, and returns the
resulting vendor volume id (so the node plugin can mount it). Delete removes the resource. On
insufficient node capacity, return `ResourceExhausted` so the CSI layer can trigger rescheduling. The
provisioner reaches the target cluster through an injectable client — in-cluster for the
single-cluster (VMaaS) case; the remote/multi-cluster client is out of scope here (tracked separately).
No publish/attach path is required for node-local backends (handled as a no-op at the CSI layer).
**Acceptance criteria:**
- A Volume on a node-local tier is provisioned end to end (resource created on the target node, becomes
  ready, vendor volume id recorded) and deleted cleanly.
- Capacity failure surfaces as `ResourceExhausted`.
- Network-backend provisioning is unchanged.
**Depends on:** T3

## CREATE — T5 · Add volume topology support to the OSAC CSI controller
**Component:** osac-csi-driver
**Description:**
For node-local tiers using WaitForFirstConsumer, the CSI controller must declare it is topology-aware,
pass the scheduler-selected node into the Volume API, and pin the resulting PV to that node. Advertise
the volume-accessibility-constraints controller capability; in CreateVolume, extract the preferred
topology node and pass it to the fulfillment create call; return the accessible topology on the created
volume so the PV gets node affinity; ensure the vendor volume id from provisioning is present in the
volume context for the node plugin.
**Acceptance criteria:**
- The controller reports the accessibility capability.
- A WaitForFirstConsumer PVC provisions on the scheduled node; its PV carries node affinity to that node.
- Network-backend provisioning is unaffected.
**Depends on:** T1

## CREATE — T6 · Route node-local mounts through the topolvm node socket
**Component:** osac-csi-driver
**Description:**
The OSAC CSI node plugin mounts by proxying to a vendor node socket selected by the backend. Node-local
(LVMS) mounts must route to the topolvm node socket, and each node must advertise the topology domain.
Have NodeGetInfo advertise the node's topology segment so a cluster-wide topology domain exists; mount
the topolvm node socket into the OSAC CSI node container and register the node-local backend's socket in
the node plugin's vendor socket map. Reuse the existing backend-keyed socket routing — no new mechanism.
**Acceptance criteria:**
- NodeGetInfo returns the node topology segment.
- A node-local PVC mounts via the topolvm node socket; write then read back succeeds.
**Depends on:** — (end-to-end exercise needs T1–T5)

## CREATE — T7 · Operator RBAC and routing config for node-local storage
**Component:** osac-operator (deployment)
**Description:**
The node-local provisioner creates LogicalVolume resources and the node-local backend must be treated
as needing no controller attach. Grant the operator the RBAC to manage LogicalVolume resources on the
target cluster; configure the node-local backend so the CSI controller treats publish/unpublish as a
no-op (existing node-local sentinel) and so the routing keys resolve for the node-local backend.
**Acceptance criteria:**
- The operator can create and delete LogicalVolume resources.
- Publish/unpublish for the node-local backend is a no-op (no error, no vendor call).
**Depends on:** T4

## CREATE — T8 · Local StorageClass with WaitForFirstConsumer and device-class parameter
**Component:** osac-aap
**Description:**
The local storage tier's StorageClass must defer provisioning until a pod is scheduled and must tell the
provisioner which device class / volume group to use. Ensure the local StorageClass uses the OSAC CSI
provisioner, sets volumeBindingMode to WaitForFirstConsumer, and carries the device class via the
OSAC-namespaced parameter `osac.io/device-class`. Keep creation idempotent and consistent with existing
local-storage onboarding.
**Acceptance criteria:**
- The created StorageClass has the OSAC CSI provisioner, WaitForFirstConsumer, and the device-class
  parameter.
- A PVC against it remains Pending until a pod consumes it.
**Depends on:** —

## REPURPOSE — OSAC-3711 → T9 · VMaaS: end-to-end validation of node-local storage via the OSAC CSI path
**Component:** Storage / test
**New summary:** VMaaS: validate node-local (LVMS) storage end-to-end via the OSAC CSI path
**New description:**
The LVMS operator and LVMCluster install on the management/workload cluster is already delivered; this
task validates the CSI-path flow on a VMaaS/single-cluster setup (hub == tenant). Validate end to end:
a PVC on the local tier (WaitForFirstConsumer) plus a consuming pod triggers provisioning on the
scheduled node; the OSAC Volume inventory record is present; the pod writes and reads back data; deleting
the PVC removes both the node-local volume and the OSAC inventory record.
**Acceptance criteria:**
- The full flow passes; both the OSAC inventory record and the node-local volume are cleaned up on delete.
**Depends on:** T1–T8

---

## Deferred trackers (lightweight — detail later)

## REPURPOSE — OSAC-3710 → D1 · CaaS: node-local storage via a remote target-cluster client
**New summary:** CaaS: node-local (LVMS) storage via a remote target-cluster client
**New description (tracker):**
Extend node-local storage to CaaS, where the guest cluster is separate from the hub. The operator's
node-local provisioner must target the guest cluster (where topolvm and the workers run) via a remote
client built from the guest admin kubeconfig, reusing the existing dispatcher remote-kubeconfig
mechanism; add guest-cluster RBAC and CaaS end-to-end coverage. Deferred until the VMaaS/single-cluster
path lands. Detail to follow.
**Depends on:** T4 (client seam)

## CREATE — D2 · Multi-node capacity awareness for node-local storage (tracker)
**Description (tracker):**
Without capacity-aware scheduling, WaitForFirstConsumer can bind a pod to a node lacking free space; the
provisioner returns ResourceExhausted and the pod reschedules (blind retry, possible thrash). To make
placement first-try correct on multi-node clusters, implement capacity reporting and publish per-node
storage capacity for the OSAC CSI driver. Not needed for single-node / SNO dev. Detail to follow.
**Depends on:** T5

## CREATE — D4 · Volume expansion for node-local volumes (tracker)
**Description (tracker):**
Support expansion of node-local volumes end to end (controller expand). Out of scope for the initial
flow. Detail to follow.
**Depends on:** T4

## CREATE — D5 · Quota enforcement for node-local storage tiers (tracker)
**Description (tracker):**
Node-local volumes are now tracked in OSAC inventory; evaluate quota enforcement for local tiers.
Coordinate with the metering/billing/quota area, which owns quota outside the storage group.
Placeholder. Detail to follow.
**Depends on:** T1/T2 (inventory)
