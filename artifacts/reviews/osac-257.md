# Review: osac#257 — OSAC-3632: per-disk StorageClass resolution in AAP

## PR Info
- URL: https://github.com/osac-project/osac/pull/257
- Jira: OSAC-3632 (parent epic OSAC-1710)
- Author: clobrano
- Created: 2026-08-11
- Base: main <- feat/OSAC-3632-aap-per-disk-storage-tier

## Round 1 — 2026-08-12

### Context
- Head SHA: e25a6fad9bbe69a5ab7164abdc6db70776ed5d7b
- Files changed: 29 (+494 -144)
- CI status: pre-commit FAIL (end-of-file-fixer), check-labels FAIL, E2E pending, compile/unit PASS

### Findings
| # | Severity | Category | File:Line | Finding | Status |
|---|----------|----------|-----------|---------|--------|
| 1 | Critical | correctness | create_resources.yaml:8 | `compute_instance.spec.bootDisk.storageTier` accessed without `default(...)` — UndefinedError on all existing CIs (optional field, omitempty) | OPEN |
| 2 | Critical | correctness | resolve_additional_disk.yaml:6 | `item.storageTier` without `default(...)` — same issue for additional disks | OPEN |
| 3 | Major | correctness | playbook_osac_create_compute_instance.yml:52 | `map(attribute='storageTier')` on additionalDisks without `default` parameter — Ansible error on missing key | OPEN |
| 4 | Major | test-coverage | test-windows-golden-image.yml:53 | Uses removed `tenant_storage_class_name` + no `storageTier` on bootDisk — broken by this PR, not fixed | OPEN |
| 5 | Major | ci | pre-commit | end-of-file-fixer modified files — trailing newline | OPEN |
| 6 | Major | documentation | PR description | STORAGE_REQUESTED_TIER removed with no migration guide for existing deployments | OPEN |
| 7 | Minor | documentation | README:70 | ocp_virt_vm spec field table missing storageTier | OPEN |
| 8 | Minor | conflict-risk | computeinstance-test.yaml | Overlap with PR #199 on same lines — merge conflict risk | OPEN |
| 9 | Nitpick | naming | create_resources.yaml:7 | boot_disk_storage_class / additional_disk_storage_classes lack vm_ prefix | OPEN |
| 10 | Nitpick | comment | setup_test_env.sh:26 | step 3.5 orphaned comment after collapse | OPEN |

### Recommendation
REQUEST CHANGES
