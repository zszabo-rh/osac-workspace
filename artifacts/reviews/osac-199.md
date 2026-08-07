# Review: osac#199 — OSAC-3234: CaaS local storage — LVMS on guest cluster workers

## PR Info
- URL: https://github.com/osac-project/osac/pull/199
- Jira: OSAC-3234 (parent: OSAC-917 Storage Framework)
- Author: zszabo-rh
- Created: 2026-08-07
- Base: main <- feat/OSAC-3234-caas-lvms

## Round 1 — 2026-08-07

### Context
- Commits reviewed: a8308fe0..9fd9bb7b (2 commits)
- Files changed: 4 (+154 -14)
- CI status: In progress (just opened)

### Findings
| # | Severity | Category | File:Line | Finding | Status |
|---|----------|----------|-----------|---------|--------|
| 1 | Major | correctness | ensure_storage_class.yaml:94-110 | `failed_when` does not short-circuit `until` retries — LVMCluster `Failed` state triggers 10min retry instead of immediate failure | OPEN |
| 2 | Minor | consistency | ensure_storage_class.yaml:28-38 | OperatorGroup missing `spec.targetNamespaces` — inconsistent with hub installer pattern | OPEN |
| 3 | Minor | consistency | ensure_storage_class.yaml:20 | `validate_certs` pattern differs from `_dispatch_provider.yaml` (`not X` vs `false if X else omit`) | OPEN |
| 4 | Minor | maintainability | defaults/main.yaml:17 | Hardcoded `stable-4.22` channel — no override mechanism from dispatcher | OPEN |
| 5 | Nitpick | jira | — | Prow bot warns no target version on OSAC-3234 | OPEN |

### Draft Comments

1. **ensure_storage_class.yaml:94-110** — `failed_when` + `until` interaction doesn't fail fast. Fix: add `Failed` to the `until` exit condition:
   ```yaml
   until:
     - _lvms_cluster_status.resources | length > 0
     - _lvms_cluster_status.resources[0].status.state | default('') in ['Ready', 'Failed']
   failed_when:
     - _lvms_cluster_status.resources | length > 0
     - _lvms_cluster_status.resources[0].status.state | default('') == 'Failed'
   ```

2. **ensure_storage_class.yaml:28-38** — Add `spec.targetNamespaces` to match hub installer:
   ```yaml
   spec:
     targetNamespaces:
       - "{{ lvms_storage_operator_namespace }}"
   ```

3. **ensure_storage_class.yaml:20** — Consider aligning `validate_certs` pattern with `_dispatch_provider.yaml` (`false if ... else omit`).

4. **defaults/main.yaml:17** — Channel is OCP-version-dependent. Consider dispatcher override or document how to customize.

5. **Jira** — Set target version on OSAC-3234.

### Recommendation
REQUEST CHANGES — fix #1 (one-line fix delivers the fast-fail behavior the PR promises)
