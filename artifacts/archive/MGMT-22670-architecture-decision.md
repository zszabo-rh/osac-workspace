# Serial Console Access — Architecture Options

**Jira:** [MGMT-22670](https://issues.redhat.com/browse/MGMT-22670)
**Goal:** Allow tenants to access the serial console of their VMs and bare metal hosts from the CLI

## Context

OSAC has two resource types that need serial console access:

| Resource | CLI noun | Backend | Console mechanism |
|----------|----------|---------|-------------------|
| **ComputeInstance** (VM) | `computeinstance` | KubeVirt on hub cluster | WebSocket to KubeVirt subresource API |
| **Host** (bare metal) | `host` | ESI / Ironic | IPMI Serial-over-LAN (SOL) |

The bare metal enhancement proposal explicitly calls this out:

> *"We would like to implement a solution for serial console access that can be utilized by both the bare metal service and the virtual machine service."* — `enhancement-proposals/enhancements/bare-metal-fulfillment/README.md`

MGMT-22670 covers VMs (ComputeInstance) first, but the architecture should not be KubeVirt-specific. The proxy / session layer must support pluggable backends so that bare metal console (IPMI SOL via ESI) can be added later without rearchitecting.

Target UX:

```bash
fulfillment-cli console computeinstance <id>   # VM serial console (v1)
fulfillment-cli console host <id>              # BM serial console (future)
```

All options share the same CLI and proto work — the difference is where the data plane (streaming bytes between user and console backend) lives.

### Design constraint: backend abstraction

Whichever option is chosen, the console infrastructure must have a **backend interface** so that different resource types can plug in their own connection logic:

- **KubeVirt backend** — opens a WebSocket to `/apis/subresources.kubevirt.io/v1/namespaces/{ns}/virtualmachineinstances/{name}/console` on the hub cluster
- **IPMI SOL backend** (future) — connects to the bare metal host's serial console via ESI/Ironic APIs

The fulfillment-service (or console-proxy, depending on option) resolves the resource type and delegates to the appropriate backend. The CLI and proto layer are resource-type-aware but backend-agnostic.

### Prerequisite (all options)

The fulfillment-service currently cannot resolve a ComputeInstance ID to its physical location (hub, namespace, VM name). The operator tracks this in the CR status, but the feedback controller doesn't sync it back to the fulfillment-service. This must be added first — a small change to the private proto and the feedback controller.

## Options

### Option A: Inline Proxy (fulfillment-service proxies the console)

> Options B and C were considered early on but ruled out — included here for completeness.

```
CLI ──gRPC bidi stream──► fulfillment-service ──WebSocket──► KubeVirt (hub)
                                               ──IPMI SOL──► ESI/Ironic (future)
```

The fulfillment-service handles auth, resolves the resource location, selects the appropriate backend (KubeVirt or IPMI SOL), and proxies bytes over a bidirectional gRPC stream back to the CLI.

**Changed components:**
- **fulfillment-api** — new `ConsoleConnect` streaming RPC, `GetConsoleAccess` unary RPC (resource-type-aware: works for both `computeinstance` and `host`)
- **fulfillment-service** — new `internal/console/` package (session manager, backend interface, KubeVirt backend, bidirectional proxy)
- **fulfillment-cli** — new `console computeinstance` and `console host` commands with raw terminal handling

**Pros:**
- Single entry point — no new services to deploy
- Centralized audit logging (connect/disconnect/errors all in one place)
- Users need no network access to hub clusters
- Consistent with existing OSAC access model

**Cons:**
- Mixes control plane (CRUD RPCs) with data plane (long-lived streaming sessions) in the same process — changes the service's operational profile (memory, goroutines, crash recovery)
- Rolling restarts of fulfillment-service drop active console sessions
- Scalability ceiling — each session holds resources on the fulfillment-service; heavy console usage competes with API traffic
- Double hop adds latency (CLI → service → hub)

---

### Option B: Token-based Direct Access (expose KubeVirt behind a route)

```
CLI ──gRPC unary──► fulfillment-service    (auth + resolve + issue token)
CLI ──WebSocket──────────────────────────► KubeVirt route (hub)
```

The fulfillment-service authenticates the user, resolves the VM, and returns a short-lived token plus the URL of a KubeVirt console route exposed on the hub cluster. The CLI connects directly to that route.

**Changed components:**
- **fulfillment-api** — new `GetConsoleAccess` unary RPC
- **fulfillment-service** — token issuer
- **fulfillment-cli** — new `console computeinstance` command with WebSocket client
- **hub cluster** — new OpenShift Route or Ingress exposing the KubeVirt console subresource endpoint

**Pros:**
- Simple service-side implementation (no proxy)
- Low latency (direct connection)

**Cons:**
- **Requires exposing KubeVirt API endpoints externally** — significant security surface increase on every hub cluster
- Token scoping is difficult — KubeVirt's console subresource uses Kubernetes RBAC, so the token must be a valid K8s token (similar to Option D but without the per-VMI RBAC scoping)
- Each hub needs an externally-reachable route with TLS, maintained per-hub
- Audit logging relies on hub-side mechanisms
- Users need network access to each hub's route

**Verdict:** Rejected — exposing KubeVirt endpoints externally is a security concern, and without per-VMI RBAC scoping this is strictly worse than Option D. Additionally, this approach is KubeVirt-specific and would not extend to bare metal console access.

---

### Option C: virtctl Integration (CLI shells out to virtctl)

```
CLI ──exec──► virtctl console <vm-name> --kubeconfig=<hub-kubeconfig>
```

The CLI retrieves a kubeconfig for the hub cluster (similar to `get kubeconfig` for hosted clusters) and shells out to `virtctl`, the official KubeVirt CLI tool, to establish the console connection.

**Changed components:**
- **fulfillment-api** — new RPC to retrieve a scoped hub kubeconfig
- **fulfillment-service** — kubeconfig issuer
- **fulfillment-cli** — new `console computeinstance` command that downloads kubeconfig and execs `virtctl`

**Pros:**
- Leverages battle-tested KubeVirt tooling — no custom WebSocket or terminal code
- Minimal new code in fulfillment-service

**Cons:**
- **Requires `virtctl` installed on the user's machine** — extra dependency, version management
- Users need network access to hub API servers (same as B/D)
- Kubeconfig management adds complexity (temp files, cleanup, security of kubeconfig at rest)
- Less control over UX — error messages, escape sequences, and behavior are virtctl's, not ours
- Harder to add audit logging or session limits

**Verdict:** Rejected — the external `virtctl` dependency is too heavy for end users, and the loss of UX control is undesirable. Also KubeVirt-specific — bare metal hosts have no virtctl equivalent. However, virtctl's approach can inform the WebSocket client implementation in other options.

---

### Option D: Scoped Credential Handoff (CLI connects directly to hub)

```
CLI ──gRPC unary──► fulfillment-service    (auth + resolve + issue credential)
CLI ──WebSocket──────────────────────────► KubeVirt (hub)
```

The fulfillment-service validates the user, resolves the resource location, creates a short-lived Kubernetes ServiceAccount on the hub (RBAC scoped to `virtualmachineinstances/console` for that one VMI), and returns the hub API endpoint + token. The CLI then connects directly to KubeVirt using client-go.

**Changed components:**
- **fulfillment-api** — new `GetConsoleAccess` unary RPC (returns hub endpoint + token + resource coordinates)
- **fulfillment-service** — credential issuer (creates scoped ServiceAccount on hub, sets short TTL)
- **fulfillment-cli** — new `console computeinstance` command with WebSocket client + raw terminal handling (needs `client-go` dependency)

**Pros:**
- No persistent connections through fulfillment-service — it stays a pure control plane
- Lowest latency (direct connection to hub)
- Simplest service-side implementation — no session management, no proxy, no drain logic
- Scales independently of fulfillment-service capacity
- Audit logging via Kubernetes audit logs on the hub

**Cons:**
- **Users must have network access to hub API servers** — if the fulfillment-service is the sole network entry point, this option is not viable
- CLI binary size increases (pulls in `client-go` + WebSocket libraries)
- Audit logs are split across hubs rather than centralized
- Scoped ServiceAccount lifecycle management (creation, cleanup, TTL enforcement)
- **KubeVirt-specific** — this approach relies on K8s RBAC and the KubeVirt subresource API. Bare metal console (IPMI SOL) does not go through the K8s API, so a separate mechanism would be needed for `console host`. This weakens the "unified console" goal.

---

### Option E: Dedicated Console Proxy Microservice

```
CLI ──gRPC unary──► fulfillment-service    (auth + resolve + issue session token)
CLI ──WebSocket──► console-proxy ──WebSocket──► KubeVirt (hub)
                                  ──IPMI SOL──► ESI/Ironic (future)
```

A separate lightweight `console-proxy` service handles the data plane. The fulfillment-service validates auth, resolves the resource location, issues a short-lived session token, and returns the console-proxy endpoint. The CLI connects to console-proxy via WebSocket, which validates the token, selects the appropriate backend (KubeVirt or IPMI SOL), and proxies bidirectionally.

**New/changed components:**
- **fulfillment-api** — new `GetConsoleAccess` unary RPC (returns console-proxy endpoint + session token)
- **fulfillment-service** — session token issuer (lightweight — no proxy logic)
- **console-proxy** (new service) — validates session tokens, selects backend (KubeVirt or IPMI SOL), manages connections, handles session lifecycle (timeouts, drain)
- **fulfillment-cli** — new `console computeinstance` command with WebSocket client + raw terminal handling
- **osac-installer** — deployment manifests for console-proxy

**Pros:**
- Clean control plane / data plane separation
- Fulfillment-service stays simple, unaffected by console session load
- Console-proxy scales horizontally and independently
- Can be restarted/upgraded without affecting API operations (and vice versa)
- Can be deployed per-hub for network locality
- Users don't need direct hub access

**Cons:**
- Additional component to build, deploy, and operate
- More complex deployment topology (new service, new route/ingress, TLS certs)
- Session token exchange adds a small amount of protocol complexity

---

## Comparison Matrix

Options B and C are included for completeness but are not recommended (see verdicts above).

| Concern | A (Inline) | B (Expose KubeVirt) | C (virtctl) | D (Credential Handoff) | E (Console Proxy) |
|---------|:-:|:-:|:-:|:-:|:-:|
| New services to deploy | 0 | 0 | 0 | 0 | 1 |
| Requires user → hub network access | No | **Yes** | **Yes** | **Yes** | No |
| Exposes KubeVirt API externally | No | **Yes** | No | No | No |
| External client-side dependency | None | None | **virtctl** | None | None |
| Fulfillment-service complexity | High | Low | Low | Low | Low |
| Data plane scalability | Coupled to API | Independent | Independent | Independent | Independent |
| Console survives service restart | No | Yes | Yes | Yes | Partial |
| Latency | Higher (2 hops) | Lowest | Lowest | Lowest | Medium (1 extra hop) |
| Centralized audit logging | Yes | No | No | No | Yes |
| CLI binary size impact | Minimal | Minimal | Minimal | Larger (client-go) | Minimal |
| Supports BM console (future) | Yes | No | No | No | Yes |
| Implementation effort | Medium | Medium | Low | Medium | Medium-High |

## Recommendation

Two factors drive the decision:

1. **Network topology:** Can tenant machines reach the hub Kubernetes API?
2. **Bare metal timeline:** Is `console host` (BM serial console via IPMI SOL) expected soon?

| Situation | Recommended option |
|-----------|-------------------|
| Users cannot reach hubs, BM console not near-term | **A** — simplest to ship; extract to E later if needed |
| Users cannot reach hubs, BM console is near-term | **E** — invest in the separate proxy now to avoid rework |
| Users can reach hubs, BM console not near-term | **D** — significantly simpler for VM-only case |
| Users can reach hubs, BM console is near-term | **A** or **E** — D won't extend to BM (IPMI SOL doesn't go through K8s API) |

Options B and C are not recommended regardless of topology (see verdicts above).

In all cases the proto and CLI should use a **resource-type-aware design** (`ConsoleResourceType` enum, dedicated `Console` service) so that adding BM support later requires only a new backend implementation, not API changes.
