# Project Plan: Serial Console Access from Fulfillment CLI

**Jira Issue:** [MGMT-22670](https://issues.redhat.com/browse/MGMT-22670)
**Epic:** MGMT-22625 (VMaaS - enhancement 1 implementation)
**Component:** OSAC

## Executive Summary

This plan covers serial console access for virtual machines (ComputeInstance) through the fulfillment-cli. The fulfillment-service proxies console connections to KubeVirt via bidirectional gRPC streaming (Option A). A backend abstraction layer keeps the door open for bare metal console support later, but BM is out of scope for this work.

```bash
fulfillment-cli console computeinstance <instance-id>
```

## Architecture

### Data Path

```
CLI (gRPC bidi stream, TLS)
  → OpenShift Route (TLS passthrough)
    → Envoy proxy (TLS termination)
      → fulfillment-service gRPC server
        → KubeVirt WebSocket console subresource (hub cluster)
```

The fulfillment-service handles authentication, resolves the VM location, opens a WebSocket to KubeVirt's console subresource API, and proxies bytes bidirectionally over a gRPC stream back to the CLI.

Source: `fulfillment-service/manifests/base/ingress-proxy/configmap.yaml`

### Envoy Timeout Constraint

The Envoy proxy routes gRPC requests with a default **300-second timeout**. Only `^.*/Watch$` (the Events stream) is exempted. The console streaming RPC must be similarly exempted or sessions will be killed after 5 minutes. See Phase 5 for the required Envoy config change.

### Resource Location Resolution

The fulfillment-service needs to resolve a ComputeInstance ID to a hub cluster + namespace + KubeVirt VM name. Currently:

- The operator stores this in the ComputeInstance CR status (`status.virtualMachineReference`)
- The feedback controller syncs status back to the fulfillment-service

**Gap:** The private `ComputeInstance` proto does not include VM reference fields. This must be added first (Phase 0).

### Backend Abstraction

The console infrastructure uses a `Backend` interface so that different resource types can plug in their own connection logic. In v1, only `KubeVirtBackend` is implemented. The interface is minimal — a single `Connect` method returning an `io.ReadWriteCloser`.

---

## Implementation Phases

### Phase 0: Resource Location Resolution (Prerequisite)

**Objective:** Ensure the fulfillment-service can resolve a ComputeInstance ID to hub + namespace + VM name.

**Deliverables:**

1. Add VM reference fields to the **private** ComputeInstance status proto:

```protobuf
// In fulfillment-service/proto/private/v1/compute_instance_type.proto
message ComputeInstanceVMReference {
  string hub_id = 1;
  string namespace = 2;
  string vm_name = 3;
}
```

2. Update the operator's feedback controller to populate these fields from `status.virtualMachineReference`

**Tasks:**
- [ ] Add `ComputeInstanceVMReference` message to private proto
- [ ] Add `vm_reference` field to private `ComputeInstanceStatus`
- [ ] Regenerate Go code
- [ ] Update operator feedback controller to send VM reference
- [ ] Verify VM reference flows through to fulfillment-service database

---

### Phase 1: API Design & Protocol Buffers

**Objective:** Define the gRPC API contract for console access

Console RPCs live in a **dedicated `Console` service** (new file `console_service.proto`) rather than being added to `ComputeInstances`. A `ConsoleResourceType` enum routes to the correct backend, allowing future resource types (e.g., bare metal Host) without duplicating RPCs.

```protobuf
service Console {
  // Bidirectional stream for console access. First message MUST be ConsoleConnectInit.
  // No google.api.http annotation — gRPC-Gateway does not support bidi streaming.
  rpc Connect(stream ConsoleConnectRequest) returns (stream ConsoleConnectResponse);

  // Check console availability without connecting.
  rpc GetAccess(GetConsoleAccessRequest) returns (GetConsoleAccessResponse) {
    option (google.api.http) = {
      get: "/api/fulfillment/v1/console/{resource_type}/{resource_id}/info"
    };
  }
}

enum ConsoleResourceType {
  CONSOLE_RESOURCE_TYPE_UNSPECIFIED = 0;
  CONSOLE_RESOURCE_TYPE_COMPUTE_INSTANCE = 1;
  CONSOLE_RESOURCE_TYPE_HOST = 2;  // Future: bare metal
}

message ConsoleConnectRequest {
  oneof payload {
    ConsoleConnectInit init = 1;
    ConsoleInput input = 2;
    ConsoleResize resize = 3;  // No-op for serial; forward-compat for VNC
  }
}

message ConsoleConnectInit {
  ConsoleResourceType resource_type = 1;
  string resource_id = 2;
  ConsoleType type = 3;
}

message ConsoleInput { bytes data = 1; }

message ConsoleResize { uint32 width = 1; uint32 height = 2; }

message ConsoleConnectResponse {
  oneof payload {
    ConsoleOutput output = 1;
    ConsoleStatus status = 2;
  }
}

message ConsoleOutput { bytes data = 1; }

message ConsoleStatus {
  ConsoleConnectionState state = 1;
  string message = 2;
}

enum ConsoleConnectionState {
  CONSOLE_CONNECTION_STATE_UNSPECIFIED = 0;
  CONSOLE_CONNECTION_STATE_CONNECTING = 1;
  CONSOLE_CONNECTION_STATE_CONNECTED = 2;
  CONSOLE_CONNECTION_STATE_DISCONNECTED = 3;
  CONSOLE_CONNECTION_STATE_ERROR = 4;
}

enum ConsoleType {
  CONSOLE_TYPE_UNSPECIFIED = 0;
  CONSOLE_TYPE_SERIAL = 1;
  CONSOLE_TYPE_VNC = 2;  // Future — not implemented in v1
}

message GetConsoleAccessRequest {
  ConsoleResourceType resource_type = 1;
  string resource_id = 2;
}

message GetConsoleAccessResponse {
  bool available = 1;
  string reason = 2;
  repeated ConsoleType supported_types = 3;
}
```

**Tasks:**
- [ ] Create `console_service.proto`
- [ ] Regenerate Go code (`make generate`)
- [ ] Update API documentation

---

### Phase 2: Fulfillment Service Implementation

**Objective:** Implement console proxy with pluggable backend

New package: `fulfillment-service/internal/console/`

```
internal/console/
├── manager.go              # Session management, backend dispatch
├── backend.go              # Backend interface
├── kubevirt_backend.go     # KubeVirt WebSocket connection
├── proxy.go                # Bidirectional stream proxy
└── types.go                # Types
```

**Backend interface:**

```go
type Backend interface {
    Connect(ctx context.Context, target Target) (io.ReadWriteCloser, error)
}

type Target struct {
    ResourceType string
    ResourceID   string
    HubID        string
    Namespace    string
    VMName       string
}
```

**Key behaviors:**
- Resolve ComputeInstance → verify `RUNNING` state → extract `vm_reference` → get hub kubeconfig
- KubeVirt backend connects to `/apis/subresources.kubevirt.io/v1/namespaces/{ns}/virtualmachineinstances/{name}/console`
- Track active sessions; reject if VMI console already in use (KubeVirt supports one session per VMI)
- Configurable session timeout (default 30 min, env var `OSAC_CONSOLE_SESSION_TIMEOUT`)
- Audit log all connections (connect, disconnect, errors) with user, tenant, resource
- Terminate session gracefully if JWT expires mid-session
- Drain active sessions on SIGTERM with configurable deadline (default 30s)

New gRPC handler: `fulfillment-service/internal/servers/console_server.go`

**Tasks:**
- [ ] Define `Backend` interface
- [ ] Implement `KubeVirtBackend`
- [ ] Implement `console.Manager` with backend dispatch
- [ ] Implement bidirectional stream proxy
- [ ] Add session timeout and concurrent session detection
- [ ] Integrate with existing auth/authz
- [ ] Add metrics (active sessions, duration histogram, error rate)
- [ ] Add audit logging
- [ ] Add graceful shutdown / session drain
- [ ] Implement `Console.Connect` and `Console.GetAccess` gRPC handlers

---

### Phase 3: CLI Implementation

**Objective:** Add `console computeinstance` command

```
fulfillment-cli console computeinstance <instance-id> [flags]

Flags:
  --timeout duration   Session timeout (default 30m)
```

Files:

```
fulfillment-cli/internal/cmd/console/
├── console.go              # Parent command
├── computeinstance.go      # VM console subcommand
└── stream.go               # gRPC streaming + terminal handling
```

**Terminal handling:**
- `golang.org/x/term` for raw mode; restore on exit via `defer` (including panic)
- Escape sequence: `\r~.` (SSH convention), handled **client-side only**
- Banner: `Connected to <id>. Escape character is '~'.`

**Auto-reconnect:**
- On transient gRPC errors (`Unavailable`, `Internal`): exponential backoff from 1s, capped at 30s, max 5 attempts
- Print: `Connection lost. Reconnecting (attempt 1/5)...`
- On permanent errors (`PermissionDenied`, `NotFound`, `Unauthenticated`) or explicit disconnect (`\r~.`, timeout): exit immediately

**Tasks:**
- [ ] Create `console` command group and `computeinstance` subcommand
- [ ] Implement terminal raw mode and escape sequence handling in `stream.go`
- [ ] Implement gRPC streaming client in `stream.go`
- [ ] Add auto-reconnect with exponential backoff
- [ ] Handle connection errors with actionable messages

---

### Phase 4: Testing

**Unit tests:**
- Console manager lifecycle, backend dispatch, KubeVirt backend (mocked)
- Escape sequence parser
- Auto-reconnect logic (transient vs permanent error classification)

**Integration tests:**
- End-to-end with mock KubeVirt WebSocket server (echo server)
- Auth/authz flows (valid user, wrong tenant, expired token)
- Timeout, concurrent session rejection, auto-reconnect on simulated drop

**E2E tests:**
- Full CLI → real KubeVirt VM console flow
- Cross-tenant isolation
- Network interruption + auto-reconnect

**Compatibility tests:** GNOME Terminal, tmux/screen, macOS Terminal.app, iTerm2; Linux VMs with `getty`, cloud-init serial output, VMs with no console listener

**Load test:** 50 concurrent sessions — measure memory, CPU, connection latency

**Tasks:**
- [ ] Unit tests for manager, backend dispatch, escape parser, reconnect logic, gRPC handlers
- [ ] Build mock KubeVirt WebSocket server
- [ ] Integration tests (mock KubeVirt, auth, reconnect)
- [ ] E2E tests in osac-test-infra
- [ ] Compatibility and load testing
- [ ] Manual QA on staging

---

### Phase 5: Documentation & Rollout

**Envoy route update (required before deployment):**

Add to `fulfillment-service/manifests/base/ingress-proxy/configmap.yaml`, **before** the default `grpc-server` catch-all:

```yaml
- name: console
  match:
    safe_regex:
      regex: ^/fulfillment\.v1\.Console/Connect$
  route:
    cluster: grpc-server
    timeout: 0s
    idle_timeout: 0s
```

**Other tasks:**
- [ ] Add Envoy route for console streaming
- [ ] Update CLI help text and user documentation
- [ ] Add architecture docs (backend interface for future BM)
- [ ] Update API reference
- [ ] Add monitoring dashboard and alerting
- [ ] Coordinate release

---

## Work Breakdown

| Phase | Task | Effort |
|-------|------|--------|
| **0** | Private proto + feedback controller update | S |
| **1** | `console_service.proto` + codegen | S |
| **2** | Backend interface + KubeVirt backend | M |
| **2** | Session manager + bidirectional proxy | M |
| **2** | gRPC handlers + auth + metrics + audit | M |
| **3** | CLI command + terminal handling | M |
| **3** | gRPC streaming client + auto-reconnect | M |
| **4** | Unit + integration tests + mock WebSocket server | M |
| **4** | E2E + compatibility + load tests | M |
| **5** | Envoy route + docs + monitoring | S |

**S** = < 1 day, **M** = 1-3 days

---

## Dependencies & Prerequisites

- `golang.org/x/term` — terminal handling (new dependency)
- KubeVirt API client — existing via client-go
- Hub kubeconfig access — existing via hub registry
- ComputeInstance VM reference — **requires Phase 0**
- KubeVirt serial console enabled on VMs — default in KubeVirt; `ocp_virt_vm` template does not disable it
- Network connectivity from fulfillment-service to hub clusters — existing

---

## Risk Assessment

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Envoy timeout kills sessions | High | High | New route with `timeout: 0s` (Phase 5) |
| VM location not in fulfillment-service | High | Low | Phase 0 prerequisite |
| WebSocket proxy complexity | Medium | Medium | Proven libraries, thorough testing |
| Service restarts drop sessions | Medium | Medium | Graceful drain + CLI auto-reconnect |
| KubeVirt single-session limit | Low | High | Detect and return clear error |
| Terminal compatibility | Low | Medium | Test on multiple emulators |

---

## Security

- **Auth:** Reuse existing OAuth/JWT flow
- **Authz:** Verify per-ComputeInstance access; enforce tenant isolation
- **Audit:** Log all connections (connect, disconnect, error) with user, tenant, resource
- **Session:** Configurable timeout (default 30 min); terminate on JWT expiry
- **Concurrency:** One session per VMI; clear error on second attempt
- **Escape:** `\r~.` handled client-side only — never sent to VM
- **Network:** TLS end-to-end (CLI ↔ Envoy ↔ service ↔ hub); KubeVirt endpoints not exposed to users

---

## Acceptance Criteria

**Functional:**
- [ ] `fulfillment-cli console computeinstance <id>` connects and displays VM output
- [ ] User can type commands and see responses
- [ ] Clean disconnect via `\r~.` or timeout
- [ ] Clear errors for: VM not running, wrong tenant, VMI already connected
- [ ] Auto-reconnect on transient failures; no reconnect on auth errors

**Non-functional:**
- [ ] Connection establishes within 5 seconds
- [ ] Input latency < 100ms
- [ ] No data loss during normal operation

**Security:**
- [ ] Cannot access other tenant's VM consoles
- [ ] All connections audited
- [ ] Session timeout enforced

**Architecture:**
- [ ] Backend interface used by KubeVirt backend
- [ ] Adding a new backend requires only a new `Backend` implementation

---

## Alternatives Considered

See `MGMT-22670-architecture-decision.md` for the full analysis. Summary:

| Option | Why not chosen |
|--------|---------------|
| **B. Token-based direct access** | Requires exposing KubeVirt API externally (security risk); KubeVirt-specific, no path to BM console |
| **C. virtctl integration** | Requires `virtctl` installed on user machines; KubeVirt-specific; loss of UX control |
| **D. Scoped credential handoff** | Users must have network access to hub API servers (not guaranteed); KubeVirt-specific, BM console (IPMI SOL) doesn't go through K8s API |
| **E. Dedicated console-proxy microservice** | Best long-term architecture but adds a new component to deploy and operate; not justified for v1 scope |

---

## Future Improvements

- **Bare metal console:** Add `IPMISOLBackend` and `console host` CLI command using the existing backend interface. Motivated by the [BM enhancement proposal](../enhancement-proposals/enhancements/bare-metal-fulfillment/README.md).
- **Console proxy extraction (Option E):** If console sessions become a bottleneck, extract `internal/console/` into a standalone microservice. The package is designed to be self-contained for this purpose.
- **VNC console:** Add graphical console via `CONSOLE_TYPE_VNC`. The proto already includes the enum and `ConsoleResize` message.
- **Session limits:** Per-user/per-tenant concurrent session caps if abuse becomes an issue.
- **Session recording:** Record console I/O for compliance auditing.

---

## Implementation Order

```
Phase 0: Resource Location Resolution ────────────────────┐
                                                           │
Phase 1: API Design (Proto) ──────────────────────────────┤
                                                           │
Phase 2: Backend Implementation ──────────────────────────┼──► Phase 4: Testing
                                                           │
Phase 3: CLI Implementation ──────────────────────────────┘
                                                           │
                                                           ▼
                                                     Phase 5: Docs & Rollout
```

Phase 0 must complete first. Phases 2 and 3 can run in parallel after Phase 1. Testing is continuous. The Envoy route update in Phase 5 is required before any staging/production deployment.
