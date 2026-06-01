# Review: osac-operator#216 — MGMT-23949: add DeletionTimestamp guard to management-state check

## PR Info
- URL: https://github.com/osac-project/osac-operator/pull/216
- Jira: MGMT-23949
- Author: zszabo-rh
- Created: 2026-05-04
- Base: main <- fix/MGMT-23949-management-state-deletion-guard
- Files changed: 10 (+311 -6)

## Round 1 — 2026-05-05

### Context
- Commits reviewed: 53c8f58..HEAD (2 commits)
- Files changed: 10 (+311 -6)
- CI status: ALL PASSING — initial push had 1 test failure, fixed in subsequent push (run 25358083309)

### Findings
| # | Severity | Category | File:Line | Finding | Status |
|---|----------|----------|-----------|---------|--------|
| 1 | ~~Critical~~ | ci-failure | computeinstance_controller_test.go:148-164 | Initial push had test timeout — fixed in subsequent push. All CI green now. | RESOLVED |
| 2 | ~~Major~~ | test-quality | PR description | CI now passes — test plan claim is accurate after fix push | RESOLVED |
| 3 | Major | test-quality | securitygroup_controller_test.go:669 | handleDelete error return ignored (_, _ =) | OPEN |
| 4 | Major | coding-pattern | securitygroup_controller_test.go:655-671 | Inconsistent test pattern — sets DeletionTimestamp manually instead of using k8sClient.Delete + Reconcile like other tests | OPEN |
| 5 | Minor | conventions | commit messages | Missing DCO Signed-off-by trailer | OPEN |
| 6 | Minor | completeness | Jira ticket | PublicIP controller status unclear — is it already fixed or not applicable? | OPEN |
| 7 | Nitpick | documentation | computeinstance_controller_test.go:169 | Tenant setup needed for CI test but not others — no comment explaining why | OPEN |

### Draft Comments
1. [computeinstance_controller_test.go:148-164] Revert Reconcile pattern — call once outside Eventually, then poll status
2. [PR description] Uncheck make test checkbox until CI passes
3. [securitygroup_controller_test.go:669] Assert handleDelete error instead of discarding
4. [securitygroup_controller_test.go:655-671] Align with k8sClient.Delete + Reconcile pattern used in other tests
5. [commit messages] Add DCO Signed-off-by trailer
6. [Jira ticket] Clarify PublicIP controller coverage
7. [computeinstance_controller_test.go:169] Add comment explaining tenant setup requirement

### Recommendation
COMMENT ONLY (CI fixed, remaining findings are quality improvements, not blockers)
