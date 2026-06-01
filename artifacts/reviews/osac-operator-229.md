# Review: osac-operator#229 — OSAC-687: Inject resolved storageClasses into AAP extra_vars

## PR Info
- URL: https://github.com/osac-project/osac-operator/pull/229
- Jira: OSAC-687 (parent: OSAC-104 — Add storage-tier support to tenant StorageClass discovery)
- Author: zszabo-rh
- Created: 2026-05-07
- Base: main <- feature/OSAC-687-inject-storage-classes-extra-vars

## Round 1 — 2026-05-07

### Context
- Commits reviewed: c7ed3ef
- Files changed: 3 (+62 -6)
- CI status: "Run Tests" FAILING (pre-existing on main — PublicIP test unrelated to this PR); lint pending; prow e2e pending

### Findings
| # | Severity | Category | File:Line | Finding | Status |
|---|----------|----------|-----------|---------|--------|
| 1 | Major | test-coverage | internal/provisioning/ | No unit test for the positive case — when storage classes ARE in context. Jira AC explicitly requires: "Unit tests verify the extra_vars contain the storageClasses list." Existing tests only cover backward compat (no context = no injection) by accident. | OPEN |
| 2 | Minor | ci-status | N/A | Jira ticket OSAC-687 has no target version set — Prow warns: "expected the sub-task to target the 5.0.0 version" | OPEN |

### Draft Comments

1. **internal/provisioning/aap_provider.go:455** (Major — test-coverage)
   The positive path (context carries storage classes → extra_vars contains `tenant_storage_classes`) has no unit test. The Jira AC explicitly calls this out: "Unit tests verify the extra_vars contain the storageClasses list." The existing tests pass `context.Background()` which covers the nil/backward-compat case, but a test like this is missing:

   ```go
   It("should include tenant_storage_classes in extra_vars when context carries them", func() {
       ctx := provisioning.WithTenantStorageClasses(context.Background(), []v1alpha1.ResolvedStorageClass{
           {Name: "ceph-fast", Tier: "fast"},
           {Name: "ceph-default", Tier: "default"},
       })
       // trigger provision with ctx, then assert:
       // req.ExtraVars["ansible_eda"]["event"]["tenant_storage_classes"] == expected
   })
   ```

### Recommendation
REQUEST CHANGES — missing test for the core feature path (finding #1)

## Round 2 — 2026-05-07

### Context
- Commits reviewed: c7ed3ef..09eb4d3
- New commit: `09eb4d3` — "OSAC-687: Add unit tests for tenant storage classes extra_vars injection"
- Files changed: 4 (+118 -6)
- CI status: pre-commit PASS, lint PASS, generated code PASS; "Run Tests" PENDING; prow e2e PENDING

### Changes Since Round 1
- New file: `internal/provisioning/aap_provider_test.go` (+56 lines) — two test cases added:
  1. Positive: context with storage classes → `tenant_storage_classes` injected into extra_vars
  2. Negative: bare context → no `tenant_storage_classes` key in extra_vars

### Findings
| # | Severity | Category | File:Line | Finding | Status |
|---|----------|----------|-----------|---------|--------|
| 1 | Major | test-coverage | internal/provisioning/ | Missing unit tests for storage class injection | RESOLVED (commit 09eb4d3) |
| 2 | Minor | ci-status | N/A | Jira OSAC-687 still has no target version — Prow will warn | STILL OPEN |

### Draft Comments
None — no new issues found.

### Recommendation
APPROVE (pending CI) — Round 1 major finding resolved. The remaining minor (Jira version) can be fixed independently.
