# CSI provisioning & mount — four scenarios compared

Purpose: build a confident mental model of how CSI works, then how the OSAC aggregating driver
changes it, for both a **network** backend (VAST) and a **node-local** backend (topolvm/LVMS).
Companion to `osac-3404-option-a-design.md`. The topolvm-via-OSAC scenario (§4) is the corrected
version of Roy's drawing.

---

## 0. The cast (CSI fundamentals)

A CSI driver is **two deployables**, and it is **passive** (a gRPC server that answers, never watches):
- **Controller** (Deployment, usually 1x): `CreateVolume`, `DeleteVolume`, `ControllerPublishVolume`
  (attach), `GetCapacity`. Cluster-wide.
- **Node plugin** (DaemonSet, 1 per node): `NodeStageVolume`, `NodePublishVolume` (mount),
  `NodeGetInfo` (declares node id + topology).

The **CO** (Container Orchestrator = Kubernetes) drives it through **sidecars** + **kubelet** — *they*
watch the API and translate to CSI gRPC:
- **external-provisioner** (next to the controller): watches **PVCs** → `CreateVolume`/`DeleteVolume`.
  Reads `GetPluginCapabilities` to learn if the driver is topology-aware.
- **external-attacher** (next to the controller): watches **VolumeAttachment** → `ControllerPublishVolume`.
- **node-driver-registrar** (next to the node plugin): registers the plugin with kubelet; kubelet then
  calls **`NodeGetInfo`** and stores the result in the node's **CSINode** object + node labels.
- **kubelet**: calls the node plugin for the actual mount.

Two independent timelines:
- **Provisioning** — happens **once** per volume (create the storage).
- **Mount** — happens **every time** a consumer starts on a node (attach + stage + publish).

`volumeBindingMode` on the StorageClass decides *when* provisioning fires:
- **Immediate** — provision as soon as the PVC exists (node unknown). Fine for network storage.
- **WaitForFirstConsumer (WFC)** — wait until a pod is scheduled, so the node is known. **Mandatory**
  for node-local storage.

Legend for the diagrams: `[box]` = pod/component · `((cyl))` = storage · `-- n. label -->` = step n.

---

## 1. VAST native (network CSI driver, no OSAC)

The baseline: a normal network CSI driver installed directly. One cluster. `volumeBindingMode: Immediate`.

```
                          ONE CLUSTER
  [PVC] --1--> (external-provisioner)
                     |                      vast-csi CONTROLLER pod
                     2. CreateVolume        [external-provisioner | external-attacher | vast-csi ctrl]
                     v
              [vast-csi controller] --3. VAST API create--> ((VAST array))
  [PV] <--4. create+bind-- (external-provisioner)

  --- pod starts ---
  [Pod on node N] --5. schedule (ANY node; volume is network-reachable)
  [VolumeAttachment] --6--> (external-attacher) --7. ControllerPublishVolume--> [vast-csi ctrl] --> ((VAST)) (LUN mask)
  [kubelet on N] --8. NodeStage/NodePublish--> [vast-csi node (DaemonSet)] --> mount iSCSI/NFS from ((VAST))
```
**Provisioning:** 1 PVC → 2 external-provisioner calls controller `CreateVolume` → 3 controller hits
the VAST API → 4 PV created & bound. Node is irrelevant (network volume).
**Mount:** 5 pod scheduled anywhere → 6–7 attach (map volume to node over the network) → 8 node plugin
mounts. Controller attach is real (the array must expose the LUN to node N).

---

## 2. topolvm native (node-local CSI driver, no OSAC)

One cluster. `volumeBindingMode: WaitForFirstConsumer`. Introduces the LogicalVolume CR trick.

```
                          ONE CLUSTER
  [PVC sc=topolvm] --1. created, stays Pending (WFC)
  [Pod] --2. scheduled to node N  (topolvm-scheduler/CSIStorageCapacity picks a node WITH free VG)
                                   PVC annotated selected-node=N
        |
        3. external-provisioner -> topolvm-controller CreateVolume(accessibility=[topolvm.io/node=N])
        v
  [topolvm-controller] --4. writes LogicalVolume CR (spec.nodeName=N, size, deviceClass)
                                        |
        (topolvm-node on N WATCHES LogicalVolume CRs for its node)   <-- topolvm's internal loop
                                        v
  [topolvm-node on N] --5. lvmd: lvcreate on node N's VG --> sets LogicalVolume.status.volumeID
  [topolvm-controller] --6. sees status --> returns CreateVolume(accessible_topology=[topolvm.io/node=N])
  [PV nodeAffinity=N] <--7. create+bind-- external-provisioner

  --- mount (pod already on N) ---
  [kubelet on N] --8. NodeStage/NodePublish--> [topolvm-node] --> mount the LV
        (NO controller attach: the LV is already physically on N)
```
**Key differences from VAST:** provisioning waits for the pod (WFC) because the node must be known
*before* the LV is carved; the controller doesn't touch storage directly — it **creates a
`LogicalVolume` CR** and topolvm-**node** (a controller-runtime reconciler, topolvm's *internal*
work-queue, invisible to CSI) does the `lvcreate`; the PV is **pinned** to N via `nodeAffinity`; and
there is **no controller attach** (steps 6–7 of the VAST flow don't exist).

---

## 3. VAST via OSAC CSI (aggregating driver, network backend)

Now OSAC's meta-driver. Two clusters: tenant (where PVCs live) + hub (control plane + vendor
controller). VAST is network, so node-agnostic; typically `Immediate`.

```
  TENANT CLUSTER                                   HUB CLUSTER
  [PVC sc=osac-vast-gold]                          [fulfillment: Volume API]
     |1 external-provisioner                          ^   |
     v                                                |   3. reconciler writes Volume CR
  [OSAC CSI controller] --2. CreateVolume-----------> |   v
     (thin: delegates to fulfillment; no vendor call) |  [Volume CR] 
                                                       |   |4 osac-operator: VastVendorProvisioner
                                                       |   |   reads tenant creds (hub Secret)
                                                       |   v
                                                       |  [vast-csi vendor controller] --5. VAST API--> ((VAST))
                                                       |   |6 feedback controller
                                                       +---+  Update(AVAILABLE, vendor-id)
  [PV] <--7. OSAC CSI polls GetVolume->AVAILABLE; PV created & bound
        volume_context{osac.backend=<id>, osac.volume-id=<vendor id>, osac.protocol}

  --- mount ---
  [Pod on ANY node] --VolumeAttachment--> external-attacher
     --8. ControllerPublishVolume--> [OSAC CSI ctrl] --route by osac.backend--> [vast-csi ctrl] --> ((VAST)) map
                                          (OSAC-4187: 0.2 stopgap, CSI ctrl dials vendor directly)
  [kubelet] --9. NodePublish--> [OSAC CSI node] --route by osac.backend--> [vast node plugin] --> mount ((VAST))
```
**What OSAC adds:** the controller is a **thin delegate** to the fulfillment Volume API (tier
resolution, policy, inventory) — it does **not** call the vendor. The **operator** drives the vendor
(credential isolation: creds stay on the hub). The node plugin is a **proxy** that routes mount calls
to the right vendor node socket by `osac.backend`. Attach is real (network volume).

---

## 4. topolvm via OSAC CSI — Option A (corrected Roy diagram)

**One cluster** (VMaaS: hub == tenant). `WaitForFirstConsumer`. This is the target design.

```
                     ONE CLUSTER (VMaaS = hub == tenant)
  [PVC sc=osac-local, WFC] --1. Pending
  [Pod] --2. scheduled to node N   (⚠ blind pick without CSIStorageCapacity — the D2 multi-node gap)
        |                            PVC selected-node=N
        3. external-provisioner -> OSAC CSI controller CreateVolume(accessibility=[topolvm.io/node=N])
        v
  [OSAC CSI controller] --4. extract N; fulfillment Volume API CreateVolume(tier=local, node=N)
        [fulfillment] tier->provider=lvms; GUARD node present (else FailedPrecondition); persist;
                      reconciler writes Volume CR (topology.node=N)
        |
        v
  [osac-operator: LvmsVendorProvisioner] --5. writes LogicalVolume CR (spec.nodeName=N)
        (bypasses topolvm-controller; on no capacity -> ResourceExhausted)
                                        |
        (topolvm-node on N watches LogicalVolume CRs)
                                        v
  [topolvm-node on N] --6. lvmd: lvcreate --> status.volumeID
  [operator] --7. poll LV ready --> Volume CR AVAILABLE (vendor_volume_id=topolvm volumeID); feedback->API
  [PV nodeAffinity=N] <--8. OSAC CSI polls GetVolume->AVAILABLE; returns accessible_topology=[topolvm.io/node=N],
                          volume_context{osac.backend=<id>, osac.topolvm-volume-id, osac.protocol}; PV bound

  --- mount (pod already on N) ---
  [ControllerPublishVolume] --9--> [OSAC CSI ctrl] --backend endpoint = "none" sentinel--> NO-OP
  [kubelet on N] --10. NodeStage/NodePublish--> [OSAC CSI node] --route by osac.backend--> [topolvm-node] --> mount LV
```
**Reads like §3 (same OSAC control plane) but with §2's node-local mechanics:** WFC + topology are
mandatory; the operator's provisioner **writes a `LogicalVolume` CR** instead of dialing a vendor
controller (no creds, no endpoint); controller attach is a **no-op** (the `none` sentinel); the node
plugin proxies to **topolvm-node**. Everything is in one cluster (no cross-cluster hop). topolvm-node
is a *peer* DaemonSet the OSAC node plugin forwards to (shared socket), not a child.

---

## 5. Side-by-side

| Dimension | 1. VAST native | 2. topolvm native | 3. VAST via OSAC | 4. topolvm via OSAC |
|---|---|---|---|---|
| Binding mode | Immediate | **WFC** | Immediate | **WFC** |
| Who calls provisioning | external-provisioner → vendor ctrl | ext-prov → topolvm ctrl | ext-prov → OSAC ctrl → fulfillment → operator | ext-prov → OSAC ctrl → fulfillment → operator |
| Storage actually created by | VAST array (network API) | topolvm-node (lvcreate via LV CR) | VAST array | topolvm-node (lvcreate via LV CR) |
| How work reaches the node | n/a (network) | **LogicalVolume CR** | n/a (network) | **LogicalVolume CR** (operator writes it) |
| Topology needed? | no | **yes** (node) | no | **yes** (node) |
| Controller attach? | **yes** (map LUN) | no | yes (via OSAC/vendor) | **no** (`none` sentinel) |
| Credentials | vendor creds in driver | none | creds on **hub**, operator-only | none |
| OSAC inventory / tier / policy | no | no | **yes** | **yes** |
| Cross-cluster | 1 cluster | 1 cluster | tenant↔hub | **1 cluster** (VMaaS) |
| PV pinned to a node? | no | **yes** (nodeAffinity) | no | **yes** (nodeAffinity) |

Row to internalize: columns 1↔2 differ because **network vs node-local**; columns 2↔4 differ because
**+OSAC control plane**. Scenario 4 = "node-local mechanics (col 2) wrapped in the OSAC control plane
(col 3)."

---

## 6. What Roy's drawing got wrong (mapped to §4)

- **Two clusters for VMaaS** → should be **one** (hub == tenant). If genuinely two, that's CaaS and
  the cross-cluster arrows become the unsolved hard part.
- **"LVMS [VMaaS cluster]" inside "Multi Vendor Controllers"** → there is no OSAC-dialed LVMS vendor
  controller. topolvm-controller exists but we **bypass** it by writing the LogicalVolume CR; the
  operator's `LvmsVendorProvisioner` (Go, inside the operator) does that — it is not a pod in the
  vendor-controllers box.
- **Hub controllers → VMaaS LVMS (steps 5, 8)** → cross-cluster provisioning/attach into node-local
  storage; impossible. Vanishes once it's one cluster + CR-creation.
- **Attach chain (6/7/8) for LVMS** → node-local needs no controller attach; attach is the `none`
  no-op, mount is node-only (step 10 here).
- **Missing the crux** → no WFC / pod-scheduling / nodeId flow, which is the whole reason LVMS is
  special (steps 1–4 here).
- Minor: "Watchs" is the **external-provisioner sidecar** watching PVCs, not the driver; "Quota check"
  is likely stale (quota left the storage WG).
