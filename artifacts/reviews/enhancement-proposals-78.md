# Review: enhancement-proposals#78 — PRD: Metering and Usage Tracking

## PR Info
- URL: https://github.com/osac-project/enhancement-proposals/pull/78
- Jira: OSAC-985 (under epic OSAC-65)
- Author: masayag (Moti Asayag)
- Created: 2026-06-25
- Base: main ← prd/OSAC-985
- Milestone: 0.3 (metering) / 0.4 (costing/billing/quota enforcement)

---

## Round 1 — 2026-07-13 (Quota Compatibility Analysis)

**Review purpose:** This review assesses PR #78 specifically for compatibility with the quota management EP (PR #28 / OSAC-333). The question driving this review: does the metering model define the "comprehensive metering system" the quota EP anticipated? Does `/v1/usage` need to become a thin wrapper over the metering system? Are there conflicts to resolve before finalizing OSAC-333?

### PR State

| Attribute | Value |
|-----------|-------|
| CI | pre-commit PASS, resolve-pr PASS, review PASS, **tide PENDING** (needs `lgtm` + `jira/valid-reference`) |
| Formal reviews | avishayt: APPROVED (Jul 1); mhrivnak: CHANGES_REQUESTED × 2 (Jun 25, Jun 25 again after rev); no new mhrivnak approval after masayag's Jul 9 update |
| AI EP review | 9/10 PASS (Jul 9 round); AI Design review 6/8 PASS |
| Status | **Not mergeable** — tide blocked on labels; mhrivnak approval likely still needed |
| Commits reviewed | Through Jul 12 (latest push in masayag's Jul 9 update summary) |

### What the Metering PRD Defines

Three services in scope: VMaaS, CaaS, MaaS. All consumption-based (not allocation-based).

| Service | Meter | Unit | Notes |
|---------|-------|------|-------|
| VMaaS | `instance-type-seconds` | uptime × price/s | Running VMs only; stopped/paused VMs do NOT generate compute meter; storage/IPs/DNS continue regardless |
| CaaS | `cluster-uptime` (control plane) + `worker-node-seconds` per host class | Seconds | Active clusters only; failed clusters excluded |
| MaaS | input tokens, output tokens, cached tokens | Tokens | 30s emit / 60s process latency requirement for quota enforcement downstream |

BMaaS, Storage-aaS, and networking are explicitly deferred.

Costing, billing, and quota enforcement are explicitly out of scope for this PRD (deferred to milestone 0.4 and separate PRDs). The PRD is aware of quota as a downstream consumer of metering data.

---

## Compatibility Analysis: Quota EP (PR #28) vs Metering PRD (PR #78)

### TL;DR

The two documents are **architecturally compatible and designed to be complementary**. The quota EP anticipated exactly this metering PRD and was structured to coexist with it. No architectural conflicts require either document to be redesigned. However, the quota EP has a **MaaS-shaped gap** that needs to be addressed, and the EP's language should now be updated to reference OSAC-985/PR #78 specifically rather than "a separate metering proposal."

---

### Where They Align

#### 1. The `/v1/usage` endpoint is not the metering system, and never was

The quota EP says this explicitly and consistently:
- "A comprehensive metering system (time-based consumption tracking for billing) is being designed separately and is **not a dependency** for quota enforcement."
- "/v1/usage endpoint is designed to be **replaceable** — when a comprehensive metering system is available, the QS can be adapted to consume metering data instead."
- The endpoint's design rationale: point-in-time snapshot of `approved_spec`, not accumulated time-based consumption.

The metering PRD confirms this distinction: §2.2 Non-goals explicitly defers quota enforcement to 0.4. The PRD never proposes to replace `/v1/usage`.

**Verdict:** No conflict. The quota EP correctly anticipated this separation.

#### 2. Different semantic purposes — allocation vs consumption

The fundamental semantic difference between the two systems is correct by design:

| Dimension | `/v1/usage` (quota EP) | Metering PRD |
|-----------|------------------------|--------------|
| Model | **Allocation-based** | **Consumption-based** |
| Data source | `approved_spec` in FS DB | Lifecycle events (start/stop) |
| Query | "How many VMs does tenant X have allocated right now?" | "How many instance-type-seconds did tenant X consume this month?" |
| Stopped VM | **Counts against quota** (capacity is reserved) | **Not metered** for compute |
| Failed resource | Counts against quota (quota EP §Provisioning Failure) | Not metered (PRD §CAP-11/12) |
| Use case | Admission control (gate new provisioning requests) | Billing, analytics, dashboards |

A stopped VM counts against allocation quota (the tenant has claimed those resources, blocking others) but does NOT accumulate compute-time billing (the tenant isn't using compute cycles). This is not a contradiction — it's the correct cloud model. AWS, GCP, and Azure behave identically.

The metering PRD §9.5 ("Should allocation-based metering be supported?") raises allocation-based billing as an open question for GPU-intensive providers. If a provider adopts allocation-based billing in the future, the quota EP's `approved_spec` model would then coincide with the metering model — and the Quota Service could consume metering data directly (which the quota EP already anticipated). Until then, they remain appropriately separate.

#### 3. Metering unavailability does not affect quota enforcement

Metering PRD §9.3 raises as an open question whether provisioning should block when metering is unavailable. The quota EP is insulated from this question: the Quota Service reads `/v1/usage` from the FS database directly, not from an external metering system. Quota enforcement works even when metering is down. This is a significant resilience advantage worth preserving and documenting explicitly in the updated quota EP.

#### 4. The "current footprint" view (metering §9.2) does not replace `/v1/usage`

The metering PRD §9.2 notes that the metering system "inherently maintains a view of which resources are currently active — any resource that has emitted a start event but not yet a stop event is running." It concludes this is an API/UI composition question, not a metering gap.

This does NOT replace `/v1/usage` for quota purposes:
- Metering's "currently active" view = resources currently running (start event, no stop event) = consumption-based snapshot
- `/v1/usage` = resources currently approved/allocated (including stopped, scaling, unhealthy) = allocation-based snapshot

The Quota Service needs the allocation-based view. The metering system's active-resource view would systematically undercount quota consumption by excluding stopped VMs.

#### 5. Resource class / host class alignment

The metering PRD uses instance type names and host class names as opaque labels: "The metering system does not define, replace, or constrain these." The quota EP's `/v1/usage` response groups by resource type (clusters, vcpus, nodes.h100, nodes.fc430), which maps naturally to the same labels. No schema conflict.

---

### Where They Diverge / Gaps to Resolve

#### GAP 1 (MaaS — significant): Quota EP has no MaaS section

**This is the primary new requirement from the metering PRD that the quota EP must address.**

The metering PRD introduces MaaS (AI model inference) as a first-class metered service:
- MaaS is consumption-based per token (input/output/cached), not per time unit
- The PRD explicitly calls out that metering events must be emitted within 30s and processed within 60s "so that downstream systems (e.g., quota enforcement) can evaluate against near-real-time balances"
- Tokens cannot be "pre-allocated" — the tenant doesn't declare "I will use 1M tokens this month" — there is no `spec` to put in `approved_spec`

This means the quota EP's approval workflow model (spec → approved_spec → gate → approve/reject) **does not apply to MaaS**. Token quotas are fundamentally budget/spending limits, not capacity allocation limits. The Quota Service for MaaS would need to:
1. Maintain a token budget per tenant (or per project, per the Organizations EP)
2. Consume near-real-time token metering data (from the metering system, not `/v1/usage`)
3. Respond within the 60s window to allow or deny inference requests

The quota EP needs a new section that acknowledges:
- MaaS quota enforcement uses a different model (consumption-based token budget, not allocation-based spec approval)
- The gate contract for MaaS would be: QS reads accumulated token usage from the metering system (not `/v1/usage`), compares against token budget, and evaluates the request
- The 60s latency requirement from the metering PRD informs the gate service contract for MaaS

**Impact on OSAC-333:** Add a "MaaS Quota" section. The approval workflow machinery (gating semaphore, approved_spec) still applies to ClusterOrders and ComputeInstances. For inference quota, either extend the gate contract or design a separate lightweight check path.

#### GAP 2 (Project-level granularity): Open question in both PRDs

The metering PRD §9.1 defers "per-user filtering within a tenant" to the Usage API or Organizations EP design. The metering PRD also explicitly says metering visibility should respect Organizations EP project-level permissions (`VIEW_PROJECT`).

The quota EP currently enforces quotas at the organization (tenant) level globally. But:
- If metering data is project-scoped (Organizations EP)
- And the metering PRD says providers may want per-project usage breakdown (CAP-9)
- Then quota limits might eventually be per-project, not just per-tenant

This is a future alignment concern, not a blocker for v1. But the quota EP should acknowledge that per-project quota is a natural extension once the Organizations EP lands (currently non-goal in the quota EP).

The "balance-check granularity" open question (user-level vs tenant/project-level) escalated to Jonathan Zarecki/Noy Itzikowitz in the metering PRD §9.1 thread should be watched — its resolution will directly affect both PRDs.

#### GAP 3 (Language/references): "Separate metering proposal" should now be named

The quota EP refers to "a comprehensive metering system (time-based consumption tracking for billing, analytics, and dashboards) being designed separately" in five places. Now that PR #78 exists, the update should name it: "the Metering and Usage Tracking PRD (OSAC-985, PR #78)."

---

### Does `/v1/usage` Need to Become a Thin Wrapper Over the Metering System?

**No, for VMaaS and CaaS quotas.** The two endpoints have different semantics (allocation vs consumption) that serve different purposes. Making `/v1/usage` a wrapper over metering would cause it to undercount quota consumption for stopped VMs — breaking the quota model.

**For future allocation-based billing (§9.5):** If providers adopt allocation-based billing, the boundary between metering and quota blurs. At that point, the Quota Service could optionally consume metering data instead of `/v1/usage`. The quota EP already says this explicitly. No architecture change needed now.

**For MaaS:** The gate service (QS) will need to consume metering data directly for token quota enforcement. `/v1/usage` does not need to expose token data — that's the metering system's job.

---

### Required Changes to the Quota EP (OSAC-333)

| Priority | Change |
|----------|--------|
| **Required** | Add MaaS quota section: acknowledge token-based quotas are consumption-based (not spec/approved_spec), QS reads metering data for MaaS token budget enforcement |
| **Required** | Update all references from "a separate metering proposal" → "the Metering and Usage Tracking PRD (OSAC-985)" |
| **Required** | Answer Barakmor1's open question (Jun 3): the quota EP covers platform-level resources OSAC provisions only (VMs, clusters, BM hosts, networks) — NOT intra-cluster workload quotas (Kubernetes ResourceQuota's domain). The metering PRD's §2.2 Non-goals confirms this: "Workload-level metering inside tenant clusters, VMs, or hosts (OSAC has no visibility into tenant-managed workloads)" |
| Recommended | Add an explicit note that `/v1/usage` is allocation-based (not consumption-based) to prevent future confusion as metering lands |
| Recommended | Note that metering unavailability does not affect quota enforcement (resilience feature) |
| Recommended | Add a note that per-project quotas are a natural future extension pending the Organizations EP |
| Optional | Add vladikr/AAQ technical response clarifying why OSAC gates before K8s objects exist (lifecycle mismatch) |

---

### Not-Yet-Merged Status of PR #78

**PR #78 is not yet merged.** Tide is blocked on `lgtm` and `jira/valid-reference` labels. mhrivnak's two CHANGES_REQUESTED rounds were addressed by masayag on Jul 6 and Jul 9, but no updated mhrivnak APPROVED is on record. The quota EP update should reference PR #78 as the in-review metering PRD but should NOT assume it has landed. Language: "the Metering and Usage Tracking PRD (OSAC-985, enhancement-proposals PR #78, in review)."

If PR #78 merges before PR #28, update the reference to the merged document path.

---

## Summary

| Question | Answer |
|----------|--------|
| Is PR #78 the "comprehensive metering system" the quota EP anticipated? | **Yes** — explicitly, for VMaaS/CaaS. MaaS is new territory not anticipated by the quota EP. |
| Does `/v1/usage` need to become a wrapper over the metering system? | **No** for VMaaS/CaaS (different semantics). **Not applicable** for MaaS (different gate contract needed). |
| Are there architectural conflicts? | **No.** The two documents are complementary by design. |
| What must change in the quota EP? | Add MaaS section, update references to name OSAC-985, answer Barakmor1 |
| Is PR #78 blocking PR #28 approval? | **No.** The quota EP's design is independent of metering being available. But naming the now-known metering PRD strengthens the quota EP and closes mhrivnak's original concern about metering/quota separation. |

### Recommendation for PR #28 / OSAC-333

The quota EP does not need a structural redesign. The three required changes above (MaaS section, reference updates, Barakmor1 answer) are additive. The quota EP's core architecture (approval workflow, gating semaphore, approved_spec, `/v1/usage`) is validated by the metering PRD — the two designs are coherent together.

**Suggested next action:** Branch `enhancement/quota-management-v2`, apply the three required changes, push to fork, post a follow-up comment on PR #28 summarizing the metering PRD compatibility analysis and the MaaS section addition. Target mhrivnak's review: the compatibility analysis directly addresses his original "metering/quota separation" concern (CHANGES_REQUESTED, Jun 25 round 1).
