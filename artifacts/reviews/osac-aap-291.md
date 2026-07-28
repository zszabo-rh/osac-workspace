# Review: osac-aap#291 — OSAC-175, OSAC-176: Tier-aware StorageClass role and template-driven selection

## PR Info
- URL: https://github.com/osac-project/osac-aap/pull/291
- Jira: OSAC-175, OSAC-176
- Author: zszabo-rh
- Created: 2026-05-07
- Base: main <- feature/OSAC-175-tier-aware-storage-class-role

## Round 1 — 2026-05-07

### Context
- Commits reviewed: fe6e88fd5b6bff085158425460d5660c0f5d46b5
- Files changed: 5 (+99 -148)
- CI status: ansible-lint pass, integration-tests pass, pre-commit pass; build-execution-environment/CodeRabbit/ci-prow-images/tide pending

### Findings
| # | Severity | Category | File:Line | Finding | Status |
|---|----------|----------|-----------|---------|--------|
| 1 | Minor | completeness | playbook_osac_create_compute_instance.yml:30-32 | `is not defined` check unreachable due to `default([])` in vars | OPEN |
| 2 | Minor | test-coverage | tests/test.yml | No test for multiple entries with same tier (first-match semantics) | OPEN |
| 3 | Minor | process | Jira | OSAC-175/176 missing target version "5.0.0" | OPEN |
| 4 | Nitpick | coding-patterns | tasks/main.yaml:17 | `_tenant_sc_available_tiers` could use `| unique` to deduplicate | OPEN |

### Draft Comments

1. **playbook_osac_create_compute_instance.yml:30-32** — Nit: `tenant_storage_classes is not defined` is unreachable here because the `vars:` block on line 11 always defines it via `| default([])`. The `| length == 0` check already covers the case where the operator didn't inject the field. Consider simplifying to just `tenant_storage_classes | length == 0`, or adding a comment explaining this is a defense-in-depth guard.

2. **tests/test.yml** — Consider adding a test case for multiple entries with the same tier (e.g., two "default" entries) to document the first-match behavior of `_tenant_sc_match[0]`. Not urgent — the Tenant controller prevents duplicates — but it would make the contract explicit.

3. **tasks/main.yaml:17** — Minor: `| unique` after `| sort` would prevent duplicate tier names in the error message, though the Tenant controller should prevent duplicates upstream.

### Recommendation
APPROVE — 0 critical, 0 major, 3 minor, 1 nitpick. Clean architectural change replacing runtime K8s API call with pre-resolved data injection. Contract with companion PR (osac-operator#229) verified. Tests self-contained.
