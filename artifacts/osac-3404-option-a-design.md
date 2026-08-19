# OSAC-3404 / OSAC-3702 — LVMS as a CSI Backend: Option A Implementation Design

**Status:** DRAFT for WG review · **Author:** Zoltan Szabo · **Date:** 2026-08-24
**Decision recorded:** WG chose **Option A (full chain)** — Roy voted A, Akshay did not object.
**Supersedes:** the "B vs C, A ruled out" recommendation in `artifacts/lvms-csi/lvms-csi-options.{html,pdf}`.

---

## 0. Why Option A, and what changed

The options doc ruled out A on the **dev-only premise** (A buys tenant-facing inventory/quota
that a dev-only feature doesn't need, at the highest engineering cost). The WG has chosen A anyway,
and Roy's 2026-08-24 feedback supplies the scoping that makes A cheap enough to justify:

> **VMaaS-first, single-cluster for now.** Roy: *"since this is dev/test only we can assume single
> cluster, so we can call into the topolvm-controller."* Akshay: *"VMaaS is enough for now, deal with
> CaaS next."*

**Precise reading of "single cluster" (this matters — see §4.6):**

- **VMaaS** is the *only* case where hub == tenant cluster: tenant workloads are KubeVirt VMs running
  **on the hub**, topolvm is on the hub (OSAC-3011). Operator and `topolvm-node` are co-located →
  the LogicalVolume CR is an **in-cluster write**. Zero cross-cluster reach. This is what we build now.
- **CaaS** is *always two clusters* — there is no dev CaaS topology where the guest == the hub. The
  guest is a separate cluster with its own topolvm (installed by OSAC-3234); the operator/fulfillment
  stay on the hub. Option A's LogicalVolume write is therefore a **cross-cluster write to the guest**.

So we do **not** hard-code "single cluster." VMaaS ships first because its cross-cluster reach is
*zero*, but the design keeps a **client seam** (§4.6) so CaaS drops in later by swapping the
in-cluster client for a remote one built from the guest admin kubeconfig the dispatcher already has
(`_remote_kubeconfig`, used by OSAC-3234). The provisioner logic is identical either way.

VMaaS-first **collapses Option A's single biggest objection** — the cross-cluster hub→tenant hop
(options doc §3.2) — for the near term. A stops being "B + a cross-cluster reach" and becomes
"**B mechanics + OSAC bookkeeping**": we keep the uniform `osac-csi` provisioner, a real Volume
record (inventory + a home for future quota), and the same Volume-API→FS→operator→vendor path every
network backend uses — while the actual LV creation is a `LogicalVolume` CR write (in-cluster for
VMaaS, cross-cluster for CaaS via the same seam).

**Net:** A is now viable and gives dev flows that exercise the *real* production storage path.
The costs the doc listed remain real and are called out as limitations in §7 (no API-first,
capacity-aware scheduling gap on multi-node, sticky volumes).

---

## 1. Does the Slack thread change the plan? Yes — it simplifies and pins three interface details

Roy's answers + Akshay's three questions resolve exactly the open interface questions. Direct answers:

### Akshay Q1 — "Will nodeId be an optional parameter?"
**Yes, optional and additive.** We add ONE optional topology field to the Volume API and Volume CR
(`node_hint`, or a small `topology` message — see §3). Network backends (VAST/NetApp/Pure) ignore it;
it stays unset on their path, so **no existing caller or backend breaks**. It becomes *required only
after tier resolution determines `backend=lvms`* — validated server-side, not in the proto.

### Akshay Q2 — "Only for publish/unpublish, or also Create/Delete?"
**For LVMS the node is consumed at `CreateVolume`** — that is when the LV is physically carved from
the VG on that node. This is the fundamental inversion from VAST:

| | VAST (network) | LVMS (node-local) |
|---|---|---|
| Node matters at | **Publish/attach** (mount a network volume onto a node) | **Create** (carve the LV on the node) |
| CreateVolume needs node? | No | **Yes** |
| Publish/Unpublish | Real vendor attach/detach RPC | Near no-op: volume already lives on the node; `ControllerPublishVolume` only validates the requesting node == the pinned node |
| Delete | By vendor volume id | By `LogicalVolume` name/id; node already pinned |

So `node_hint` flows in at **Create**; Delete/Publish/Unpublish do **not** need a new field.

### Akshay Q3 — "If there's no pod scheduled, just a PVC filed, how does nodeId work?"
Two mechanisms, both mandatory for local tiers:

1. **`WaitForFirstConsumer` binding mode** on every local StorageClass. The PVC stays `Pending`
   and **`CreateVolume` is never called** until a pod is scheduled. Once the scheduler picks node X,
   external-provisioner calls `CreateVolume` with `accessibility_requirements.preferred=[{topology.topolvm.io/node: X}]`.
   The node is therefore **always known at create time**. (This is Roy's point — it's the same
   guarantee topolvm itself relies on.)
2. **Forbid API-first for local tiers.** A `Volume` created via the API with **no consumer** (the
   provision-in-advance path, natural for VAST) is **structurally impossible** for LVMS — no
   consumer → no node → no VG. `CreateVolume` for `backend=lvms` with an empty `node_hint` must be
   **rejected** (`FailedPrecondition`). Under WaitForFirstConsumer this never fires on the PVC path;
   it only guards the direct-API misuse.

**Conclusion:** the thread does not force any redesign; it confirms the design must (a) add an
optional topology field consumed at Create, (b) advertise `VOLUME_ACCESSIBILITY_CONSTRAINTS` so
WaitForFirstConsumer engages, and (c) reject API-first for local tiers.

---

## 2. Design principle: least-disruptive, additive-only

Everything network backends do today stays byte-for-byte identical. LVMS support is added as:

- **1 optional proto field** (topology) on `CreateVolumeRequest`/`VolumeSpec` — owned by Akshay
  (OSAC-3273), the only cross-owner touchpoint.
- **1 new `VendorProvisioner` implementation** in the operator (`LvmsVendorProvisioner`) behind the
  **existing interface** introduced with the VAST provisioner (#340). No changes to the Volume
  controller's control flow, finalizers, `RunProvisioningLifecycle`, or feedback controller.
- **CSI-side additions** (all in `osac-csi-driver`, per options-doc Appendix B): topology extraction,
  `AccessibleTopology` in the response, the accessibility capability, and a NodeGetInfo topology label.
- **Config**: operator RBAC to write `LogicalVolume` CRs; the OSAC CSI node socket-mount for
  `topolvm-node`; AAP sets `volumeBindingMode: WaitForFirstConsumer` on local SCs.

No new services, no new deployment (topolvm is already installed by OSAC-3011/3234), no cross-cluster
mechanism.

---

## 3. Request path (traced end-to-end)

Per the request-path-tracing rule, every layer the request crosses, and whether it changes:

```
Pod scheduled → node X  (WaitForFirstConsumer)
  │
  ▼
[1] external-provisioner (OSAC CSI, provisioner=osac-csi)
      calls CreateVolume(capacity, tier=local, accessibility_requirements.preferred=[topology.topolvm.io/node: X])
  │
  ▼
[2] OSAC CSI Controller  (osac-csi-driver)                                  ← CHANGES
      - advertise VOLUME_ACCESSIBILITY_CONSTRAINTS capability
      - extract node X from accessibility_requirements.preferred[0]
      - call fulfillment CreateVolume(tier=local, size, access_mode, node_hint=X)
      - on AVAILABLE: return AccessibleTopology=[{topology.topolvm.io/node: X}] + volume_context
  │
  ▼
[3] Fulfillment Volume API  (fulfillment-service, OSAC-3273 / Akshay)       ← CHANGES (additive)
      - new OPTIONAL topology field on CreateVolumeRequest → VolumeSpec
      - tier resolution: tier=local → backend=lvms, protocol=block/filesystem
      - GUARD: backend=lvms && node_hint=="" → FailedPrecondition (forbid API-first)
      - persist Volume record (state=CREATING); reconciler writes Volume CR (spec incl. node_hint)
  │
  ▼
[4] Volume CR on the (single) cluster  (osac-operator CRD, OSAC-3280 / Akshay) ← CHANGES (additive)
      - VolumeSpec gains optional NodeHint/Topology field
  │
  ▼
[5] operator Volume controller → LvmsVendorProvisioner                      ← NEW (this ticket)
      - resolves backend=lvms
      - CreateVolume: create a topolvm LogicalVolume CR { spec.name, spec.nodeName=X,
        spec.deviceClass=<vg>, spec.size } in-cluster
      - poll LogicalVolume.status until Volume>0 / VolumeID set (or error)
      - return vendor_volume_id = topolvm volumeID
  │
  ▼
[6] topolvm-node (already installed) watches LogicalVolume → carves the LV on node X
  │
  ▼
[7] feedback controller  (unchanged) → Volume API Update(state=AVAILABLE, vendor_volume_id) + Signal
  │
  ▼
[8] OSAC CSI polls GetVolume → AVAILABLE → returns volume_context{osac.backend=lvms,
      osac.volume-id, osac.topolvm-volume-id} + AccessibleTopology=[node X] → PV created, PVC bound

MOUNT (separate timeline, per consumer start):
  kubelet → OSAC CSI node.NodeStage/NodePublish
    → route by volume_context[osac.backend]=lvms → topolvm-node socket
    → NodePublish against topolvm using osac.topolvm-volume-id
```

**Layers that change:** [1] SC config, [2] CSI controller+node, [3] fulfillment (1 field + 1 guard),
[4] CRD (1 field), [5] new provisioner. **Unchanged:** reconciler, feedback controller, OPA/policy
(local tier just needs an allowlist entry), node-plugin routing mechanism.

---

## 4. Component-by-component detail

### 4.1 StorageClass (AAP — already creates local SCs via OSAC-3011/3234)
- Set `volumeBindingMode: WaitForFirstConsumer` (mandatory).
- `provisioner: osac-csi` (NOT `topolvm.io`) — this is what makes it Option A rather than Option C.
- `allowVolumeExpansion` per topolvm capability.
- Parameters carry the topolvm device-class / VG name so the operator knows what to put in the
  `LogicalVolume` CR (e.g. `parameters."osac.io/device-class": lvms-vg1`).

### 4.2 OSAC CSI Controller (`osac-csi-driver`) — options-doc Appendix B
- `ControllerGetCapabilities += VOLUME_ACCESSIBILITY_CONSTRAINTS` (required for WFC to pass topology).
- `CreateVolume`: read `req.AccessibilityRequirements.Preferred[0].Segments["topology.topolvm.io/node"]`;
  pass it to `fulfillment.CreateVolume` in the new topology field. Return
  `Volume.AccessibleTopology=[{topology.topolvm.io/node: X}]` from the fulfillment response.
- The controller stays a **thin delegate to fulfillment** — it does NOT talk to topolvm directly
  (that's what distinguishes A from B). Topology is the only new thing it handles.

### 4.3 OSAC CSI Node (`osac-csi-driver`)
- `NodeGetInfo`: return `AccessibleTopology={topology.topolvm.io/node: <nodeID>}` so the topology
  domain exists cluster-wide.
- Helm: mount the `topolvm-node` unix socket into the OSAC CSI node container; register
  `lvms=<topolvm-node socket>` in `--vendor-sockets`. Existing `proxy.Manager` routing by
  `osac.backend` then handles NodeStage/NodePublish with no code change.

### 4.4 Fulfillment Volume API (`fulfillment-service`, OSAC-3273 — **coordinate with Akshay**)
- **Proto (the one cross-owner change):** add an OPTIONAL field to `CreateVolumeRequest` and
  `VolumeSpec`. Recommend a small forward-compatible message rather than a bare string:
  ```proto
  // in osac.private.v1 VolumeSpec (and mirror on CreateVolumeRequest)
  message VolumeTopology {
    // CSI topology segment value for topology.topolvm.io/node (the scheduler-selected node).
    string node = 1;
  }
  optional VolumeTopology topology = N;   // unset for network backends
  ```
  A message (not a raw `node_hint` string) lets us add zone/region later without another proto bump.
- **Tier resolution (already merged, #342):** `tier=local → backend=lvms`. No change beyond reading
  the new field.
- **Guard (new):** if resolved `backend` is node-local (lvms) and `topology.node` is empty →
  `codes.FailedPrecondition` ("local tier requires a scheduled consumer; use WaitForFirstConsumer").
  This is the enforcement point for "no API-first for local tiers."
- Reconciler writes the field through to the Volume CR (mechanical).
- OPA: local tier gets the same CSI-role allowlist entry as other tiers.

### 4.5 Volume CR (`osac-operator`, OSAC-3280 — **coordinate with Akshay**)
- `VolumeSpec` gains the same optional `Topology`/`NodeHint` field. Purely carries data to the
  provisioner; no controller-flow change.

### 4.6 operator LvmsVendorProvisioner (`osac-operator`) — **the core of this ticket**
Implements the existing `VendorProvisioner` interface (same one `VastVendorProvisioner` implements).

**Client seam (VMaaS now, CaaS later — Q1):** the provisioner does not assume "in-cluster." It
resolves a **`targetClusterClient`** = the client to the cluster where topolvm runs:
- VMaaS → the operator's own in-cluster client (hub == tenant).
- CaaS → a remote client built from the guest admin kubeconfig the dispatcher already holds
  (`_remote_kubeconfig` / OSAC-3234; the operator already reaches the tenant cluster for VAST PV/PVC
  tracking). **Only the client differs; the logic below is identical.**

- **CreateVolume:**
  1. Require `spec.Topology.Node` (defense-in-depth; fulfillment already guards).
  2. Create a topolvm `LogicalVolume` CR via `targetClusterClient`:
     `spec.name`, `spec.nodeName = <node X>`, `spec.deviceClass = <vg from SC params>`,
     `spec.size = <requested>`. (This is the "thin part" of topolvm-controller — the doc's
     "A-delegate via CR creation," preferred over gRPC-proxying topolvm-controller because it needs
     **RBAC only, no TCP-exposed socket** — see §8 / Q2. Note: topolvm-**node** still does all actual
     LV carving, so this *is* delegation to topolvm, not a reimplementation of its storage logic.)
  3. Poll `LogicalVolume.status` until `status.volumeID` is set (success) or an error is reported.
  4. **On capacity failure, return `codes.ResourceExhausted`** (NOT a generic error). This is what
     lets external-provisioner clear the `selected-node` annotation and reschedule (Q3) — without it,
     a pod bound to a full node gets stuck. Must also be propagated by the CSI controller (§4.2).
  5. Return `vendor_volume_id = status.volumeID` (topolvm's handle) — threaded into `volume_context`
     as `osac.topolvm-volume-id` so the node plugin can NodePublish against topolvm-node.
- **DeleteVolume:** delete the `LogicalVolume` CR by name via `targetClusterClient`; topolvm-node
  reclaims the LV.
- **ControllerPublish/Unpublish:** near no-op — validate the requesting node == the pinned node
  (`LogicalVolume.spec.nodeName`); return success. (The volume is already on the node; there is no
  network attach step.)

### 4.7 Deployment / Helm
- Operator RBAC: `create/get/list/watch/delete` on `topolvm.io/LogicalVolume`.
- OSAC CSI node socket mount for topolvm-node (§4.3).
- (No new deployment — topolvm already installed.)

---

## 5. Work breakdown (created under OSAC-3702, 2026-08-24)

**Jira keys:** T1 OSAC-4357 · T2 OSAC-4358 · T3 OSAC-4359 · T4 OSAC-4360 · T5 OSAC-4361 ·
T6 OSAC-4362 · T7 OSAC-4363 · T8 OSAC-4364 · **T9 OSAC-3711** (repurposed, VMaaS E2E) ·
D1 OSAC-3710 (repurposed, CaaS, Backlog) · D2 OSAC-4365 · D4 OSAC-4366 · D5 OSAC-4367 (Backlog).
Exploration ticket OSAC-3404 closed. Milestone: T1–T9 = `0.3`; deferred = `Backlog`. "Blocks" links
wired per the Depends-on column. Ticket text: `artifacts/osac-3702-ticket-drafts.md`.


| # | Component | Work | Owner | Depends on |
|---|-----------|------|-------|-----------|
| 1 | proto (fulfillment) | optional `VolumeTopology` on CreateVolumeRequest + VolumeSpec; buf lint/generate | Akshay (coord) | — |
| 2 | fulfillment | read topology; API-first guard for local backends; pass to Volume CR | Akshay / Zoltan | 1 |
| 3 | operator CRD | optional `Topology` on VolumeSpec | Akshay (coord) | 1 |
| 4 | operator | `LvmsVendorProvisioner` (LogicalVolume CR create/poll/delete/publish-validate) | **Zoltan** | 3 |
| 5 | osac-csi-driver | `VOLUME_ACCESSIBILITY_CONSTRAINTS` cap, topology extract, AccessibleTopology, NodeGetInfo label | **Zoltan / Roy** | 1 |
| 6 | osac-csi-driver Helm | topolvm-node socket mount + `--vendor-sockets lvms=...` | **Zoltan** | — |
| 7 | operator Helm | RBAC for LogicalVolume | **Zoltan** | 4 |
| 8 | AAP (osac-aap) | local SC: `provisioner: osac-csi`, `volumeBindingMode: WaitForFirstConsumer`, device-class param | **Zoltan** | — |
| 9 | e2e | SNO: PVC(tier=local) + pod → LV on node; Volume record present; delete cleans up both | **Zoltan** | 1-8 |

---

## 6. Data-flow gotchas to get right (the tricky bits)

1. **Volume handle threading.** The node plugin mounts by calling topolvm-node with topolvm's
   volume id — so the operator MUST return topolvm's `status.volumeID` as `vendor_volume_id`, and the
   CSI controller MUST surface it in `volume_context` (`osac.topolvm-volume-id`). Getting this wrong =
   volume provisions but won't mount.
2. **Topology domain must exist before scheduling.** `NodeGetInfo` on every node must advertise
   `topology.topolvm.io/node` (§4.3) or WaitForFirstConsumer has no domain to constrain against.
3. **Device class / VG name** must travel from the SC parameters → CreateVolume `parameters` →
   fulfillment → Volume CR → LogicalVolume `spec.deviceClass`. Decide the parameter key now.
4. **`reserved` proto discipline** — pick a fresh field number for `topology`; never reuse the old
   `pvc_ref` number (removed in #341).

---

## 7. Known limitations (accepted with Option A — none are new; carried from the options doc)

- **No API-first / provision-in-advance for local tiers** — structurally impossible; guarded (§4.4).
- **Capacity-aware scheduling gap on multi-node.** topolvm's real scheduler integration
  (`CSIStorageCapacity` / topolvm-scheduler) is tied to `provisioner: topolvm.io`. With
  `provisioner: osac-csi`, the k8s scheduler has **no per-node VG free-capacity signal**, so on a
  multi-node cluster WaitForFirstConsumer can bind a pod to a node without room. Consequences (Q3):
  - **Not a correctness/data problem**, and **not a hard blocker** *provided* the provisioner returns
    `codes.ResourceExhausted` on capacity failure (§4.6) — external-provisioner then clears the
    `selected-node` annotation and the scheduler re-picks.
  - But the re-pick is **blind** (no capacity signal), so on a tight cluster it can **thrash** across
    nodes before landing on one with space → potentially significant provisioning delay; hard fail
    only if *no* node has room. `CSIStorageCapacity` would make it first-try correct.
  - **Moot on SNO / single-node dev (the stated VMaaS target).** Implementing `GetCapacity` +
    `CSIStorageCapacity` publishing on OSAC CSI is the multi-node fix — out of scope here; note it.
- **Split controller behavior** — the operator now has a per-backend provisioner (network vs
  node-local); this is inherent to supporting both and is the maintenance cost the doc flagged.
- **Sticky volumes** — an LVMS PV is pinned to one node for life; standard LVMS caveat, not fixable.

---

## 7b. Locked decisions (2026-08-24)

- **Routing key = StorageBackend ID.** Tier resolution sets `status.backend = BackendAssociation.BackendId`
  (`private_volumes_server.go:159` ← `start_grpc_server_cmd.go:962`). This ID is the `osac.backend`
  value in `volume_context` and the key for `--vendor-sockets` (node mount routing) and
  `--vendor-controllers` (publish). The lvms backend's ID must be threaded into those maps the same
  way VAST's is.
- **Provisioner selection = StorageBackend `provider`.** Provider string is **`lvms`** (StorageBackend
  named `local`, `spec.provider: lvms`; `register-local-storage.yaml`). The operator selects
  `LvmsVendorProvisioner` when the backend provider is `lvms`.
- **Attach is already solved.** CSI controller `controller.go` has `noAttachEndpoint = "none"` — a
  backend configured with endpoint `none` makes `ControllerPublish/UnpublishVolume` a logged no-op
  ("node-local"). So **LVMS needs no operator publish path** — configure the lvms backend's
  vendor-controller endpoint = `none`. `LvmsVendorProvisioner` = **Create + Delete only**.
- **Topology proto shape = typed message (Q3 option 2):** `VolumeTopology { string node = 1; }`,
  optional on `CreateVolumeRequest` + private `VolumeSpec`; mirror on the operator Volume CRD. Room
  for `zone`/`region` later without another VolumeSpec change.
- **Device-class param key = `osac.io/device-class` (Q4 option 2):** vendor-neutral SC parameter; the
  operator translates it to the topolvm `LogicalVolume.spec.deviceClass`.
- **CRD coupling note (Q6):** CR-creation couples us to topolvm's `LogicalVolume` CRD schema (we
  construct it). Accepted for now (CRD is stable); a hardening ticket (pin/vendor types + drift test)
  is **held**, filed only if drift bites. The gRPC-proxy alternative would avoid this coupling but at
  the cost of a TCP-exposed unauthenticated socket — not chosen.
- **CreateVolume today** (`controller.go:~102`) delegates only to `fulfillment.CreateVolume` (params:
  Tier/SizeBytes/AccessMode/ClusterID/PVCRef) and returns `volume_context{osac.backend, osac.volume-id
  =VendorVolumeID, osac.protocol}`. No topology extraction, no `AccessibleTopology`, capabilities =
  CREATE_DELETE + PUBLISH_UNPUBLISH only. T5 adds the topology pieces.

## 8. Open items to confirm with the WG / Akshay / Roy

1. **Proto field shape** — `VolumeTopology` message vs bare `node_hint` string (recommend message).
2. **A-delegate mechanism** — LogicalVolume CR creation (recommended, RBAC-only) vs gRPC-proxy to
   topolvm-controller (needs TCP Service). Roy said "proxy to the topolvm-controller" — confirm he's
   fine with the CR-creation realization, which achieves the same thing without exposing the socket.
3. **Device-class parameter key** naming.
4. **Multi-node capacity** — accept the SNO-only limitation for now, or scope `GetCapacity` in?
5. **CaaS vs hub first** — Akshay suggested hub=VMaaS first, CaaS next. Agree; sub-task 9 targets
   SNO/hub first.
