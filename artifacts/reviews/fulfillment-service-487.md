# Review: fulfillment-service#487 — MGMT-24034: Switch console backend to console.osac.openshift.io API

## PR Info
- URL: https://github.com/osac-project/fulfillment-service/pull/487
- Jira: MGMT-24034
- Author: sk-ilya (Ilya Skornyakov)
- Created: 2026-05-05
- Base: main <- console-proxy
- Dependency: must merge AFTER osac-operator#213

## Round 1 — 2026-05-05

### Context
- Commits reviewed: 1 commit
- Files changed: 12 (+135 -70)
- CI status: ALL PASSING

### Findings
| # | Severity | Category | File:Line | Finding | Status |
|---|----------|----------|-----------|---------|--------|
| 1 | Major | documentation | PR description | Minimal description doesn't explain full scope (API migration, keepalive, stream lifecycle, Envoy routes) | OPEN |
| 2 | Major | completeness | console_server.go:438 | No runtime check/clear error if console.osac.openshift.io API not deployed on hub | OPEN |
| 3 | Minor | conventions | .gitignore | .idea/.vscode should be in global gitignore, not project | OPEN |
| 4 | Minor | coding-pattern | config.go:236 | 10s keepalive hardcoded globally for all CLI connections, not just console | OPEN |
| 5 | Minor | coding-pattern | console_server.go:248 | isCleanShutdown pattern repeated 3x — extract helper | OPEN |
| 6 | Nitpick | naming | kubevirt_backend.go | File/type still named "kubevirt" but no longer connects to KubeVirt | OPEN |

### Recommendation
COMMENT ONLY
