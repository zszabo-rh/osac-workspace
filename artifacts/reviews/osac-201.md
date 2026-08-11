# Review: osac#201 — OSAC-2872: Volume private API, DB migration, CRD types

## PR Info
- URL: https://github.com/osac-project/osac/pull/201
- Jira: OSAC-2872 (Storage Control Plane)
- Author: akshaynadkarni
- Created: 2026-08-07
- Base: main <- feat/OSAC-2872-volume-api-crd

## Round 1 — 2026-08-08

### Context
- Commits reviewed: 5f09d2e..461d0b5 (3 commits)
- Files changed: 25 (+7355 -353)
- CI status: Unit/integration/lint/build pass. E2E (BMaaS/CaaS/VMaaS) fail (pre-existing infra, not PR-related). Tide pending lgtm.
- Other reviewers: CodeRabbit (CHANGES_REQUESTED, 2 rounds)

### Findings
| # | Severity | Category | File:Line | Finding | Status |
|---|----------|----------|-----------|---------|--------|
| 1 | Major | validation | private_volumes_server.go:113-128 | No validation of required spec fields (storage_tier, size_gib, access_mode) in Create handler. All other comparable servers (StorageBackends, StorageTiers, Secrets) have validate*Create() methods. | OPEN |
| 2 | Minor | crd-validation | volume_types.go:56 | PVCRef immutability rule lacks optionalOldSelf=true — optional field can be added on update even though intent is immutable-once-set | OPEN |
| 3 | Minor | crd-validation | volume_types.go:47 | AccessMode is free-form string without Enum constraint on CRD — any arbitrary string passes admission | OPEN |
| 4 | Minor | test-coverage | 94_create_volumes_tables_test.go:29-57 | archived_volumes table not tested (only volumes table has insert test) | OPEN |
| 5 | Nitpick | jira | PR-level | Jira OSAC-2872 has no target version set (CI bot expects 5.0.0) | OPEN |

### Draft Comments
1. [private_volumes_server.go:113] Other private servers (StorageBackends, StorageTiers, Secrets) all validate required spec fields in Create via a validate*Create() method. This server is missing that validation. A volume could be created with empty storage_tier, size_gib=0, or missing access_mode. Even though the controller layer will eventually enforce these, the API should reject invalid requests early.
2. [volume_types.go:56] Without optionalOldSelf=true, the immutability rule for this optional field is skipped when the old value is absent — PVCRef can be added on update. If the design is "set at creation or never," needs optionalOldSelf: true.
3. [volume_types.go:47] Consider adding Enum validation for known K8s access modes (ReadWriteOnce, ReadOnlyMany, ReadWriteMany, ReadWriteOncePod).
4. [94_create_volumes_tables_test.go:29] Add Entry("archived_volumes", "archived_volumes") to verify the archived table.

### Recommendation
REQUEST CHANGES (major: missing Create validation)

---

## Round 2 — 2026-08-11

### Context
- Commits reviewed: 461d0b5..f070c474 (5 new commits)
- CI status: All checks pass (100% green — CodeRabbit pass, all unit/integration/lint/build)
- Other reviewers: CodeRabbit (all Major findings resolved or accepted by author)

### Findings
| # | Severity | Category | File:Line | Finding | Status |
|---|----------|----------|-----------|---------|--------|
| 1 | Major | validation | private_volumes_server.go:117-155 | validateVolumeCreate added | RESOLVED |
| 2 | Minor | crd-validation | volume_types.go:49 | PVCRef optionalOldSelf — behavior is correct without it: field-level rule prevents post-creation add/change; spec-level rule prevents removal; CREATE skips transition rules so pvcRef settable at creation. "Set at creation or never" semantics ✅ | RESOLVED |
| 3 | Minor | crd-validation | volume_types.go:42-44 | AccessMode now VolumeAccessMode enum with 4 valid values + buf.validate defined_only | RESOLVED |
| 4 | Minor | test-coverage | 94_create_volumes_tables_test.go:51 | archived_volumes table still not tested — only Entry("volumes","volumes") exists | STILL OPEN |
| 5 | Nitpick | jira | PR-level | Jira target version | not checked |
| 6 | Minor | protocol-type | volume_type.proto | StorageProtocol enum now used (shared storage_common_type.proto) | RESOLVED |

### CodeRabbit open items (accepted by author)
- SizeGiB max bound — valid skip, backend limits belong in quota/controller layer
- Spec immutability at API layer — deferred to controller PR (#223), correct for passthrough GenericServer

### Draft Comments
1. [94_create_volumes_tables_test.go:51] The DescribeTable block only verifies the `volumes` table. `archived_volumes` is created by the same migration but has no test entry. Add `Entry("archived_volumes", "archived_volumes")` — same one-liner as the volumes entry.

### Recommendation
APPROVE with comment on finding #4 (one-liner fix, can go here or in #223)
