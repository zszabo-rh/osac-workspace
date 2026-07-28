# Clarification Log — OSAC-998

## Status

- Rounds completed: 2
- Open gaps: 1 (non-functional requirements / edge-case behavior — see Remaining Gaps)
- Exit criteria met: Partially — see assessment below

## Round 1 — Scope boundaries

### R1.Q1: ColdFront vs. general pluggability
**Answer:** Telefonica Gigafactory (RFP label on this Feature) indicates MOC is not the only customer. The quota limit-setting API should be generic/provider-agnostic; a ColdFront-specific plugin is a nice-to-have, lower priority, likely out of scope for this PRD.
**Impact:** Locked as D1/D3 below. Clarified further in follow-up: "generic" applies only to how limits are set, not to enforcement (see R2 follow-up).

### R1.Q2: MaaS scope
**Answer:** MaaS didn't exist when the Feature was created, but the quota system must handle all OSAC resources including MaaS, and ideally speak to future resource types too.
**Impact:** MaaS is in scope (D5). Extensibility question deferred to R2.Q3.

### R1.Q3: Resource types
**Answer:** Cover all resource types (same reasoning as R1.Q2).
**Impact:** Initially locked as "all types in scope" (D4 v1) — later revised in Round 2 after the phasing discussion (see D4 REVISED below).

### R1.Q4: Breach automation & per-job quota non-goals
**Answer:** Requested an explanation of "breach automation" first (provided: automated suspension/alerting beyond basic admission rejection — confirmed NOT present in PR #28). Agreed to treat as Non-Goal per Oved's June 3 RFP-mapping comment; let reviewers push back if this reads wrong.
**Impact:** Locked as D6. Per-job/Slurm quota also treated as Non-Goal, generalized in R2.Q4 to avoid naming a specific scheduler.

### R1.Q5: Tenant User persona
**Answer:** The four OSAC personas weren't finalized when the Feature was created, but the PRD/design must cover all of them.
**Impact:** Locked as D10.

## Round 2 — Scope depth & structure

### R2 follow-up: What does "generic API" mean, and doesn't quota need to enforce, not just set, limits?
**Answer:** Confirmed misunderstanding needed correcting — enforcement (gating tenant create/scale requests against configured limits) is core and always-on, not something that varies by allocation source. "Generic" only describes the limit-*setting* interface.
**Impact:** Locked as D2 (new). Ensures the PRD states enforcement as a first-class Goal, not left ambiguous.

### R2 follow-up: Roadmap check for future resource types
**Answer:** User asked to verify via wg-osac-eng Slack and, later, directly via the canonical "OSAC Roadmap" Google Sheet (accessed via `gws` CLI) rather than trusting the stale local roadmap file.
**Finding:** Neither Slack search nor the "roadmap Q2" sheet shows any resource type beyond the current five (BMaaS, CaaS, VMaaS, MaaS, Enclave) — the sheet in fact has zero MaaS rows, confirming it predates MaaS and cannot be used to compare relative priorities. The sheet's own Quota row: Status "Blocked", Priority 2, Owner Zoltan, Dependency noted as "Metering (why it blocks?)" — corroborates the decision to review the Metering PRD (PR #78) first.
**Impact:** Informational — feeds into R2.Q3 and the phasing decision below.

### R2.Q1 (phasing) — resolved after roadmap research
**Answer:** Align quota's milestone scope with the Metering PRD (OSAC-985 / PR #78), which shares the same fix version (0.3) and already made this exact call: VMaaS + CaaS + MaaS in scope for 0.3, Storage-aaS/Object Storage/networking metering explicitly deferred. User confirmed: "let's keep quota PRD in sync with metering."
**Impact:** **D4 REVISED (supersedes the Round 1 "cover all" answer):** Quota enforcement for VM, Cluster (CaaS), and Bare Metal is in scope for this PRD's target milestone. **Storage and Networking resource-type quota enforcement is deferred to a future milestone (Non-Goal)**, explicitly tied to the Metering PRD's own deferral of those same resource types — not an arbitrary scope cut.

### R2.Q2: MaaS as a distinct concept
**Answer:** "Feels like a different concept that should be handled separately."
**Impact:** Locked as D8 — MaaS usage budgets (consumption-based) are a distinct capability set from resource capacity quotas (allocation-based for VM/Cluster/Bare Metal), not unified into one "quota" concept in the PRD.

### R2.Q3: Extensibility as an explicit PRD requirement
**Answer:** "Depends on the roadmap... sounds more like a design detail." Roadmap research (see above) found no other future resource type is currently anticipated.
**Impact:** Locked as D9 — extensibility to future resource types is not stated as an explicit PRD requirement; treated as a design-time concern, informed by MaaS's own precedent.

### R2.Q4: Non-Goal wording for workload/per-job quota
**Answer:** "Yes, make it generic."
**Impact:** Locked as D7 — Non-Goal wording avoids naming a specific scheduler (e.g., Slurm); states "workload-level quota inside tenant-managed clusters is out of scope, enforced by the tenant's own scheduler."

### R2.Q5: Goal/Non-Goal wording for ColdFront
**Answer:** "Sounds fine."
**Impact:** Confirms D1/D3 wording as drafted.

## Locked Decisions

- **D1:** The quota limit-setting interface must be generic/allocation-source-agnostic — usable by any authorized external system or admin, not built specifically for ColdFront. `[R1.Q1, R2.Q5]`
- **D2:** Enforcement — gating tenant create/scale requests against configured limits — is a core, always-on OSAC platform behavior, not pluggable and not dependent on how a limit was set. `[R2 follow-up]`
- **D3:** A ColdFront-specific connector/plugin is out of scope for this PRD (candidate lower-priority follow-on work, not a v1 deliverable). `[R1.Q1, R2.Q5]`
- **D4 (REVISED):** Quota enforcement for VM, Cluster (CaaS), and Bare Metal is in scope for this PRD's target milestone. Storage and Networking resource-type quota enforcement is deferred to a future milestone (Non-Goal), aligned with the Metering PRD's (OSAC-985/PR #78) own deferral of the same resource types under the shared 0.3 fix version. `[R1.Q3, R2.Q1]`
- **D5:** MaaS is in scope for this PRD's target milestone, aligned with the Metering PRD's 0.3 scope. `[R1.Q2, R2.Q1]`
- **D6:** Automated quota-breach suspension/alerting is a Non-Goal for this PRD. `[R1.Q4]`
- **D7:** Per-job/workload-level quota inside tenant-managed clusters is a Non-Goal, worded generically (no scheduler names). `[R1.Q4, R2.Q4]`
- **D8:** MaaS usage budgets are a distinct capability set from resource capacity quotas (VM/Cluster/Bare Metal) — not unified into one "quota" concept. `[R2.Q2]`
- **D9:** Extensibility to future OSAC resource types is not stated as an explicit PRD requirement (design-time concern). `[R1.Q2, R2.Q3]`
- **D10:** PRD must cover all four OSAC personas (Cloud Provider Admin, Cloud Infrastructure Admin, Tenant Admin, Tenant User); Tenant User gets its own capability, not folded into Tenant Admin. `[R1.Q5]`

## Remaining Gaps

- **Non-functional requirements are not yet enumerated.** No discussion yet of concrete, testable constraints — e.g., how quickly must an enforcement decision be returned to the tenant, whether quota checks must remain accurate under concurrent requests from the same tenant, isolation expectations between tenants' quota data.
- **Edge-case / acceptance-criteria-level behavior not yet confirmed** — e.g., what a tenant observes when a request is rejected for exceeding quota (error message content/specificity), whether usage visibility includes a "nearing limit" indicator (a passive display, distinct from the automated breach-actions already ruled out in D6), and whether a quota limit change takes effect for in-flight vs. only future requests.
