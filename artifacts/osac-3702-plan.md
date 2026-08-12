# OSAC-3702 Implementation Plan
# Tenant clusters use node-local storage through LVMS as a CSI driver backend

**Last updated:** 2026-08-17
**Epic:** OSAC-3702 (child of OSAC-2872 Storage Control Plane)
**Exploration task:** OSAC-3404 (ready to close)

---

## Scope (tight)

OSAC-3702 owns **CSI driver wiring for LVMS topology** only.
The Volume controller dispatch belongs to OSAC-3280 (Akshay).

---

## Close immediately

| Ticket | Action |
|--------|--------|
| OSAC-3404 | Close with findings comment (exploration done — see below) |
| OSAC-3710 | Close — covered by OSAC-3234 (PR #199). LVMS installed on CaaS guest cluster post-cluster-ready, before any PVC creation. |
| OSAC-3711 | Close — covered by OSAC-3011 (merged Aug 6). LVMS installed on hub during tenant onboarding, before any PVC creation. |

---

## Dependencies (not our work — must wait)

| Blocker | Owner | Ticket | What we need |
|---------|-------|--------|--------------|
| Volume CRD & Operator — generic dispatch | Akshay | OSAC-3280, PR #223 | Operator Volume controller must include lvms backend dispatch (topology-aware, node-local). Flag to Akshay before PR #223 is too far along. |
| VolumeSpec proto `node_hint` field | Akshay | OSAC-3273, PR #201 | `CreateVolume` topology requirement needs to flow into the Volume CR. Currently VolumeSpec has no topology field. |
| Real gRPC VolumeClient in CSI driver | Roy | OSAC-2882 | `client.go` is currently empty. End-to-end not testable until this lands. |

### Flag to Akshay (before OSAC-3280 PR #223 finalizes)

OSAC-3280 must design in lvms backend dispatch. The operator Volume controller needs a
`backend=lvms` code path that:
1. Reads node_hint from VolumeSpec (topology — which node was selected by scheduler)
2. Creates a LogicalVolume CR on the target cluster with node selector, OR creates a PVC
   on the hub pointing to the lvms StorageClass (simpler, avoids direct topolvm CR coupling)
3. Polls until LV/PVC is bound
4. Updates VolumeStatus with vendor_volume_id, state=AVAILABLE

---

## Architecture Decision: Full chain vs Passthrough

**Open question — sync with Roy before committing to either.**

### Option A: Full chain (original plan)
```
OSAC CSI CreateVolume
  → fulfillment service (create Volume record in DB)
  → Volume CR on hub
  → osac-operator Volume controller [OSAC-3280, Akshay]
  → topolvm-controller (LogicalVolume CR)
  → LV created, AccessibleTopology returned back up the chain
```
- Pros: volume inventory, quota enforcement, consistent with VAST/ONTAP path
- Cons: blocks on OSAC-3280; topology round-trip adds complexity; OSAC must re-return topolvm's AccessibleTopology

### Option B: Passthrough (Roy's suggestion)
```
OSAC CSI CreateVolume
  → fulfillment service (resolve tier → backend=lvms, topolvm socket endpoint)
  → OSAC CSI controller proxies CreateVolume DIRECTLY to topolvm-controller gRPC socket
  → topolvm handles everything, returns AccessibleTopology natively
  → OSAC CSI returns topolvm's response verbatim
```
- Pros: no OSAC-3280 dependency; topology correct by default (topolvm returns it); simpler; same pattern as node plugin
- Cons: no Volume record in DB; no OSAC quota enforcement; topolvm-controller socket must be exposed via a Service (TCP) for the OSAC controller pod to reach it

### Option C — Drop OSAC-3702, keep AAP path (raised 2026-08-17)

The original goal (devs get storage without VAST) is already achieved by OSAC-3234 (merged Aug 13). OSAC-3702 adds only CSI path alignment:
- **Costs:** node affinity propagation, topology complexity, ongoing special-case maintenance, Option B is already a deviation so "same path as prod" is broken anyway
- **Benefit:** uniform StorageClass provisioner name (topolvm vs osac-csi) — devs don't care, and LVMS can never be fully equivalent to network-attached storage anyway (sticky, non-mobile volumes)
- **The question for Akshay:** who is the actual user and do they care about the provisioner name? If target = OSAC dev testing storage features → they know internals, Option C is fine. If target = any tenant who should see identical prod behavior → Option C is a compromise.

**Recommended starting point: Option B** (pre-2026-08-17 recommendation) **or Option C** (discuss with Akshay). Volume tracking can be layered on later once OSAC-3280 is mature. The socket exposure is a small Helm addition. Topology is handled correctly with zero extra work.

**Pre-condition for Option B:** confirm with Roy that topolvm-controller can be exposed via a TCP Service (not just pod-internal socket) and that OSAC-3634 architecture supports proxying controller-side RPCs.

---

## Our work — can start now (no blockers)

All in `osac-csi-driver/`. Unit-testable with stubs before OSAC-3280/3273 land.

### 1. ControllerGetCapabilities — add VOLUME_ACCESSIBILITY_CONSTRAINTS

`pkg/driver/controller.go:231` — add alongside CREATE_DELETE_VOLUME and PUBLISH_UNPUBLISH_VOLUME.
Required for WaitForFirstConsumer to work with LVMS.

### 2. CreateVolume — topology passthrough

`pkg/driver/controller.go:45` — extract `AccessibilityRequirements.preferred[0]` node key and
add to `CreateVolumeParams`. Wire to VolumeSpec `node_hint` once OSAC-3273 proto lands.
Return `AccessibleTopology` in `CreateVolumeResponse`.

### 3. NodeGetInfo — return topolvm topology labels

`pkg/driver/node.go:214` — return `topology.topolvm.io/node=<nodeID>` in `NodeGetInfoResponse.AccessibleTopology`.
This is what Kubernetes uses to match PVCs to nodes for WaitForFirstConsumer.

### 4. Helm chart — topolvm-node socket mount

`charts/csi-driver/templates/node-daemonset.yaml`:
- Add hostPath volume for `/run/topolvm` (or wherever topolvm-node socket lives)
- Mount into osac-csi-driver container
- Add `lvms=/run/topolvm/csi-topolvm.sock` to `--vendor-sockets` via values

---

## OSAC-3404 exploration findings (for closing comment)

Key findings since ticket was written (July 30):

1. **PR #141 (merged Aug 7)** changed controller architecture. Controller now delegates ALL
   volume lifecycle to fulfillment service VolumeClient. The "boomerang via topolvm socket"
   described in the ticket no longer applies to the controller — that path goes via the
   operator Volume controller (OSAC-3280) instead.

2. **Volume API (PR #201/223, Akshay)** is much further along than assumed. VolumeSpec and
   VolumeStatus are defined. Missing: `node_hint` field for topology.

3. **The controller never talks to topolvm socket** — the ticket's proposed wiring for the
   controller side is stale. The correct architecture:
   - CSI controller → fulfillment API → Volume CR on hub
   - osac-operator Volume controller → topolvm (via LogicalVolume CR or PVC on hub cluster)
   - CSI node plugin → topolvm-node socket (Stage/Publish, no change needed)

4. **Work item "Validate topolvm socket accessibility (controller side)"** — N/A. Controller
   doesn't use vendor sockets. Dropped.

5. **Topology is still the key open item** (correctly identified in ticket). WaitForFirstConsumer
   requires VOLUME_ACCESSIBILITY_CONSTRAINTS capability + NodeGetInfo topology labels +
   topology passthrough in CreateVolume. This is 100% in OSAC-3702/CSI driver scope.

6. **OSAC-3710/3711** are covered by existing work (OSAC-3234, OSAC-3011). Close them.

---

## Architecture diagram (post-PR #141)

```
PVC on tenant cluster (tier=local, WaitForFirstConsumer)
  |
  | [scheduler selects node X]
  v
csi-provisioner calls OSAC-CSI CreateVolume
  (AccessibilityRequirements: preferred node = X)
  |
  v
ControllerServer.CreateVolume (osac-csi-driver)
  | extracts node_hint=X from topology
  | calls VolumeClient.CreateVolume(tier=local, node_hint=X)
  v
fulfillment-service Volume private API
  | creates Volume CR on hub cluster
  | (VolumeSpec: tier=local, node_hint=X, size, access_mode)
  v
osac-operator Volume controller [OSAC-3280, Akshay]
  | backend=lvms dispatch:
  |   creates LogicalVolume CR (or PVC) on hub with node selector=X
  |   waits for LV ready
  |   updates VolumeStatus: vendor_volume_id=<lv-name>, state=AVAILABLE
  v
OSAC-CSI polls GetVolume until AVAILABLE
  | returns CreateVolumeResponse:
  |   volume_context: osac.backend=lvms, osac.volume-id=<lv-name>, osac.protocol=block
  |   accessible_topology: topology.topolvm.io/node=X
  v
NodeStageVolume / NodePublishVolume (osac-csi-driver node plugin)
  | resolves vendor socket: osac.backend=lvms → /run/topolvm/csi-topolvm.sock
  | proxies to topolvm-node on node X
  v
topolvm-node creates LV on node X VG, formats, mounts
```
