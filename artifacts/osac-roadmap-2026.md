# OSAC Roadmap — 2026

*Last updated: 2026-05-05 based on meeting analysis (March 2 – May 4, 2026)*

## Strategic Context

OSAC is transitioning from a development/research project to a platform that must support production MOC 2.0 operations. Key external drivers:

1. **MOC 2.0** — June 1, 2026 dev cluster inclusion; end of summer compliance
2. **ARPA-H $50M program** — medical data platform requiring HIPAA/NIST 800-171 compliant cluster provisioning
3. **Foxconn partnership** — driving Netris networking integration priority
4. **NVIDIA Carbide/Nico** — GPU infrastructure management integration (DPU zero-trust networking)
5. **Red Hat Summit demos** — VMaaS and CaaS booth demos (May 2026)
6. **NVIDIA NCP (Cloud Partner)** — VAST/DDN fast storage for KV cache and model storage; DGXO reference architecture
7. **IBM Sovereign Core** — potential consumer of VMaaS (not yet production-ready)

### Q2 2026 Roadmap (official, per Alona's weekly report Apr 27)

Three primary use cases driving prioritization:

1. **VMaaS (VCD Alternative)** — VM provisioning positioned as VMware VCD replacement
2. **CaaS with NIC-Mode Networking (Netris)** — bare metal cluster provisioning using Ironic + traditional NIC-mode + Netris for network tenancy
3. **CaaS with DPU Zero-Trust Networking** — bare metal cluster provisioning using Ironic + DPU-based network tenancy (Carbide/Nico)

---

## Timeline

### NOW — April 2026 (In Progress)

| Work Stream | Items | Status | Owner(s) |
|-------------|-------|--------|----------|
| **Bare Metal** | Enhancement proposal | **APPROVED & MERGING** (Apr 13) | Tzu-Mainn, Lars |
| **Bare Metal** | Separate bare metal operator | Decision made — separate from OSAC operator | Tzu-Mainn, Lars |
| **Bare Metal** | Terminology: "host type" (hardware) vs "host class" (backend) | Agreed (Apr 13) | Tzu-Mainn |
| **Networking** | Basic networking components | Near finalized, ~5 tickets + bugs remaining | Eran Cohen |
| **Networking** | Public IP Pool (MetalLB L2) | Operator+AAP ready; fulfillment nearly ready. **Target: May 1 demo** | Akshay, Dakota, Sedat |
| **Networking** | FQN-to-UID standardization | In progress | Elad Tabak |
| **Networking** | Network class defaulting | Draft PRs open | Will Gordon |
| **Fulfillment** | IDP/Keycloak + Organizations | **MERGED** (IDP). Org mgmt nearly complete — **demo May 1**. Keycloak manifest integration in progress. | Crystal Chun |
| **Fulfillment** | Optimistic locking + leader election | In progress | Juan |
| **Fulfillment** | Template catalog/inheritance EP | Awaiting review | Juan |
| **Fulfillment** | GPU pass-through CRD auto-config | PR submitted (Apr 22), awaiting review | Juan |
| **Fulfillment** | Catalog items EP | Original proposal to be finalized (Juan's alternative rejected Apr 20) | TBD |
| **Fulfillment** | CLI rename to "osac" | **COMPLETED** (Apr 22) | Will Gordon |
| **Fulfillment** | Service rename: "fulfillment service" → "OSAC service" | Proposal submitted (Apr 22) | Elad Tabak |
| **Fulfillment** | CaaS API enhancement (fields to cluster spec) | Done, awaiting review | Elad Tabak |
| **Carbide/Nico** | Create/delete/scale integration | **WORKING** — full demo shown Apr 27. PR open, **blocked on CaaS networking alignment** with Dan Manor. | Trey West |
| **Carbide/Nico** | Pre-register agents | **BLOCKED** — API limitation (can't move instances between VPCs). Agents created at fulfillment time. | Trey West |
| **CI** | VMaaS networking CI | **MERGED** | Omer Vishlitzky |
| **CI** | CaaS CI, OSAC installer CI | 4 PRs open, rehearsals ongoing | Omer Vishlitzky |
| **AI Policy** | Formal policy document | Near finalized, 24h comment deadline set (Apr 13) → PR to docs repo | Eran Cohen |
| **Quota** | Enhancement proposal finalization | Michael's feedback addressed. **Visibility gap** — team unaware of progress | Zoltan |
| **Storage** | Storage tenant onboarding | **Code complete**, PRs submitted. Blocking on docs + code review. Demo ~1.5 weeks (mid-May). | Zoltan |
| **Storage** | Storage quota enforcement (provider-level) | **DECIDED** (Apr 22) — CaaS/BM at provider level, VMaaS via CSI/webhook | Will, Avishay, Zoltan, Lars |
| **Storage** | VAST integration for NCP | Test framework PR up, Ansible code functional against mocked server. Waiting for Vast on Cloud access (**May 4 call**). OVA on KubeVirt as alternative. | Will Gordon |
| **Storage** | Storage Ansible automation (Phase 1) | **Active** — 2 cards in sprint | Will Gordon |
| **Storage** | DGXO reference architecture review | **In progress** | Fabien Dupont |
| **DNS** | DNS API | **Fundamentally complete** — Route 53 backend, extensible architecture. Demo May 1. | Dan Manor |
| **Instance Types** | Define instance types across BM/VM | Enhancement proposal in design (Avishay, next week). Not yet decided: merge BM/VM into single compute resource abstraction. | Avishay, Michael |
| **GPU** | GPU pass-through template | **WORKING** — demo shown Apr 20 | Juan |
| **GPU** | Automate HyperConverged CR config | **NEW** — reduce admin burden for new GPU types | TBD |
| **VMs** | Windows VM support | **WORKING** — templates created, API testing needed. Demo ~2 weeks (mid-May). | Ameya Sathe |
| **Demo** | Weekly demo cadence in Monday meetings | Active — 3-week planning tab added. Automate demo process. | Oved, Alona |
| **Demo** | Networking + VM demo re-recording | **DONE** — recorded demo shown Apr 27. Security groups + network isolation working. | Adrien |
| **Image Mgmt** | Image management EP + epics | **NEW** — upload images via API, reference, save VMs to images (backup). Adrien reviewed EP. | Avishay |
| **CaaS** | CaaS+BM end-to-end flow | **DEMOED May 4** — full flow working: CLI → AAP → BM pool → agent assignment → cluster. Profile-based templates next. | Tzu-Mainn, Austin, Lars, Dan Manor |
| **CaaS** | Automate bare metal server registration | Fast-path Ansible playbook. Host lease CRs as unified API. | Dan Manor, Alona Paz, Lars |
| **CaaS** | Stable UI integration environment | **NEW** — dedicated single-node OpenShift on 830-class machine. Ticket to be created (Adrien), setup by Lars. | Adrien, Lars |
| **CI** | VMaaS (VIMAS) deployment | **MERGED** — can be demoed May 1 (local/Beaker). | Omer Vishlitzky |
| **CI** | VMaaS E2E testing | **In progress** — lifecycle tests (create/run/delete), Prow-triggered. 2-2.5h per run. Working on unified environment + golden image to cut to ~60min. | Omer Vishlitzky |
| **Jira** | Migrate to dedicated OSAC project | **DECIDED May 4** — moving from MGMT to OSAC project. Amir Gv managing. Will break integrations temporarily. | Amir Gv |
| **Console** | Console proxy for dedicated VMaaS clusters | **In progress** — per-namespace approach validated locally. "Couple more days" to complete. | Ilya Skornyakov |
| **Summit** | Demo feature gap analysis (events, alerts, observability) | Epics created by Adrien | Adrien, Elliot Belovich |
| **Org** | GitHub org permissions simplification | Blanket write access for all members | Lars |
| **Docs** | Component-local docs + aggregator pattern | CLI as proof-of-concept | Will Gordon |

### May 2026 — Summit

| Work Stream | Items | Notes |
|-------------|-------|-------|
| **Summit demos** | VMaaS booth demo | Working with UIX team (Ethan, Elliot) |
| **Summit demos** | CaaS booth demo (ESI + Carbide) | Oved's document maps two use cases |
| **Summit demos** | Feature gap epics: events, alerts, VM observability (CPU/mem) | Created by Adrien |
| **UI** | Demo mockups being made real | Currently mocked, team working to implement before summit |

### June 1, 2026 — MOC 2.0 Dev Cluster

| Work Stream | Items | Notes |
|-------------|-------|-------|
| **CaaS** | Automated cluster provisioning via OSAC | Replaces MOC's manual process |
| **Bare Metal** | ESI-based host management | Core path for MOC clusters |
| **Compliance** | Basic HIPAA/NIST 800-171 awareness | Not full compliance yet |
| **Quota** | Resource quota enforcement | Called out as a gap (Oved, Apr 8) |

### End of Summer 2026 — MOC 2.0 Production

| Work Stream | Items | Notes |
|-------------|-------|-------|
| **Compliance** | HIPAA + NIST 800-171 compliance | Driven by ARPA-H hospitals |
| **VMaaS** | Production readiness assessment | Deploy to dev first, evaluate |
| **Monitoring** | Monitoring and charging | Blockers for VMaaS production |
| **Multi-replica** | Controller HA (using Juan's locking) | Reliability for production |

### H2 2026 — Growth Phase

| Work Stream | Items | Notes |
|-------------|-------|-------|
| **Networking** | Additional network classes (Netris, Metal3) | Pluggable backend ecosystem |
| **Networking** | Batch/parallel operations for bare metal | Orran's push, deferred from v1 |
| **Bare Metal** | Flexible workflow/profiles | After hardcoded cluster fulfillment works |
| **Bare Metal** | Metal3 as default backend option | Metal3 team interested once stable |
| **Organizations** | Multi-org support | Crystal's Keycloak work is foundation |
| **Instance Types** | Unified instance type system (BM + VM) | Includes GPU, storage profiles, inventory tracking |
| **Metering** | Comprehensive metering system | OpenMeter vs Red Hat cost mgmt decision pending (needs Michael). Event source reliability fix needed. |
| **Cost Management** | Integration with Red Hat sovereign cost mgmt | GPU utilization, allocation-based billing. Competes with OpenMeter direction — must choose. |
| **Post-install** | Formalized service installation (Slurm, GPU ops) | Michael flagged as needed |

---

## Architecture Evolution

### Networking Stack (converging)
```
Tenant API (fulfillment-service)
    └─ Network Class (pluggable)
         ├─ ESI Network Class (OpenStack Neutron) ← first implementation
         ├─ Netris Network Class ← Foxconn-driven
         ├─ Metal3 Network Class ← future
         └─ Public IP Pool (MetalLB L2) ← starting now
```

### Bare Metal Stack (emerging)
```
fulfillment-service → HostPool CR
    └─ Bare Metal Pool Operator (creates Host CRs)
         └─ Host Inventory Operator (queries backend, assigns mgmt class)
              └─ Host Management Operator (per-backend, separately installable)
                   ├─ Ironic backend (ESI)
                   ├─ Carbide backend (NVIDIA)
                   └─ future backends
```

### Fulfillment Service (maturing)
```
- Optimistic locking → leader election → multi-replica HA
- Template inheritance → catalog system
- Organizations → multi-org Keycloak integration
- Quota service → gating semaphore → usage tracking
```

---

## Key Risks and Dependencies

| Risk | Impact | Mitigation |
|------|--------|------------|
| Michael Hrivnak review bottleneck | Multiple EPs and PRs blocked (GPU quota EP long-standing) | Escalate; schedule dedicated review sessions |
| MOC 2.0 June 1 deadline | Scope pressure on CaaS + bare metal | Focus on CaaS automation, defer VMaaS |
| ARPA-H approval (~April 13) | Budget and urgency for compliance work | Consultants already building; OSAC automates |
| Netris monolithic API mismatch | Complicates integration | Dan decomposing into individual endpoints |
| Metal3 networking overlap | Potential duplication | Active discussions with Dmitry Tantsur |
| AI policy not yet established | Risk of inconsistent practices | Near finalized, 24h deadline set Apr 13 |
| Carbide VPC isolation constraint | No API to move instances between VPCs | Scale-down requires delete+recreate |
| Quota visibility gap | Leadership (Oved) perceives no progress | Post Slack status update; storage tier implementation kickoff imminent |
| Metering 2.0 document | Strategic dependency for MOC 2.0 billing | MOC metering requirements to be incorporated into OSAC (avoid MOC-only code). Event-based tracking required. |
| Metering direction undecided | OpenMeter vs RH cost mgmt blocks quota & event infrastructure design | Needs Michael present to decide. Deferred Apr 27. |
| Carbide→Nico multi-tenancy | OSAC and Nico multi-tenancy can't work together | Need to decide: modify one/both or rely on OSAC only |
| Code review bottleneck | PRs blocking (Crystal's org PR, Juan's GPU PR) | Oved introduced mini code-review groups (2-3 per work stream) |
| Jira project migration | Temporary disruption to all Jira integrations, skills, and queries | Monitor migration progress; update JQL queries once new project key confirmed |

---

## People / Ownership Map

| Area | Primary | Secondary |
|------|---------|-----------|
| Bare Metal Fulfillment | Tzu-Mainn Chen, Austin Jamias | Lars, Danni Shi |
| Networking API | Eran Cohen | Adrien Gentil |
| Netris Integration | Dan Manor | Lars |
| Carbide Integration | Trey West | - |
| Fulfillment Service | Juan Hernandez | - |
| OSAC Operator | Elad Tabak | - |
| AAP/Ansible | Avishay Traeger, Adrien | - |
| Auth/Orgs | Crystal Chun | - |
| Quota | Zoltan Szabo | - |
| Storage (VMaaS) | Akshay Nadkarni | Zoltan (tier implementation) |
| Storage Automation/VAST | Will Gordon | - |
| Storage (CaaS) | TBD (pending coordination meeting) | Will, Avishay, Lars |
| Instance Types | Avishay Traeger | Michael Hrivnak (UX) |
| GPU | Juan Hernandez | Trey West |
| Public IP Pool | Akshay Nadkarni | - |
| CI/Testing | Omer Vishlitzky | - |
| Summit Demos | Oved Ourfali | Ethan Kim, Elliot Belovich (UI), Adrien (feature gaps) |
| AI Policy | Eran Cohen | Orran, Idomar |
| Architecture | Michael Hrivnak | Lars |
| Project Mgmt | Alona Paz | Oved Ourfali |
| MOC Strategy | Orran Krieger | Heidi Dempsey |
