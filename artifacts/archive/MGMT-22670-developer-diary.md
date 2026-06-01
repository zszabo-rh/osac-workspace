# MGMT-22670 Developer Diary: Serial Console Access

## 2026-02-26 - Session Start

### Initial Assessment
- Read the full plan: `MGMT-22670-serial-console-plan.md`
- Explored the codebase structure thoroughly
- Key findings from exploration:
  - Private ComputeInstance proto (`fulfillment-service/proto/private/v1/compute_instance_type.proto`) has `hub` in status (field 4) but NO VM reference fields
  - Operator's `VirtualMachineReferenceType` exists in `osac-operator/api/v1alpha1/computeinstance_types.go` with `Namespace` and `KubeVirtVirtualMachineName`
  - Feedback controller (`computeinstance_feedback_controller.go`) syncs conditions, phase, IP address, restarts - but NOT VM reference
  - Envoy config has timeout exemption for `^.*/Watch$` pattern; console needs similar
  - Server pattern: Builder → public server (wraps private) → generic server → DAO
  - CLI pattern: Cobra commands with `runnerContext`, gRPC connection from config
  - Proto organization: `*_type.proto` for types, `*_service.proto` for RPCs

### Implementation Order
Phase 0 → Phase 1 → Phase 2 → Phase 3 → Phase 5 (Envoy) → Phase 4 (Testing throughout)

---

## Phase 0: Resource Location Resolution

### Status: COMPLETE

### Approach
1. Add `ComputeInstanceVMReference` message to private proto
2. Add `vm_reference` field to `ComputeInstanceStatus`
3. Regenerate Go code
4. Update operator feedback controller to send VM reference
5. Verify flow

### Progress Log

#### Step 1: Proto modification
- Added `ComputeInstanceVMReference` message (hub_id, namespace, vm_name) to `fulfillment-service/proto/private/v1/compute_instance_type.proto`
- Added `optional ComputeInstanceVMReference vm_reference = 6` to `ComputeInstanceStatus`
- Ran `buf generate` in fulfillment-service -- generated code has all methods (Get/Set/Has/Clear/Builder)
- **Build: PASS** (`go build ./...`)
- **Tests: 68/69 PASS** (1 pre-existing failure: missing `helm` binary for auth_rules_test)

#### Step 2: Operator proto regeneration
- Temporarily overrode operator's `buf.gen.yaml` to reference local proto (instead of BSR v0.0.40)
- Ran `buf generate` in osac-operator -- generated code has VmReference types
- Restored `buf.gen.yaml` to original (BSR reference)
- **Note:** In production, the private proto must be published to BSR first, then operator updated

#### Step 3: Feedback controller update
- Added `syncVMReference()` to `syncState()` call chain in `computeinstance_feedback_controller.go`
- Implementation: reads `status.virtualMachineReference` from CR, builds `ComputeInstanceVMReference` with hub_id from existing `status.hub`
- Only writes if reference changed or not yet set (avoids unnecessary updates)
- **Build: PASS** (`go build ./...`)
- **Tests: ALL PASS** (`make test` - all suites green)

### Decisions
- Used `ci.GetStatus().GetHub()` as the `hub_id` source since it's already set by the fulfillment-service during scheduling
- Added early return if VM reference already matches (avoid spurious updates)

---

## Phase 1: API Design & Protocol Buffers

### Status: COMPLETE

### Progress Log

#### Proto creation
- Created `fulfillment-api/proto/fulfillment/v1/console_service.proto`
- Contains: Console service with `Connect` (bidi stream) and `GetAccess` (unary) RPCs
- Enums: `ConsoleResourceType`, `ConsoleType`, `ConsoleConnectionState`
- Messages: `ConsoleConnectRequest` (oneof: init/input/resize), `ConsoleConnectResponse` (oneof: output/status)
- Buf lint fix: renamed `GetConsoleAccessRequest` → `ConsoleGetAccessRequest` (naming convention)
- **Lint: PASS**

#### Code generation
- Generated Go code in fulfillment-service (`internal/api/fulfillment/v1/console_service*.go`)
- Generated Go code in fulfillment-common (`api/fulfillment/v1/console_service*.go`)
- Both required temporarily overriding buf.gen.yaml to reference local proto dirs (instead of BSR)
- **Build: PASS** (both fulfillment-service and fulfillment-common)
- **Tests: 68/69 PASS** (same pre-existing failure)

### Decisions
- Console service placed in public API (`fulfillment-api`) since CLI calls it directly
- HTTP annotation only on `GetAccess` (unary) — `Connect` (bidi stream) is gRPC-only
- REST path: `/api/fulfillment/v1/console/{resource_type}/{resource_id}/access`

### Workarounds
- For development: temporarily override buf.gen.yaml inputs to local directories instead of BSR modules
- Must publish proto updates to BSR before merging to main

---

## Phase 2: Fulfillment Service Implementation

### Status: COMPLETE

### Progress Log

#### Package structure
- Created `internal/console/` package:
  - `backend.go` - `Backend` interface + `Target` struct + `ErrSessionExists` typed error
  - `kubevirt_backend.go` - KubeVirt WebSocket backend using `golang.org/x/net/websocket`
  - `manager.go` - Session manager with timeout, concurrent session rejection, drain support
- Created `internal/servers/console_server.go` - gRPC handler for `Console.Connect` and `Console.GetAccess`

#### Backend design
- `Backend` interface: single `Connect(ctx, Target) (io.ReadWriteCloser, error)` method
- `KubeVirtBackend`: connects via WebSocket to `/apis/subresources.kubevirt.io/v1/namespaces/{ns}/virtualmachineinstances/{name}/console`
- `HubConfigProvider` function type abstracts how hub REST configs are obtained
- `HubConfigProviderFromKubeconfigs` helper builds REST configs from raw kubeconfig bytes

#### Dead end: SPDY approach
- Initially tried `k8s.io/client-go/tools/remotecommand` SPDY executor — wrong protocol for KubeVirt console
- KubeVirt console subresource uses WebSocket, not SPDY/exec
- Switched to `golang.org/x/net/websocket` (already a dependency)

#### Dead end: gorilla/websocket dep
- Tried `go get github.com/gorilla/websocket` — broke go.mod due to module path rename issues (innabox → osac-project)
- Reverted go.mod/go.sum and used `golang.org/x/net/websocket` instead

#### Server wiring
- Console server wired into `start_grpc_server_cmd.go`
- Uses `privateHubsServer.Get()` directly for hub kubeconfig (in-process call, no gRPC hop)
- Uses `privateComputeInstancesServer` for resource resolution
- Resolves ComputeInstance → verifies RUNNING state → extracts vm_reference → passes to backend

#### Session management
- One session per resource (concurrent session rejection with informative error)
- Configurable timeout via `OSAC_CONSOLE_SESSION_TIMEOUT` env var (default 30m)
- `managedConnection` wrapper auto-removes session on close
- `DrainSessions()` for graceful shutdown
- `ActiveSessions()` for metrics
- Server proxy actively closes backend connection on context expiry (timeout enforcement)

### Bugs Found During E2E Testing
- **"failed to get transaction from context"** — The console server calls `ciServer.Get()` and `hubsServer.Get()` in-process, but the `TxInterceptor` only injects transactions for unary RPCs. Streaming RPCs (like `Console.Connect`) don't get a transaction in the context. Fix: inject `TxManager` into console server, create transactions manually around each private server call.
- **Session timeout not enforced** — `context.WithTimeout` in the Manager fires after 30m but the WebSocket connection (`golang.org/x/net/websocket`) does not monitor context cancellation. Session becomes unresponsive but stays in session map, blocking reconnects. Fix: proxy goroutine monitors `ctx.Done()` and actively closes the backend connection.
- **hub-access RBAC insufficient for console** — The default hub-access Role only covers OSAC CRDs. KubeVirt console subresource (`virtualmachineinstances/console`) requires cluster-admin. Fix: `oc create clusterrolebinding hub-access-admin-<ns> --clusterrole=cluster-admin --serviceaccount=<ns>:hub-access`.

### Decisions
- Used in-process server calls instead of gRPC client for resource resolution (simpler, no auth overhead)
- Bidirectional proxy uses two goroutines (backend→client, client→backend) with error channel
- Session key is `{resource_type}/{resource_id}` for uniqueness
- Concurrent session error returns `codes.FailedPrecondition` (classified as permanent, no retry)

---

## Phase 3: CLI Implementation

### Status: COMPLETE

### Progress Log

#### Command structure
- Created `fulfillment-cli/internal/cmd/console/console_cmd.go` - parent command
- Created `fulfillment-cli/internal/cmd/console/computeinstance/console_computeinstance_cmd.go` - main implementation
- Registered in `root_cmd.go`

#### Terminal handling
- Uses `golang.org/x/term` (already in go.mod) for raw mode
- `term.MakeRaw(fd)` with `defer term.Restore(fd, oldState)` for cleanup
- Gracefully handles non-terminal stdin (skips raw mode)

#### Escape sequences
- SSH-style `\r~.` (CR + tilde + period) for disconnect
- Ctrl+] (0x1D, telnet style) — works at any time without preceding Enter
- Implemented as `escapeDetector` state machine
- Client-side only — never sent to VM

#### Auto-reconnect
- Exponential backoff: 1s → 2s → 4s → 8s → 16s, capped at 30s
- Max 5 consecutive failures (counter resets after successful connection)
- Permanent errors (PermissionDenied, NotFound, Unauthenticated, FailedPrecondition, InvalidArgument, Unimplemented) exit immediately
- Transient errors (Unavailable, Internal) trigger retry
- Clean user-facing error messages (gRPC noise stripped)

#### Name resolution
- Accepts compute instance name or UUID
- Resolves via `ComputeInstances/List` with filter `this.id == "key" || this.metadata.name == "key"`
- Rejects ambiguous names (multiple matches) with suggestion to use ID

#### Client-side timeout
- `--timeout` flag (default 30m) enforced via `context.WithTimeout`
- Clean "Session timed out after ..." message on expiry
- No reconnect attempts after timeout

#### Credential documentation
- CLI help text explains cloud-init password setup for serial console login
- Documents the `cloud_init_config` template parameter

#### Misc fixes
- Fixed typo "maching" → "matching" in get command output

#### Workaround
- Added `replace` directive in go.mod to reference local fulfillment-common (for console proto types)
- Must be removed before merging; requires publishing updated fulfillment-common first

---

## Phase 5: Envoy Route Update

### Status: COMPLETE

### Progress Log
- Added console route to `fulfillment-service/manifests/base/ingress-proxy/configmap.yaml`
- Route matches `^/fulfillment\.v1\.Console/Connect$`
- Placed before the default `grpc-server` catch-all
- `timeout: 0s` and `idle_timeout: 0s` (same pattern as Watch/events route)
- **Critical:** Without this route, Envoy's default 300s timeout kills console sessions every 5 minutes exactly. Confirmed and fixed during E2E testing.

---

## Phase 4: Testing

### Unit Test Summary

| File | Tests | What's Covered |
|------|-------|---------------|
| `fulfillment-service/internal/console/manager_test.go` | 10 | Manager build, connect, concurrent rejection, multi-resource, double close, drain, 2 timeout tests |
| `fulfillment-service/internal/console/kubevirt_backend_test.go` | 8 | Backend build validation, connect errors, HubConfigProvider (getter error, invalid kubeconfig, valid kubeconfig) |
| `fulfillment-service/internal/console/kubevirt_backend_integration_test.go` | 4 | Backend → mock WS: connect+exchange data, Manager→backend data flow, concurrent session rejection, server-side close |
| `fulfillment-service/internal/console/mock_ws_server_test.go` | (infra) | Mock KubeVirt WebSocket server (echo mode, banner, custom handler) |
| `fulfillment-service/internal/servers/console_server_test.go` | 14 | Build validation (4), GetAccess (5), Connect handler (5: reject non-init, reject not running, reject unsupported, bidirectional relay, backend failure) |
| `fulfillment-cli/internal/cmd/console/computeinstance/escape_test.go` | 11 | Escape detector: CR/LF+~+., Ctrl+], single chunk, no CR, failed sequence, reset, multi-CR, normal text, embedded |
| `fulfillment-cli/internal/cmd/console/computeinstance/stream_test.go` | 9 | isPermanentError classification for all gRPC codes |
| `fulfillment-cli/internal/cmd/console/computeinstance/reconnect_test.go` | 4 | In-process gRPC server: transient retry, permanent error, full connectWithRetry, stream EOF |
| `osac-operator/internal/controller/computeinstance_feedback_controller_test.go` | 2 | syncVMReference (new fields synced, preserved when matching) |

**Total new tests: 62** (+ E2E playbook)

### E2E Test Results (hypershift1, 2026-03-02)

| Test | Result | Notes |
|------|--------|-------|
| CLI connects and displays VM output | **PASSED** | Fedora cloud image, serial getty |
| User can type commands and see responses | **PASSED** | `ls -l` executed, output displayed |
| Disconnect via Ctrl+] | **PASSED** | Immediate, works during any state |
| Disconnect via Enter ~. | **PASSED** | SSH-style, works at shell prompt |
| VM not running error | **PASSED** | "not running (state: COMPUTE_INSTANCE_STATE_STARTING)" |
| Concurrent session rejection | **PASSED** | Immediate error, no retry, shows active user |
| Auto-reconnect on transient failure | **PASSED** | Counter resets after successful reconnect |
| No reconnect on permanent errors | **PASSED** | FailedPrecondition exits immediately |
| Envoy timeout (5 min) no longer kills sessions | **PASSED** | Session stable beyond 6 minutes |
| Client-side timeout enforcement | **PASSED** | Clean "Session timed out" message |
| Server-side timeout enforcement | **PASSED** | Backend connection closed, session freed |
| Name-based lookup | **PASSED** | `console computeinstance console-demo` works |
| Ambiguous name rejection | **PASSED** | "multiple compute instances match; use the ID instead" |
| Clean error messages | **PASSED** | gRPC noise stripped from user-facing errors |
| Wrong tenant isolation | **SKIPPED** | Needs multi-tenant Keycloak setup |
| Load testing | **SKIPPED** | Needs infrastructure |

### E2E Test Scaffolding (osac-test-infra)

| File | Purpose |
|------|---------|
| `roles/test_compute_instance_console/tasks/main.yml` | Console access check (GetAccess), connection test, stdin echo test |
| `roles/test_compute_instance_console/tasks/test_not_running.yml` | Negative test: console denied for non-running instance |
| `playbooks/test_compute_instance_console.yml` | Orchestration playbook with optional CI creation and cleanup |

---

## Files Modified/Created

### fulfillment-api (public API)
- **NEW:** `proto/fulfillment/v1/console_service.proto`

### fulfillment-service
- **MODIFIED:** `proto/private/v1/compute_instance_type.proto` (added VM reference)
- **REGENERATED:** `internal/api/` (proto codegen)
- **NEW:** `internal/console/backend.go`, `kubevirt_backend.go`, `manager.go`
- **NEW:** `internal/console/console_suite_test.go`, `manager_test.go`, `kubevirt_backend_test.go`, `kubevirt_backend_integration_test.go`, `mock_ws_server_test.go`
- **NEW:** `internal/servers/console_server.go`, `console_server_test.go`
- **MODIFIED:** `internal/cmd/start_grpc_server_cmd.go` (console server wiring + tx management)
- **MODIFIED:** `manifests/base/ingress-proxy/configmap.yaml` (Envoy route)

### fulfillment-common
- **REGENERATED:** `api/` (proto codegen for console service + VM reference)

### osac-operator
- **REGENERATED:** `internal/api/private/v1/compute_instance_type*.pb.go`
- **MODIFIED:** `internal/controller/computeinstance_feedback_controller.go` (syncVMReference)
- **MODIFIED:** `internal/controller/computeinstance_feedback_controller_test.go` (+2 tests)

### fulfillment-cli
- **NEW:** `internal/cmd/console/console_cmd.go`
- **NEW:** `internal/cmd/console/computeinstance/console_computeinstance_cmd.go`
- **NEW:** `internal/cmd/console/computeinstance/escape_test.go`, `stream_test.go`, `reconnect_test.go`
- **MODIFIED:** `internal/cmd/root_cmd.go` (console command registration)
- **MODIFIED:** `internal/cmd/get/templates/no_matching_objects.txt` (typo fix)
- **MODIFIED:** `go.mod` (replace directive for dev)

### osac-test-infra
- **NEW:** `playbooks/test_compute_instance_console.yml`
- **NEW:** `roles/test_compute_instance_console/tasks/main.yml`
- **NEW:** `roles/test_compute_instance_console/tasks/test_not_running.yml`

---

## Future Improvements

### From project plan (not yet implemented)
- **Bare metal console:** Add `IPMISOLBackend` and `console host` CLI command
- **Console proxy extraction (Option E):** Extract `internal/console/` into standalone microservice if sessions become bottleneck
- **VNC console:** Add graphical console via `CONSOLE_TYPE_VNC`
- **Session limits:** Per-user/per-tenant concurrent session caps
- **Session recording:** Record console I/O for compliance auditing

### From E2E testing feedback
- **Timeout coordination:** Server should communicate its max timeout to client (e.g., in ConsoleStatus or GetAccessResponse). Client should validate `--timeout` against server limit and inform user. Consider raising server default to 1h and lowering client default to 5m.
- **Idle timeout vs hard timeout:** Current timeout is a hard deadline regardless of activity. Consider adding an idle timeout that resets on user input, so active sessions aren't killed.
- **Console credential UX:** Cloud images require password setup via cloud-init. Consider adding a `--set-password` flag to `create computeinstance` as a convenience wrapper, or prompting users when console login fails.
- **Empty prompt on first connect:** Serial console shows whatever the VM is currently outputting. If the login prompt has already scrolled, user sees nothing. Could auto-send `\r` on connect, but risks interfering with running commands.
- **hub-access RBAC:** The default hub-access Role should include KubeVirt subresource permissions for console access. Currently requires manual ClusterRoleBinding to cluster-admin.

### Infrastructure / testing
- **Cross-tenant isolation test:** Needs multi-tenant Keycloak setup on hypershift1
- **Load testing:** 50 concurrent sessions — measure memory, CPU, connection latency
- **Compatibility testing:** GNOME Terminal, tmux/screen, macOS Terminal.app, iTerm2

---

## Outstanding Items for Production
1. Publish updated fulfillment-api to BSR (`buf.build/innabox/fulfillment-api`)
2. Publish updated private-api to BSR (`buf.build/innabox/private-api`)
3. Update version references in all `buf.gen.yaml` files
4. Regenerate all repos from BSR (clean, not local overrides)
5. Remove `replace` directive from fulfillment-cli `go.mod`
6. Create PRs for all 6 repos
7. CI passes on all PRs

---

## Deployment Notes (hypershift1)
- Personal OSAC stack deployed in `osac-zszabo` namespace
- Custom images: `quay.io/rh-ee-zszabo/fulfillment-service:console`, `quay.io/rh-ee-zszabo/osac-operator:console`
- Envoy configmap patched manually (console route not in installer base yet)
- hub-access ClusterRoleBinding created manually for KubeVirt access
- Test VMs cleaned up after testing
- Stack left running for future use
