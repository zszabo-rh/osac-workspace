# Review: osac#94 — OSAC-3053: implement fulfillment gRPC client stub

## PR Info
- URL: https://github.com/osac-project/osac/pull/94
- Jira: OSAC-3053 (parent: OSAC-2882 CSI Driver: Core Driver & Packaging)
- Author: rgolangh (Roy Golan)
- Created: 2026-08-02
- Base: main <- feat/OSAC-3053-fulfillment-grpc-client

## Round 1 — 2026-08-05

### Context
- Commits reviewed: d158b302 (single commit, squashed rewrite)
- Files changed: 7 (+215 -10)
- CI: all pass (CodeRabbit rate-limited, no blocking CI failures)
- Status: Akshay APPROVED; lgtm label cleared by last push; CHANGES_REQUESTED from prow safety

### Existing Review Comments Status
| Reviewer | Comment | Status |
|----------|---------|--------|
| akshaynadkarni | `buf.gen.yaml:28` — use local proto path instead of BSR? | Deferred to OSAC-1735 by Omer; Roy agreed |
| omer-vishlitzky | Points to OSAC-1735 discussion | Acknowledged |
| coderabbitai | `buf.gen.yaml:20` — go_package_prefix mismatch | Marked ✅ fixed in earlier commit |
| coderabbitai | `client_test.go:47` — srv.Serve error discarded | Roy marked "outdated" |
| **rgolangh** | **`client.go:54` — "not aligned with design, needs to be gone"** | **OPEN — not addressed** |

### Findings
| # | Severity | Category | File:Line | Finding | Status |
|---|----------|----------|-----------|---------|--------|
| 1 | Major | spec-match | client.go:54 | GRPCClient.Resolve delegates to stub — Roy's own design objection unaddressed | OPEN |
| 2 | Major | spec-match | OSAC-3053 | Jira AC says "Resolve RPC returns backend routing info" — PR intentionally doesn't satisfy this | OPEN |
| 3 | Minor | test-coverage | conn.go | No unit tests for new public package | OPEN |
| 4 | Minor | coding-patterns | Containerfile | Copies entire osac-operator/pkg/ instead of just pkg/fulfillment/ | OPEN |
| 5 | Minor | coding-patterns | conn.go:88 | Token file path exposed in error messages | OPEN |

### Recommendation
REQUEST CHANGES — Roy's outstanding self-comment on client.go:54 must be resolved.
