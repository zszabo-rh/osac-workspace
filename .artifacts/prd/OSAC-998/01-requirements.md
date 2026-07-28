# Raw Requirements — OSAC-998

## Source Issue

- **Key:** OSAC-998
- **Summary:** Quota Management
- **Status:** New
- **Priority:** Undefined
- **Labels:** OSAC, rfp-telefonica-gigafactory
- **Fix Version:** 0.3
- **Size:** Not set

## Description

### Feature Goal

Provide quota support including integration with ColdFront in a flexible fashion that does not bind the solution tightly to MOC requirements.

Enhancement Proposal (referenced in the ticket, now superseded — see Initial Observations): https://github.com/osac-project/enhancement-proposals/pull/8

### Problem Statement

OSAC needs a quota management system to control resource allocation across tenants and projects. Current implementation lacks flexible quota enforcement and integration capabilities.

### Tenant User Stories

- As a Cloud Provider Admin, I need to set resource quotas per tenant
- As a Tenant Admin, I need to see current quota usage and limits
- As an OSAC Cloud Infrastructure Admin, I need quota system to integrate with ColdFront for allocation management

### Definition of Done

- [ ] Quota API endpoints implemented (create, read, update, delete)
- [ ] ColdFront integration functional and tested
- [ ] Quota enforcement active across resource types (VMs, storage, networking)
- [ ] Documentation updated with quota management guide
- [ ] E2E tests covering quota scenarios

### Out of Scope

- Billing or cost management features
- Automated quota adjustment based on usage patterns
- Multi-cluster quota federation

## Acceptance Criteria / Definition of Done

See Definition of Done above (no separate acceptance criteria section on the issue).

## Comments

**Oved Ourfali** (2026-06-03):
> RFP Gigafactory Requirements Mapping:
> - Req #17 (Chargeback 7.3): Automation hooks for quota breach suspension and unusual consumption alerts — Partial (quota management exists but automation hooks for suspension/alerting not explicitly scoped)
> - Req #21 (Job Scheduling 4.4): Automated quota enforcement across jobs (CPU hours, GPU hours, memory) — Partial (feature covers platform-level quota, per-job quota handled by Slurm)

**Vladik Romanovsky** (2026-06-09):
> [to Alona Paz] I've made a suggestion on https://github.com/osac-project/enhancement-proposals/pull/28 regarding this. I'd like to be included in the conversation when this is going to be picked up again, please.

**Zoltan Szabo** (2026-07-15):
> Process note for future PRD/design workflow runs on this feature: the child Epic OSAC-70 and its child Task OSAC-333 predate this project's PRD + Design two-stage workflow (and also predate /design:decompose + /design:sync). As of 2026-07-15, no formal decomposition has been performed, so during the first workflow execution their existence should not be read as evidence that decomposition has already run against this Feature.

## Linked Issues

### OSAC-991: NCP Integration — NVIDIA requirements coverage
- **Relationship:** relates to
- **Status:** In Progress
- **Description:** Outcome-type issue tracking NVIDIA Cloud Partner (NCP) requirements coverage; OSAC-998 is one of the related features feeding into it.

## Attachments

None.

## Initial Observations

- **The issue description is a stale, unfilled Jira template.** The Definition of Done checkboxes are all unchecked placeholders, "Feature origin"/"Reasoning"/"Competitor analysis" boilerplate sections from the Feature creation template were never filled in (not captured above since they contained no content), and the linked "Enhancement Proposal" points to PR #8 — an even older proposal than PR #28 (the one actually reviewed through mid-2026). The description has not been kept in sync with actual project history.
- **Tension in the Feature Goal itself:** it asks for ColdFront integration "in a flexible fashion that does not bind the solution tightly to MOC requirements" — this pairs a specific external integration (ColdFront, MOC-specific) with an explicit instruction not to over-couple to MOC. This needs to be resolved during /clarify: is ColdFront integration a hard requirement for v1, or an example of one pluggable consumer of a more general quota API?
- **MaaS (AI model inference) is entirely absent** from this Feature's description, Definition of Done, and Out of Scope. Given OSAC-985/PR #78 (Metering and Usage Tracking PRD, reviewed 2026-07-14) introduces MaaS as a first-class metered service with its own consumption-based quota-adjacent latency requirements, /clarify should explicitly confirm whether MaaS quota enforcement is in scope for this PRD or deferred.
- **ColdFront and Slurm are named directly in Jira comments/description** (implementation-adjacent specifics) — these will need to be reframed as user-observable outcomes during /draft per the "no design details" hard limit, or captured as integration context/non-goals rather than requirements.
- **The RFP Gigafactory mapping comment (Oved, 2026-06-03) marks two requirements as "Partial"** — automation hooks for quota-breach suspension/alerting, and per-job quota enforcement (explicitly deferred to Slurm, outside OSAC's scope). These read as candidate Non-Goals for the PRD, but should be confirmed during /clarify rather than assumed.
- **No sizing information** (`customfield_10795`) is set on this Feature.
- **A substantial prior enhancement proposal exists** (PR #28, `enhancement/quota-management-v2` branch) with a validated architecture (approval workflow, gating semaphore, `/v1/usage` endpoint) that predates this project's PRD+Design workflow. It is being kept as a reference only — most of its content is expected to carry forward conceptually, but the PRD must be authored fresh from this Feature's requirements, not copied from the old EP's implementation-heavy language.
- **Vladik Romanovsky's request to be included** (2026-06-09 comment) is a process/communication matter, not a requirement — track separately (per user decision: invite to PR review, not a Jira reply).
