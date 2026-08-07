# Review: osac#198 — OSAC-3712: fix LVMS namespace resolution and tenant_name for hub storage

## PR Info
- URL: https://github.com/osac-project/osac/pull/198
- Jira: OSAC-3712
- Author: omer-vishlitzky
- Created: 2026-08-07
- Base: main <- fix/OSAC-3712-lvms-namespace-and-tenant-name
- Files changed: 9 (+33 -10)

## Round 1 — 2026-08-07

### Context
- Commits reviewed: 0fec1ac96f0447c0bdc128e3cfe721bd68e481d4..3f8ba6957b78c277a555e25aaf09d118c83c0aa8
- CI status: ansible-lint PASS; pre-commit, integration tests, CodeQL IN PROGRESS at review time
- CodeRabbit: CHANGES_REQUESTED (rate-limited before reviewing second commit, concern about annotation guard)
- Jira bot: warning about missing target version (5.0.0 not set on OSAC-3712)

### Findings
| # | Severity | Category | File:Line | Finding | Status |
|---|----------|----------|-----------|---------|--------|
| 1 | Nitpick | Documentation | commit 2 message | Commit message says "use errors='strict'" but code uses errors='ignore' — PR description correctly explains the intentional choice | OPEN |
| 2 | Nitpick | Documentation | vast_storage/defaults/main.yaml:19 | Comment still says "3. osac-system — last-resort fallback" but that line is now removed; comment not updated | OPEN |
| 3 | Non-issue | Spec | playbook_create:17-22 | CodeRabbit concern (CHANGES_REQUESTED): "require annotation before accessing it for ClusterOrder" — storage_controller.go guarantees annotation exists before triggering AAP; false alarm | RESOLVED by architecture |
| 4 | Non-issue | Logic | playbook_create/delete | Unknown kind produces empty tenant_name/tenant_namespace → storage_provider role validates both with explicit fail tasks (main.yaml:138-146); lvms_storage/setup.yaml:17-20 validates via DNS label regex — fail-fast path is clear | RESOLVED by downstream validation |

### Recommendation
APPROVE

### Draft Comments
None required — changes are correct.
