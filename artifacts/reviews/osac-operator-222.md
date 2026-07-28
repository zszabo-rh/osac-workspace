# Review: osac-operator#222 — MGMT-24300: fix duplicate AAP jobs from feedback controller race condition

## PR Info
- URL: https://github.com/osac-project/osac-operator/pull/222
- Jira: OSAC-2 (migrated from MGMT-24300)
- Author: danmanor
- Created: 2026-05-05
- Base: main <- fix-duplicates

## Round 1 — 2026-05-06

### Context
- Commits reviewed: bacd970f2cfd3e472f258a7b6fa1a918afb1a900
- Files changed: 8 (+227 -12)
- CI status: All passing (tests, lint, pre-commit, build, prow images). Tide pending (needs lgtm label).

### Findings
| # | Severity | Category | File:Line | Finding | Status |
|---|----------|----------|-----------|---------|--------|
| 1 | Major | correctness | all 4 controllers | `r.Get` (cached) used instead of `r.APIReader.Get` (direct API) in retry loop — PR description claims APIReader | OPEN |
| 2 | Minor | documentation | PR description | Description says "via APIReader.Get()" but code uses cached `r.Get()` — misleading | OPEN |
| 3 | Minor | observability | publicippool/securitygroup controllers | `log.Error(updateErr, "failed to update status")` removed without replacement in retry helper | OPEN |
| 4 | Nitpick | code-duplication | all 4 controllers | `updateStatusWithRetry` copy-pasted 4x with only type changed — could be generic, but follows existing computeinstance pattern | OPEN |

### Draft Comments

1. **[subnet_controller.go:137] (applies to all 4 controllers)**
   The PR description says "Fix by re-reading the resource from the API server via APIReader.Get()" but the retry helper uses `r.Get()` (the cached informer client). If the informer hasn't delivered the watch event yet, all retry attempts may observe the same stale `resourceVersion` and exhaust the retry budget.

   The existing `computeinstance_controller.go` has the same pattern, so this is consistent with the codebase — but for the stated fix goal, `r.APIReader.Get()` would be more correct. It guarantees a fresh read from the API server on every retry, eliminating the race window entirely.

   Since all 4 controllers already have `r.APIReader` populated (used in `CheckAPIServerForNonTerminalProvisionJob`), this is a one-line change per controller:
   ```diff
   -  if err := r.Get(ctx, key, latest); err != nil {
   +  if err := r.APIReader.Get(ctx, key, latest); err != nil {
   ```

   In practice `r.Get` works in most cases because the informer cache typically updates within a few milliseconds, well within the ~130ms retry window. But APIReader removes the theoretical gap entirely.

### Recommendation
COMMENT — the fix is a clear improvement over the no-retry approach and CI is green. The `r.Get` vs `r.APIReader.Get` issue is worth raising but not blocking, since it follows the established pattern in computeinstance_controller.go and works in practice.
