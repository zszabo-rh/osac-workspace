#!/usr/bin/env python3
"""Builds a self-contained HTML analysis doc with graphviz diagrams.
No network needed: diagrams rendered locally via graphviz.

  IMG_MODE=svg  (default) -> inline SVG, crisp, for browser/HTML sharing
  IMG_MODE=png            -> base64 PNG <img>, survives HTML->docx (libreoffice)
"""
import subprocess, sys, html, os, base64

IMG_MODE = os.environ.get("IMG_MODE", "svg")

def svg(dot: str) -> str:
    """Render a graphviz DOT string to an embeddable diagram block."""
    if IMG_MODE == "png":
        out = subprocess.run(["dot", "-Tpng", "-Gdpi=140"], input=dot.encode(), capture_output=True)
        if out.returncode != 0:
            sys.stderr.write(out.stderr.decode()); raise SystemExit("dot failed")
        b64 = base64.b64encode(out.stdout).decode()
        return f'<div class="diagram"><img src="data:image/png;base64,{b64}"/></div>'
    out = subprocess.run(["dot", "-Tsvg"], input=dot.encode(), capture_output=True)
    if out.returncode != 0:
        sys.stderr.write(out.stderr.decode())
        raise SystemExit("dot failed")
    s = out.stdout.decode()
    i = s.find("<svg")
    return '<div class="diagram">' + s[i:] + "</div>"

# ---------------------------------------------------------------- diagrams ----

D_CONSTRAINT = r'''
digraph G {
  rankdir=LR; fontname="Helvetica"; node [fontname="Helvetica", fontsize=11];
  edge [fontname="Helvetica", fontsize=10];
  subgraph cluster_net {
    label="Network-attached (VAST / NetApp / Pure)"; style=filled; color="#e8f0fe"; fontsize=12;
    vpod [label="Pod on\nany node", shape=box, style=filled, fillcolor=white];
    varr [label="VAST Array\n(on the network)", shape=cylinder, style=filled, fillcolor="#c9e0ff"];
    vpod -> varr [label="mount over\nNFS / iSCSI\n(node-agnostic)"];
  }
  subgraph cluster_local {
    label="Node-local (LVMS / topolvm)"; style=filled; color="#fde8e8"; fontsize=12;
    lpod [label="Pod on\nNODE X", shape=box, style=filled, fillcolor=white];
    ldisk [label="LV in VG\nON NODE X", shape=cylinder, style=filled, fillcolor="#ffd0d0"];
    lpod -> ldisk [label="local block dev\n(ONLY on node X)"];
    lother [label="NODE Y\n(cannot reach it)", shape=box, style=filled, fillcolor="#f5f5f5", fontcolor="#999"];
    lother -> ldisk [label="X", color="#cc0000", fontcolor="#cc0000", style=dashed];
  }
}
'''

D_VAST_TOPO = r'''
digraph G {
  rankdir=TB; fontname="Helvetica"; compound=true;
  node [fontname="Helvetica", fontsize=10, shape=box, style="filled,rounded", fillcolor=white];
  edge [fontname="Helvetica", fontsize=9];
  subgraph cluster_tenant {
    label="TENANT CLUSTER  (no vendor controllers, no vendor credentials)";
    style=filled; color="#e8f5e9"; fontsize=12;
    pvc [label="PVC\nsc: osac-vast-gold"];
    ep [label="external-provisioner\n/ external-attacher", fillcolor="#f0f0f0"];
    csictrl [label="OSAC CSI Controller\n(Deployment)", fillcolor="#dbeafe"];
    subgraph cluster_node {
      label="worker node"; style=filled; color="#f1f8e9";
      csinode [label="OSAC CSI Node\n(DaemonSet)", fillcolor="#dbeafe"];
      vastnode [label="VAST node plugin\n(vendor socket)", fillcolor="#fff3cd"];
      csinode -> vastnode [label="route by\nosac.backend=vast"];
    }
    pvc -> ep; ep -> csictrl;
  }
  subgraph cluster_hub {
    label="HUB CLUSTER  (control plane + vendor controllers + credentials)";
    style=filled; color="#e3f2fd"; fontsize=12;
    subgraph cluster_fs {
      label="fulfillment-service"; style=filled; color="#ede7f6"; fontsize=11;
      volapi [label="Volume API\n(Create / Delete)", fillcolor="#d1c4e9"];
      cpapi [label="Storage Control Plane API\n(Publish / Unpublish)", fillcolor="#d1c4e9"];
    }
    volcr [label="Volume CR", fillcolor="#fce4ec"];
    opctrl [label="Volume Controller\n(osac-operator)", fillcolor="#c8e6c9"];
    opfb [label="Feedback Controller", fillcolor="#c8e6c9"];
    vastctrl [label="VAST CSI Controller\n(vendor, on hub)", fillcolor="#fff3cd"];
    volapi -> volcr [label="reconciler creates"];
    opctrl -> volcr [label="reconciles", dir=back];
    opctrl -> vastctrl [label="vendor CreateVolume\n(+ credentials)"];
    opfb -> volapi [label="sync status"];
  }
  array [label="VAST Array", shape=cylinder, fillcolor="#c9e0ff"];
  csictrl -> volapi [label="ONE cross-cluster gRPC connection\nVolume API (Create/Delete) +\nStorage Control Plane API (Publish/Unpublish)", lhead=cluster_fs];
  vastctrl -> array;
  vastnode -> array [label="iSCSI / NFS mount"];
}
'''

D_VAST_PROV = r'''
digraph G {
  rankdir=LR; fontname="Helvetica"; node [fontname="Helvetica", fontsize=10, shape=box, style="filled,rounded", fillcolor=white];
  edge [fontname="Helvetica", fontsize=9];
  pvc [label="1. PVC created\n(tier=gold)"];
  csi [label="2. OSAC CSI ctrl\nCreateVolume", fillcolor="#dbeafe"];
  api [label="3. Volume API\nresolve tier, policy,\npersist (CREATING)", fillcolor="#d1c4e9"];
  cr  [label="4. Volume CR\non hub", fillcolor="#fce4ec"];
  op  [label="5. operator\nreads creds,\ncalls vendor", fillcolor="#c8e6c9"];
  vast [label="6. VAST ctrl\ncreate on array", fillcolor="#fff3cd"];
  fb  [label="7. feedback →\nAPI: AVAILABLE", fillcolor="#c8e6c9"];
  poll [label="8. CSI polls\nGetVolume →\nvolume_context", fillcolor="#dbeafe"];
  pv  [label="9. PV created,\nPVC bound"];
  pvc -> csi -> api -> cr -> op -> vast -> fb -> poll -> pv;
}
'''

D_APIFIRST = r'''
digraph G {
  rankdir=TB; fontname="Helvetica"; node [fontname="Helvetica", fontsize=11, shape=box, style="filled,rounded"];
  edge [fontname="Helvetica", fontsize=10];
  subgraph cluster_a {
    label="VAST: API-first works"; style=filled; color="#e8f5e9"; fontsize=12;
    a1 [label="POST /volumes\n(tier=gold, 100Gi)\nNO consumer yet", fillcolor=white];
    a2 [label="VAST array carves\na 100Gi volume\n(exists on network)", fillcolor="#c9e0ff"];
    a3 [label="later: VolumeAttachment\nbinds it to a PVC/pod\non any node", fillcolor=white];
    a1 -> a2 -> a3 [label="OK"];
  }
  subgraph cluster_b {
    label="LVMS: API-first is IMPOSSIBLE"; style=filled; color="#fde8e8"; fontsize=12;
    b1 [label="POST /volumes\n(tier=local, 100Gi)\nNO consumer yet", fillcolor=white];
    b2 [label="which node?\nno pod scheduled →\nno node → no VG", fillcolor="#ffd0d0"];
    b3 [label="cannot carve an LV\nwithout a target node", fillcolor="#ffd0d0"];
    b1 -> b2 [label="?"]; b2 -> b3 [label="dead end", color="#cc0000", fontcolor="#cc0000"];
  }
}
'''

D_OPT_A = r'''
digraph G {
  rankdir=LR; fontname="Helvetica"; compound=true;
  node [fontname="Helvetica", fontsize=10, shape=box, style="filled,rounded", fillcolor=white];
  edge [fontname="Helvetica", fontsize=9];
  subgraph cluster_t {
    label="TENANT CLUSTER"; style=filled; color="#e8f5e9"; fontsize=11;
    pvc [label="PVC (WaitForFirstConsumer)\npod scheduled → node X"];
    csi [label="OSAC CSI ctrl\nextract node X", fillcolor="#dbeafe"];
    topc [label="topolvm-controller\n(MUST live here —\nnode-local)", fillcolor="#ffe0b2"];
    topn [label="topolvm-node\ncarves LV on X", fillcolor="#fff3cd"];
  }
  subgraph cluster_h {
    label="HUB CLUSTER"; style=filled; color="#e3f2fd"; fontsize=11;
    api [label="Volume API\n+ node_hint (new)", fillcolor="#d1c4e9"];
    cr  [label="Volume CR\n+ node_hint", fillcolor="#fce4ec"];
    op  [label="operator\nlvms dispatch (new)", fillcolor="#c8e6c9"];
  }
  pvc -> csi;
  csi -> api [label="CreateVolume\n(node_hint=X)", lhead=cluster_h];
  api -> cr -> op;
  op -> topc [label="cross-cluster hop\nBACK to tenant", color="#cc0000", fontcolor="#cc0000", ltail=cluster_h];
  topc -> topn [label="LogicalVolume CR (node X)"];
}
'''

D_OPT_B = r'''
digraph G {
  rankdir=LR; fontname="Helvetica"; compound=true;
  node [fontname="Helvetica", fontsize=10, shape=box, style="filled,rounded", fillcolor=white];
  edge [fontname="Helvetica", fontsize=9];
  subgraph cluster_t {
    label="TENANT CLUSTER  (both controllers co-located)"; style=filled; color="#e8f5e9"; fontsize=11;
    pvc [label="PVC (WaitForFirstConsumer)\npod → node X"];
    csi [label="OSAC CSI ctrl\nresolve tier→lvms", fillcolor="#dbeafe"];
    topc [label="topolvm-controller\n(TCP Service)", fillcolor="#ffe0b2"];
    topn [label="topolvm-node\ncarves LV on X", fillcolor="#fff3cd"];
  }
  subgraph cluster_h {
    label="HUB"; style=filled; color="#e3f2fd"; fontsize=11;
    tier [label="tier lookup only\n(no Volume record)", fillcolor="#d1c4e9"];
  }
  pvc -> csi;
  csi -> tier [label="resolve tier=local", style=dashed];
  csi -> topc [label="PROXY CreateVolume\n(in-cluster, verbatim)", color="#1565c0", fontcolor="#1565c0"];
  topc -> topn [label="LogicalVolume CR (node X)\ntopology native"];
}
'''

D_OPT_C = r'''
digraph G {
  rankdir=LR; fontname="Helvetica";
  node [fontname="Helvetica", fontsize=10, shape=box, style="filled,rounded", fillcolor=white];
  edge [fontname="Helvetica", fontsize=9];
  subgraph cluster_t {
    label="TENANT CLUSTER  (OSAC control plane NOT in the path)"; style=filled; color="#e8f5e9"; fontsize=11;
    pvc [label="PVC\nsc: osac-lvms\nprovisioner: topolvm.io"];
    topc [label="topolvm-controller", fillcolor="#ffe0b2"];
    topn [label="topolvm-node\ncarves LV on X", fillcolor="#fff3cd"];
    pvc -> topc [label="native"]; topc -> topn [label="LogicalVolume CR"];
  }
  note [label="fulfillment / operator / OSAC CSI\n= not involved", shape=note, fillcolor="#f5f5f5"];
}
'''

# ------------------------------------------------------------------- prose ----

CSS = """
:root{--fg:#1a1a1a;--muted:#555;--line:#e0e0e0;--accent:#1565c0;--warn:#cc0000;}
*{box-sizing:border-box}
body{font-family:-apple-system,Segoe UI,Helvetica,Arial,sans-serif;color:var(--fg);
  max-width:960px;margin:0 auto;padding:40px 28px;line-height:1.55;font-size:16px}
h1{font-size:30px;border-bottom:3px solid var(--accent);padding-bottom:10px;margin-top:0}
h2{font-size:23px;margin-top:44px;border-bottom:1px solid var(--line);padding-bottom:6px}
h3{font-size:18px;margin-top:30px;color:#222}
h4{font-size:15px;margin-top:22px;color:var(--muted);text-transform:uppercase;letter-spacing:.03em}
code{background:#f4f4f4;padding:1px 5px;border-radius:4px;font-size:13.5px;
  font-family:ui-monospace,SFMono-Regular,Menlo,monospace}
pre{background:#f7f7f9;border:1px solid var(--line);border-radius:8px;padding:14px 16px;
  overflow-x:auto;font-size:13px;line-height:1.4}
pre code{background:none;padding:0}
table{border-collapse:collapse;width:100%;margin:18px 0;font-size:14.5px}
th,td{border:1px solid var(--line);padding:8px 11px;text-align:left;vertical-align:top}
th{background:#f0f4f8}
tr:nth-child(even) td{background:#fafbfc}
.diagram{margin:22px 0;padding:16px;background:#fff;border:1px solid var(--line);
  border-radius:10px;text-align:center;overflow-x:auto}
.diagram svg{max-width:100%;height:auto}
.tldr{background:#eef4fb;border-left:5px solid var(--accent);padding:16px 20px;border-radius:0 8px 8px 0;margin:22px 0}
.warn{background:#fdecea;border-left:5px solid var(--warn);padding:14px 18px;border-radius:0 8px 8px 0;margin:18px 0}
.ok{background:#eaf6ec;border-left:5px solid #2e7d32;padding:14px 18px;border-radius:0 8px 8px 0;margin:18px 0}
.tag{display:inline-block;font-size:12px;font-weight:600;padding:2px 9px;border-radius:12px;color:#fff}
.tA{background:#8e24aa}.tB{background:#1565c0}.tC{background:#2e7d32}
.small{color:var(--muted);font-size:13.5px}
ul{margin:8px 0}
.check{color:#2e7d32;font-weight:700}.cross{color:#cc0000;font-weight:700}
footer{margin-top:50px;border-top:1px solid var(--line);padding-top:16px;color:var(--muted);font-size:13px}
"""

def h(s): return html.escape(s)

BODY = f"""
<h1>OSAC Storage: LVMS as a CSI Backend — Options Analysis</h1>
<p class="small">Working document for the Storage WG · prepared for discussion · reflects merged code + in-flight PRs + the OSAC-2872 design as of review.</p>

<div class="tldr">
<b>TL;DR.</b> The OSAC Storage Control Plane (OSAC-2872) was designed exclusively for
<b>network-attached</b> arrays (VAST/NetApp/Pure). Its entire model — provision a Volume via the
API independently of any pod, vendor controllers on the hub, credential isolation — assumes the
storage is reachable from anywhere. <b>LVMS is node-local and sticky</b>: a volume physically lives
in a volume group on one node and can only be created once the consuming pod's node is known.
LVMS therefore <b>cannot</b> fit the design cleanly. The three options below are three different
<b>levels of compromise</b>, not three equivalent implementations. None makes LVMS behave like a
network tier. Crucially, <b>LVMS was introduced for a dev-only purpose</b> — giving developers
usable storage without a real backend array. That premise (not a "who is the user?" question)
should drive the decision: it removes any hard requirement for tenant-facing inventory, quota, or a
uniform provisioner, and points away from the heaviest option.
</div>

<h2>1. Background: how the OSAC Storage Control Plane works (network-attached)</h2>
<p>Four repos plus the installer make up the storage control plane. The key design principles,
quoted from the OSAC-2872 design:</p>
<ul>
<li><b>Asynchronous, declarative Volume API.</b> The CSI driver calls <code>CreateVolume</code>,
which persists a record and returns immediately. A reconciler then creates a <code>Volume</code> CR
on the hub; the operator drives the vendor call; a feedback controller syncs status back.</li>
<li><b>"The tenant cluster has no vendor controllers and no vendor credentials."</b> All controller
operations route through the fulfillment-service. Vendor <b>controllers</b> run on the <b>hub</b>;
only vendor <b>node plugins</b> run on the tenant cluster.</li>
<li><b>"The CSI driver never connects directly to vendor controllers."</b> The CSI <b>node</b>
plugin <i>is</i> a proxy (it routes mount calls to a vendor node socket by
<code>volume_context["osac.backend"]</code>). The CSI <b>controller</b> is <i>not</i> a proxy — it
talks only to the fulfillment-service.</li>
</ul>

<h4>Deployment topology (VAST)</h4>
{svg(D_VAST_TOPO)}
<p class="small">Note where things live: vendor <b>controller</b> + credentials + operator on the
<b>hub</b>; vendor <b>node plugin</b> on the tenant worker. The OSAC CSI driver has exactly one
cross-cluster connection — to the fulfillment-service — and never to a vendor controller.</p>

<h2>2. Reference flow: VAST (network-attached) provisioning</h2>
{svg(D_VAST_PROV)}
<p class="small">This is the <b>CSI / PVC-driven</b> path (dynamic provisioning). The other entry is
<b>API-first</b>: the Volume is created via the API with no consumer, then a pre-provisioned PV
(<code>csi.volumeHandle = &lt;osac volume id&gt;</code>) is bound statically and
<code>CreateVolume</code> is never called. API-first is out of scope here — it is impossible for
LVMS (see §3.1) — so only the CSI-driven path is elaborated.</p>
<p>Numbered, matching the OSAC-2872 sequence:</p>
<pre><code>1. Tenant creates PVC (storageClassName: osac-&lt;vendor&gt;-gold)
2. external-provisioner → OSAC CSI Controller.CreateVolume(tier=gold, tenant, size, accessMode, clusterID)
3. Volume API: resolve tier→backend+protocol, OPA policy check, persist record (state=CREATING), return now
4. fulfillment reconciler (on pg_notify) creates a Volume CR on the HUB
5. operator Volume controller: reads tenant creds from hub Secret, calls vendor CSI CreateVolume
6. VAST CSI controller creates the volume on the array, returns vendor volume ID
7. feedback controller → Volume API: Update(state=AVAILABLE, vendor_volume_id) + Signal(id)
8. OSAC CSI polls GetVolume until AVAILABLE → returns volume_context{{osac.backend, osac.volume-id, osac.protocol}}
9. Kubernetes creates the PV (volume_context stored as spec.csi.volumeAttributes), binds the PVC</code></pre>
<p><b>Mount is a separate timeline</b>, triggered not by provisioning but by <b>a consumer being
scheduled onto a node</b> — a pod, or for VMaaS the KubeVirt VM's <code>virt-launcher</code> pod. It
repeats every time a consumer starts on a node; provisioning happens only once. Sequence: pod/VM
scheduled → <code>VolumeAttachment</code> created → external-attacher →
<code>ControllerPublishVolume</code> → Storage Control Plane API → operator → vendor
<code>ControllerPublishVolume</code> (attach); then kubelet → OSAC CSI <b>node</b> →
<code>NodeStageVolume</code> / <code>NodePublishVolume</code>, routed by
<code>osac.backend=vast</code> → VAST node plugin → iSCSI/NFS mount. <b>No control-plane call is made
from the node</b>; all routing is baked into <code>volume_context</code> at create time.</p>

<h2>3. Why LVMS does not fit: the node-local constraint</h2>
{svg(D_CONSTRAINT)}
<p>VAST is node-agnostic: the array is on the network, any node mounts it. LVMS is the opposite —
the volume is an LV carved from a volume group <b>on one specific node</b>, and it is only reachable
from that node. Consequences that ripple through the whole architecture:</p>
<ul>
<li><b><code>WaitForFirstConsumer</code> is mandatory.</b> You cannot pick where to put the volume
until the scheduler picks the pod's node.</li>
<li><b>Topology must flow end-to-end.</b> Scheduler picks node X → CSI
<code>CreateVolume</code> receives <code>accessibility_requirements.preferred=[{{topology.topolvm.io/node: X}}]</code>
→ provisioning must target X → the response's <code>accessible_topology</code> pins the PV to X.</li>
<li><b>Node affinity must be propagated to the PV.</b> The <b>LV</b> (the LVM block device) is
physically on node X — that's a given. The challenge is making Kubernetes aware of it: the <b>PV</b>
must carry <code>spec.nodeAffinity=node X</code> so the scheduler
only places consumers there. A VAST PV has no node affinity (mountable anywhere); an LVMS PV must be
pinned to node X for its lifetime, and that pin has to be threaded through the provisioning path.</li>
</ul>

<h3>3.2 Deployment asymmetry: why the vendor-controller-on-hub model breaks for LVMS</h3>
<p>A CSI driver is two halves — a <b>controller</b> (Deployment) and a <b>node plugin</b>
(DaemonSet). OSAC splits them deliberately:</p>
<table>
<tr><th>Piece</th><th>Where it runs</th><th>Why</th></tr>
<tr><td>Vendor <b>controller</b> (VAST/NetApp/Pure)</td><td><b>Hub</b></td><td>Credential isolation — vendor creds stay on the hub, never reach the tenant cluster. The controller just makes a <b>network API call to the array</b>, so it doesn't matter where nodes are.</td></tr>
<tr><td>Vendor <b>node plugin</b></td><td><b>Tenant / CaaS</b></td><td>Must run where the mounts happen; reached by the OSAC node plugin via socket routing.</td></tr>
<tr><td><b>OSAC</b> CSI driver (controller + node)</td><td><b>Tenant / CaaS</b> (and the hub too, per the passthrough proposal)</td><td>That's where tenant PVCs are. Its only cross-cluster reach is one gRPC connection to the fulfillment-service.</td></tr>
</table>
<p><b>topolvm-controller cannot follow the vendor-controller-on-hub pattern.</b> Unlike VAST's
controller (which makes a network call to a remote array), topolvm-controller on
<code>CreateVolume</code> <b>creates a <code>LogicalVolume</code> CR in its own cluster's API</b>,
which the <b>topolvm-node DaemonSet in that same cluster</b> watches and acts on, and its scheduling
reads <b>that cluster's node VG capacity</b>. It operates entirely within one cluster and can only
manage that cluster's own nodes. Run it on the hub and it would target hub nodes, not tenant nodes.
So it <b>must</b> live on the tenant cluster — exactly where OSAC-3011/3234 already install LVMS.
This is the concrete reason Option A's "operator on the hub calls the vendor controller" model
does not translate to LVMS.</p>

<h3>3.3 How a CSI controller is normally reached (context for Option B)</h3>
<p>A CSI controller pod contains the vendor plugin container <b>plus</b> the CSI sidecars
(external-provisioner, external-attacher, external-resizer). The plugin serves its CSI gRPC over a
<b>unix-domain socket on an in-pod <code>emptyDir</code></b>, and the <b>only clients are those
co-located sidecars</b>. external-provisioner watches PVCs → calls <code>CreateVolume</code> on the
socket; external-attacher watches VolumeAttachments → calls <code>ControllerPublish</code>. Nothing
outside the pod ever talks to topolvm-controller; it is never on the network. That is why any option
where a <i>different</i> pod (the OSAC CSI controller) drives topolvm-controller needs a new access
path — see Option B.</p>

<h3>3.1 The deepest mismatch: API-first provisioning</h3>
<p>With <code>pvc_ref</code> now removed from the Volume API (PR #341, merged) and a future
<b>VolumeAttachment</b> object (OSAC-3278) taking over the Volume↔PVC linkage, the OSAC Volume
lifecycle is <b>decoupled from pods</b>. The canonical path becomes <b>API-first</b>: create a
Volume with no consumer, attach it later. This is natural for a network array — and
<b>structurally impossible for LVMS</b>.</p>
{svg(D_APIFIRST)}
<p class="small">This is the single strongest architectural argument: the direction the Volume API is
evolving (provision-in-advance, pod-independent) is exactly the direction LVMS cannot follow. For
LVMS the <b>only</b> viable entry point is the CSI + <code>WaitForFirstConsumer</code> path, where a
node exists at provision time. The pure-API path must be forbidden for local tiers.</p>

<h2>4. The three options</h2>

<h3><span class="tag tA">Option A</span> Full chain — CSI → fulfillment → Volume CR → operator → topolvm</h3>
{svg(D_OPT_A)}
<h4>Components</h4>
<p>OSAC CSI controller (+ topology extraction), Volume API (+ a new <code>node_hint</code>/topology
field), Volume CR (+ <code>node_hint</code>), operator Volume controller (+ an lvms
<code>VendorProvisioner</code>), topolvm on the tenant cluster, OSAC CSI node (+ topology labels).</p>
<h4>Data flow</h4>
<pre><code>1. Pod scheduled → node X (WaitForFirstConsumer)
2. OSAC CSI ctrl extracts node X from accessibility_requirements
3. → fulfillment.CreateVolume(tier=local, size, accessMode, node_hint=X)   [Volume API needs new field]
4. tier resolution → backend=lvms; DB record; Volume CR on HUB (spec: ..., node_hint=X)
5. operator lvms dispatch → creates a LogicalVolume CR targeting node X ON THE TENANT CLUSTER
6. operator polls LV ready → Volume CR status (AVAILABLE); feedback → DB
7. OSAC CSI polls GetVolume → volume_context + accessible_topology=[node X]
8. node plugin routes osac.backend=lvms → topolvm-node socket → mount</code></pre>
<div class="warn">
<b>Two structural problems.</b> (1) <b>Control-flow round-trip:</b> the request climbs from the
tenant cluster to the hub (fulfillment + CR + operator), then the operator must reach
<b>back down into the tenant cluster</b> to create the LogicalVolume on node X — for a purely local
operation the hub has no part in. (2) <b>topolvm-controller cannot live on the hub</b> where VAST's
controller lives; it must run on the tenant cluster with the nodes and VGs. So step 5 is either the
operator <b>reimplementing topolvm-controller's job</b> (fragile, duplicative) or the operator
<b>delegating to topolvm-controller</b> — in which case <b>Option A = Option B plus fulfillment/CR/
operator bookkeeping and a cross-cluster hop.</b>
</div>
<h4>Pros</h4>
<ul><li><span class="check">✓</span> Full volume inventory in the OSAC DB</li>
<li><span class="check">✓</span> Quota enforcement possible</li>
<li><span class="check">✓</span> One provisioner name (<code>osac-csi</code>) — looks uniform to the tenant</li></ul>
<h4>Cons</h4>
<ul><li><span class="cross">✗</span> Needs a new topology field in the Volume API (Volume API owner / OSAC-3273/3280) — not there today</li>
<li><span class="cross">✗</span> Needs an operator lvms provisioner — not there today</li>
<li><span class="cross">✗</span> Cross-cluster reach hub→tenant to create the LV</li>
<li><span class="cross">✗</span> <b>Still</b> cannot support API-first / provision-in-advance (§3.1) — no VAST parity despite the most work</li>
<li><span class="cross">✗</span> Most engineering of the three</li></ul>

<h3><span class="tag tB">Option B</span> Passthrough — CSI controller forwards local provisioning to topolvm</h3>
{svg(D_OPT_B)}
<h4>Two realizations (confirm which with the proposer — they differ in what must be exposed)</h4>
<table>
<tr><th></th><th>B1 · gRPC proxy</th><th>B2 · CRD create</th></tr>
<tr><td>OSAC CSI ctrl does</td><td>Proxies the CSI <code>CreateVolume</code> RPC to topolvm-controller</td><td>Directly creates a topolvm <code>LogicalVolume</code> CR</td></tr>
<tr><td>Requires</td><td>topolvm-controller exposed via a <b>TCP Service</b> (non-standard)</td><td>A <b>k8s client + RBAC</b> in the CSI driver (none today)</td></tr>
<tr><td>Security surface</td><td>Network-exposes a normally in-pod socket</td><td>RBAC to create one CRD type</td></tr>
<tr><td>Note</td><td>Bypasses topolvm's own provisioner sidecar</td><td>Reimplements the thin part of topolvm-controller (CR creation)</td></tr>
</table>
<p class="small"><b>Sidecar nuance:</b> with StorageClass <code>provisioner: osac-csi</code>, <b>OSAC's</b>
external-provisioner sidecar handles the PVC and topolvm's own provisioner sidecar sits idle (it only
watches <code>provisioner: topolvm.io</code>). So Option B effectively <b>replaces topolvm's
provisioner sidecar with a cross-pod hop</b> (B1) or with direct CR creation (B2).</p>
<h4>Components</h4>
<p>OSAC CSI controller (+ an lvms proxy branch), fulfillment (tier-resolution lookup only, no Volume
record), topolvm-controller exposed via a TCP Service, OSAC CSI node (existing socket routing).</p>
<h4>Data flow</h4>
<pre><code>1. Pod scheduled → node X
2. OSAC CSI ctrl: resolve tier=local → backend=lvms + topolvm-controller endpoint
3. OSAC CSI ctrl PROXIES CreateVolume verbatim → topolvm-controller (in-cluster)
4. topolvm-controller creates the LogicalVolume on node X, returns AccessibleTopology natively
5. OSAC CSI returns topolvm's response, adding volume_context{{osac.backend=lvms}}
6. node plugin routes osac.backend=lvms → topolvm-node socket → mount</code></pre>
<div class="warn">
<b>This is the design's rejected Alternative 3</b> ("CSI driver proxies vendor calls / client-side
orchestration"). It was rejected for <b>credential isolation</b> — vendor credentials would transit
the tenant cluster. <b>But LVMS has no vendor credentials</b> (local disk, no array API, no Secret),
so the specific reason for the rejection <b>does not apply to LVMS.</b> That makes B a defensible
exception rather than a violation.
</div>
<p class="small"><b>Co-location detail:</b> on both shapes the OSAC CSI controller and
topolvm-controller are on the <b>same</b> cluster (CaaS: both on the guest cluster per OSAC-3234;
VMaaS/hub: both on the hub per OSAC-3011), so the path is an <b>in-cluster</b> hop — strictly
simpler than A's cross-cluster reach. The one new mechanic applies to <b>B1 only</b>:
topolvm-controller isn't network-exposed by default (its csi-provisioner sidecar uses an in-pod unix
socket), so a TCP Service must be added — pre-condition to confirm with the CSI driver owner / topolvm. <b>B2</b>
sidesteps this entirely (create the <code>LogicalVolume</code> CR directly; needs only RBAC).</p>
<h4>Pros</h4>
<ul><li><span class="check">✓</span> No dependency on the operator lvms path or a new Volume-API field</li>
<li><span class="check">✓</span> Topology "just works" — topolvm owns it natively</li>
<li><span class="check">✓</span> Low latency (direct, in-cluster); provisioner name stays <code>osac-csi</code></li>
<li><span class="check">✓</span> The credential-isolation objection is moot for LVMS</li></ul>
<h4>Cons</h4>
<ul><li><span class="cross">✗</span> No Volume record → no inventory, no quota for LVMS</li>
<li><span class="cross">✗</span> The controller behaves differently per backend (proxy for lvms, full-chain for network) — a split path to maintain</li>
<li><span class="cross">✗</span> New exposure: TCP Service for topolvm-controller (B1) or a CR-creation RBAC client in the CSI driver (B2)</li></ul>

<h3><span class="tag tC">Option C</span> Native — keep the topolvm/AAP path, OSAC not in the LVMS path</h3>
{svg(D_OPT_C)}
<h4>Components</h4>
<p>A topolvm StorageClass created by AAP (already shipped via OSAC-3011/3234),
<code>provisioner: topolvm.io</code>. The OSAC CSI driver, fulfillment, and operator are not
involved in the LVMS path at all.</p>
<h4>Data flow</h4>
<pre><code>PVC (sc=osac-lvms, WaitForFirstConsumer) → topolvm-controller → LogicalVolume → topolvm-node → LV
(zero OSAC control-plane involvement)</code></pre>
<h4>Pros</h4>
<ul><li><span class="check">✓</span> Zero new work — already functional and merged</li>
<li><span class="check">✓</span> Correct by construction (topolvm as designed); no new security surface, no cross-cluster hops</li>
<li><span class="check">✓</span> Honest about LVMS being a different category</li></ul>
<h4>Cons</h4>
<ul><li><span class="cross">✗</span> StorageClass provisioner is <code>topolvm.io</code>, not <code>osac-csi</code> — an <b>abstraction leak</b> (tenant sees LVMS internals)</li>
<li><span class="cross">✗</span> No OSAC inventory or quota for LVMS</li>
<li><span class="cross">✗</span> Two visibly different tenant UXes (local tier vs network tiers)</li></ul>

<h2>5. Side-by-side comparison</h2>
<p>Every row where a "network parity" property is <span class="cross">✗</span> is a compromise that
<b>no option removes</b> — because they stem from LVMS being node-local, not from implementation choices.</p>
<table>
<tr><th>Dimension</th><th>VAST (reference)</th><th class="tA">A · Full chain</th><th class="tB">B · Passthrough</th><th class="tC">C · Native</th></tr>
<tr><td>OSAC volume inventory</td><td class="check">✓</td><td class="check">✓</td><td class="cross">✗</td><td class="cross">✗</td></tr>
<tr><td>Quota enforcement</td><td class="check">✓</td><td class="check">✓</td><td class="cross">✗</td><td class="cross">✗</td></tr>
<tr><td>Provisioner = <code>osac-csi</code></td><td class="check">✓</td><td class="check">✓</td><td class="check">✓</td><td class="cross">✗ (topolvm.io)</td></tr>
<tr><td>API-first / provision-in-advance</td><td class="check">✓</td><td class="cross">✗</td><td class="cross">✗</td><td class="cross">✗</td></tr>
<tr><td>Topology handled by</td><td>n/a</td><td>OSAC (4 layers)</td><td>topolvm</td><td>topolvm</td></tr>
<tr><td>Cross-cluster reach needed</td><td class="check">✓ (by design)</td><td class="cross">✗ hub→tenant</td><td>in-cluster only</td><td>none</td></tr>
<tr><td>New security surface</td><td>—</td><td>operator→tenant</td><td>topolvm TCP Service</td><td>none</td></tr>
<tr><td>Follows OSAC-2872 design</td><td class="check">✓</td><td>partly</td><td>rejected Alt. 3*</td><td>rejected Alt. 4</td></tr>
<tr><td>New engineering</td><td>—</td><td>Highest</td><td>Medium</td><td>~None</td></tr>
</table>
<p class="small">* Alternative 3 was rejected for credential isolation, which does not apply to LVMS.</p>

<h2>6. Open questions for the WG</h2>
<p class="small"><b>Settled premise:</b> LVMS is dev-only (usable storage without a real backend
array). So there is no tenant-facing requirement for inventory, quota, or a uniform provisioner —
which removes the only justification for Option A. The remaining questions are about B vs C.</p>
<ol>
<li><b>Does the tenant-visible provisioner name matter even for dev use?</b> (<code>osac-csi</code>
vs <code>topolvm.io</code>) — if no, C is sufficient; if we want dev flows to exercise the real
osac-csi path, B.</li>
<li><b>Do we want dev flows to exercise the OSAC CSI path at all</b> (so dev testing mirrors the
network-backend path), or is native topolvm fine for dev?</li>
<li><b>[B pre-condition]</b> Which realization — B1 (expose topolvm-controller via a TCP Service) or
B2 (CSI driver creates the <code>LogicalVolume</code> CR directly, RBAC only)? Confirm with the CSI
driver owner / topolvm.</li>
<li><b>Are we OK maintaining a split controller path (B)</b> long term — passthrough for lvms,
full-chain for network backends?</li>
</ol>
<p class="small">Option A is retained below for completeness only; the dev-only premise rules it out.</p>

<h2>7. Recommendation</h2>
<div class="ok">
<b>Given the dev-only premise, it's B vs C.</b> <b>Option C</b> is already done and correct — if
native topolvm (provisioner <code>topolvm.io</code>) is acceptable for dev use, stop there.
<b>Option B</b> is worth it only if we want dev flows to exercise the real <code>osac-csi</code> path
(so dev testing mirrors the network-backend experience) — topology is correct for free and the
credential objection is moot for LVMS; the split path is the only real cost. Prefer the <b>B2</b>
realization (direct <code>LogicalVolume</code> CR creation, RBAC only) over B1 (TCP-exposing
topolvm-controller). <b>Option A is ruled out</b> by the dev-only premise: it buys tenant-facing
inventory/quota nobody needs here, and still cannot achieve VAST parity (API-first is impossible for
LVMS regardless) — A-delegate is just B plus bookkeeping and a cross-cluster hop, A-reimplement
duplicates topolvm-controller.
</div>

<h2>Appendix A — Verified current code state</h2>
<table>
<tr><th>Area</th><th>State (verified)</th></tr>
<tr><td>VolumeSpec proto</td><td><code>storage_tier, size_gib, access_mode</code> only. <code>pvc_ref</code> removed (PR #341 merged). No topology/<code>node_hint</code> field.</td></tr>
<tr><td>Tier resolution</td><td>Merged (PR #342): Volume Create resolves tier→backend+protocol, writes <code>status.backend</code>/<code>status.protocol</code>.</td></tr>
<tr><td>OSAC CSI controller</td><td>Delegates to fulfillment VolumeClient (PR #141 merged). No topology extraction, no <code>AccessibleTopology</code> in response, no <code>VOLUME_ACCESSIBILITY_CONSTRAINTS</code> capability.</td></tr>
<tr><td>OSAC CSI node</td><td>Routes mount to a vendor socket by <code>osac.backend</code> (proxy.Manager). <code>NodeGetInfo</code> returns only <code>node_id</code> — no topology labels.</td></tr>
<tr><td>operator Volume controller</td><td>PR #340 (open): <code>VendorProvisioner</code> interface, currently nil. No lvms/topolvm/LogicalVolume awareness anywhere in the codebase.</td></tr>
<tr><td>Volume reconciler (fulfillment)</td><td>PR #339 (open).</td></tr>
<tr><td>Vendor CSI controllers deploy</td><td>PR #188 (open): csi-backends Helm chart (VAST/Trident/Pure) — network backends only.</td></tr>
</table>

<h2>Appendix B — What OSAC-3702 must add on the CSI side (any of A/B)</h2>
<ul>
<li><code>ControllerGetCapabilities</code> += <code>VOLUME_ACCESSIBILITY_CONSTRAINTS</code> (required for WaitForFirstConsumer)</li>
<li><code>CreateVolume</code>: extract <code>accessibility_requirements.preferred[0]</code>, return <code>AccessibleTopology</code></li>
<li><code>NodeGetInfo</code>: return <code>topology.topolvm.io/node=&lt;nodeID&gt;</code></li>
<li>Helm: mount the topolvm-node socket into the OSAC CSI node container; register <code>lvms=&lt;socket&gt;</code> in <code>--vendor-sockets</code></li>
</ul>

<footer>
Sources: OSAC-2872 storage-control-plane design.md (authoritative), verified against merged code
(PR #141/#341/#342) and open PRs (#339/#340/#188), OSAC-1110 StorageTier design (single-backend-per-tier),
OSAC-3011/3234 (LVMS install). Diagrams rendered locally with graphviz.
</footer>
"""

DOC = f"""<!DOCTYPE html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>OSAC Storage — LVMS as a CSI Backend</title><style>{CSS}</style></head>
<body>{BODY}</body></html>"""

_base = "/home/zszabo/projects/osac-workspace/artifacts/lvms-csi/lvms-csi-options"
_out = _base + (".png.html" if IMG_MODE == "png" else ".html")
with open(_out, "w") as f:
    f.write(DOC)
print("wrote", _out, len(DOC), "bytes", "(IMG_MODE=%s)" % IMG_MODE)
