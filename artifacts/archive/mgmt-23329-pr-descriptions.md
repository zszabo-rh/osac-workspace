# MGMT-23329: PR Descriptions and Jira Bug

## PR 1: osac-operator

**Repo:** osac-project/osac-operator
**Branch:** zszabo-rh/osac-operator @ feature/mgmt-23329-restart-vm-ansible
**Title:** MGMT-23329: Move VM restart logic to Ansible

### Description

## Summary

Move the VM restart mechanism from the Go operator to the Ansible create
template. Instead of the operator directly deleting the VMI, restart is now
handled as part of the normal provisioning flow.

### Changes

**Removed:**
- `computeinstance_restart.go` — direct VMI deletion logic (219 lines)
- `computeinstance_restart_test.go` — associated tests (445 lines)
- `handleRestartRequest()` call from the reconciler

**Added:**
- `lastRestartedAt` update in the reconcile steady-state path: when config
  versions match and `restartRequestedAt > lastRestartedAt`, the operator
  sets `status.lastRestartedAt`
- EDA provider fix: when config versions match (proving Ansible completed),
  non-terminal provision jobs are marked Succeeded. This fixes a pre-existing
  bug where EDA jobs stuck in `Unknown` state blocked all subsequent
  spec-change-driven provisioning.
- 5 unit tests for the `lastRestartedAt` update logic

### How restart works now

1. User sets `spec.restartRequestedAt` (via API or direct CR patch)
2. Spec hash changes → `desiredConfigVersion != reconciledConfigVersion`
3. Operator triggers provision (EDA webhook or AAP job)
4. Ansible `create.yaml` detects `restartRequestedAt > lastRestartedAt`,
   deletes the VMI. KubeVirt recreates it (runStrategy stays Always).
5. Ansible sets `reconciledConfigVersion` annotation
6. Operator sees config versions match → sets `status.lastRestartedAt`

### EDA fix detail

Previously, when config versions matched but the EDA provision job was in
`Unknown` state (EDA can't poll job status), the operator entered an infinite
polling loop instead of proceeding. Now, matching config versions are treated
as proof that the provision completed, regardless of provider-reported state.

## Test plan

- [x] Unit tests pass (`make build`)
- [x] E2E verified with AAP Direct provider on hypershift1
- [x] E2E verified with EDA provider on hypershift1
- [x] Ansible lint passes (production profile)

---

## PR 2: osac-templates

**Repo:** osac-project/osac-templates
**Branch:** zszabo-rh/osac-templates @ feature/mgmt-23329-restart-vm-ansible
**Title:** MGMT-23329: Add restart logic to VM create template

### Description

## Summary

Add restart detection and VMI deletion to the `ocp_virt_vm` create template
so that VM restart is handled as part of the normal provisioning flow.

### Changes

Added to `roles/ocp_virt_vm/tasks/create.yaml` (after VM creation, before
waiting for Ready):

1. **Check if restart is requested** — evaluates
   `restartRequestedAt > lastRestartedAt` (or `lastRestartedAt` not set)
2. **Delete VirtualMachineInstance** — triggers KubeVirt to recreate the VMI.
   Only runs when restart is detected.

### Design decisions

- **VMI deletion** (not runStrategy toggle): safer — if the Ansible job fails
  mid-restart, KubeVirt auto-recreates the VMI since runStrategy stays Always.
  A runStrategy toggle could leave the VM stopped if the job crashes.
- **Inside create.yaml** (not a separate restart template): Adrien's
  architectural decision — the provision flow reconciles the full desired
  state, including restart. This also means EDA support works automatically.

## Test plan

- [x] Ansible lint passes (production profile)
- [x] E2E verified on hypershift1 — VMI deletion confirmed in AAP job output

---

## Jira Bug: Fulfillment API update mask clears unmasked spec fields

**Project:** MGMT
**Component:** OSAC
**Type:** Bug
**Assignee:** zszabo@redhat.com
**Summary:** Fulfillment API update mask clears unmasked explicit spec fields

### Description

**Problem:**
When updating a ComputeInstance via the fulfillment API with an update_mask
targeting a single field (e.g., `spec.restart_requested_at`), all other
explicit spec fields (`cores`, `memory_gib`, `boot_disk`, `image`,
`run_strategy`) are cleared from the database.

**Reproducibility:** 100%

**Steps to reproduce:**
1. Create a ComputeInstance with all explicit spec fields
2. Update only `restart_requested_at` using update_mask: `["spec.restart_requested_at"]`
3. Get the object — `cores`, `memory_gib`, `boot_disk`, `image`, `run_strategy` are gone

**Expected:** Only the masked field should change. Other fields preserved.

**Root cause:** The `masks.Path.Set()` implementation likely replaces the
entire `spec` message rather than setting only the leaf field when processing
a nested path like `spec.restart_requested_at`. This causes unset fields in
the input to overwrite populated fields in the existing object.

**Impact:**
- Blocks VM restart (MGMT-23329) from working end-to-end via the API
- Affects any update-mask operation on ComputeInstance explicit spec fields
- Workaround: set restartRequestedAt at creation time, or patch CR directly

**Related:** Discovered during MGMT-23329 E2E testing.
Tested on fulfillment-service commit eea2905 (2026-03-19).
