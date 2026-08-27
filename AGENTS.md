# OSAC Workspace

Meta-workspace that bootstraps all OSAC (Open Sovereign AI Cloud) component repos for cross-component development, testing, and AI-assisted workflows. OSAC is a fulfillment system for provisioning Kubernetes clusters and compute instances with networking capabilities. Primary languages: Go, YAML, Python. Primary tools: kubectl, jira CLI, gh CLI.

## Critical Rules

- **`osac-workspace/` is the project root** — all work happens from here; component docs are loaded via progressive disclosure
- **Never skip tenant isolation metadata** (`osac.openshift.io/tenant`, `osac.openshift.io/owner-reference` annotations) in new resources
- **Always `buf lint` before committing** proto changes; regenerate with `buf generate`
- **Fork-based workflow**: push to `$PUSH_REMOTE`, never to `$UPSTREAM_REMOTE` — resolve via the vendored `resolve-remotes.sh` (full detail in the shared `dev-conventions` rule, see [Git Workflow](#git-workflow) below)
- **AI attribution**: use an `Assisted-by: <tool> <contact>` trailer on commits, naming whichever AI tool actually did the work — never use `Co-Authored-By` for AI tools (Red Hat attribution standard). Example for Claude Code: `Assisted-by: Claude Code <noreply@anthropic.com>`
- When debugging Kubernetes operators, check for stale vendor directories and cached images before rebuilding
- **Edit OSAC skills only in [`osac-project/osac-ai-skills`](https://github.com/osac-project/osac-ai-skills)** — this workspace vendors them via `./bootstrap.sh`; do not treat local `skills/` as an editable source
- **Bump `metadata.version` in any skill you modify in `osac-ai-skills`** — that repo's `check-skill-version-bump` CI enforces semver patch/minor bumps (e.g. `0.1.0` → `0.1.1` / `0.2.0`)

## Dev Environment

### Option A: Distrobox (recommended)

All dev tools are packaged in a Fedora 42 container (`Containerfile`). Requires `podman` and `distrobox`.

```bash
make enter                     # Build image and enter distrobox
make status                    # Check image and distrobox status
make rebuild                   # Rebuild image from scratch
```

### Option B: Local toolchain

Install Go, Node.js, buf, kubectl, kind, jira CLI, gh CLI, jq directly.

### Option C: Local Kind cluster

Kind lives in the `osac` mono-repo, under `osac-installer/` (no Makefile at the `osac/` root). From this workspace:

```bash
make -C osac/osac-installer install PLATFORM=kind PROFILE=dev NS=osac
```

Infra-only, uninstall, `/etc/hosts`, and test suites: [`osac/fulfillment-service/AGENTS.md`](osac/fulfillment-service/AGENTS.md) (Integration Tests).

### Bootstrap

```bash
./bootstrap.sh                 # Clone all repos with fork setup (requires gh CLI)
./bootstrap.sh --no-fork       # Clone read-only without forking
```

Re-run `./bootstrap.sh` anytime to update all repos to latest `main`.

## Repository Structure

Meta-workspace — run `./bootstrap.sh` to clone/update all component repos to latest `main`. **In component repos, read `CLAUDE.md` first** (progressive disclosure). Use that component's `AGENTS.md` where the table below shows **Yes** for tool-agnostic build/test conventions.

Note: `fulfillment-api` and `fulfillment-common` were merged into `fulfillment-service`, which was then merged with `osac-operator`, `osac-aap`, `osac-installer`, `bare-metal-fulfillment-operator`, and `osac-csi-driver` into the `osac` mono-repo below.

| Component | Description | AGENTS.md |
|-----------|-------------|-----------|
| [`fulfillment-service`](https://github.com/osac-project/fulfillment-service) | gRPC server + REST gateway, PostgreSQL, integrated API definitions | Yes |
| [`osac-operator`](https://github.com/osac-project/osac-operator) | Kubernetes operator for OpenShift clusters via Hosted Control Planes | Yes |
| [`osac-aap`](https://github.com/osac-project/osac-aap) | Ansible Automation Platform roles for network provisioning | — |
| [`osac-installer`](https://github.com/osac-project/osac-installer) | Installation manifests and prerequisites | Yes |
| [`osac-test-infra`](https://github.com/osac-project/osac-test-infra) | Integration testing infrastructure | — |
| [`osac-ui`](https://github.com/osac-project/osac-ui) | OSAC UI web console | Yes |
| [`enhancement-proposals`](https://github.com/osac-project/enhancement-proposals) | Design documents and RFCs | — |
| [`docs`](https://github.com/osac-project/docs) | Architecture docs and guides (see `osac-docs/architecture/`) | — |

## Build and Test

This workspace has no build step of its own. Each component repo documents build and test commands in its `AGENTS.md` or `CLAUDE.md`.

| Component              | Build                              | Unit Tests               | Lint                       |
|------------------------|------------------------------------|--------------------------|----------------------------|
| `fulfillment-service/` | `go build`                         | `ginkgo run -r internal` | `uv run dev.py lint`       |
| `osac-operator/`       | `make build`                       | `make test`              | `make lint`                |
| `osac-aap/`            | —                                  | —                        | `ansible-lint`             |
| `osac-installer/`      | `kustomize build overlays/<name>`  | —                        | `yamllint --strict .`      |
| `osac-test-infra/`     | —                                  | —                        | `pre-commit run --all-files` |
| `osac-ui/`             | `pnpm build`                       | `pnpm test`              | `pnpm lint`                |

### Quick Reference

```bash
# osac/fulfillment-service
cd osac/fulfillment-service
go build ./...                        # Build
ginkgo run -r internal                # Unit tests (excludes integration)
# Integration tests: AGENTS.md (Integration Tests)
make -C ../osac-installer test PLATFORM=kind PROFILE=dev NS=osac SUITE=fulfillment
buf lint && buf generate              # Proto lint + codegen

# osac/osac-operator
cd osac/osac-operator
make image-build image-push IMG=<registry>/osac-operator:tag
make install                          # Install CRDs
make deploy IMG=<registry>/osac-operator:tag
```

### CI

The workspace itself runs one GitHub Actions workflow:
- `pr-dashboard.yml` — generates a PR dashboard (runs on schedule, deploys to GitHub Pages via `tools/pr-notify/generate.py`)

Component repos have their own CI pipelines.

## Code Style

### Git Workflow

Fork-based push rules, branch naming, DCO sign-off, AI attribution, and PR
title conventions are generic across any OSAC repo — see the shared
`dev-conventions` guidance centralized in `osac-ai-skills` for the full
detail; summarized in Critical Rules above. `resolve-remotes.sh`
(referenced there) is canonically hosted in `osac-ai-skills`, vendored at
`~/.osac-ai-skills` or `./.osac-ai-skills` (whichever `bootstrap.sh` set
up).

### Cross-Component Changes

`fulfillment-service`, `osac-operator`, `osac-aap`, `osac-installer`,
`bare-metal-fulfillment-operator`, and `osac-csi-driver` all live in one
mono-repo (`osac/`) — a feature spanning any of them (proto definitions,
CRD types, Ansible roles/playbooks, Helm values) lands in a single branch
and PR there.

Link PRs in descriptions: "Depends on osac-project/osac#123".

## Deployment Coordination

`osac-installer/setup.sh` pins component versions (AAP collections, fulfillment-service images) via submodule refs. When making changes that cross component boundaries, always update `osac-installer` to match:

- **New CRD types** in `osac-operator` → register in the `fulfillment-service` reconciler (an in-repo change, same PR)
- **`osac-ui`** → a real external dependency (OCI chart + image, version-tagged), bumped deliberately when a new release is needed

Failing to update `osac-installer` after cross-component changes causes CI failures and deployment mismatches. See `.planning/codebase/CONVENTIONS.md` for the full cross-repo dependency table.

## Enhancement Proposals

OSAC uses the flightctl ai-workflows PRD and design skills with project-level template overrides in `.design/templates/`. The two-stage flow produces a PRD followed by a design document.

### Docs Repo

- Both PRD and design workflows publish to the `enhancement-proposals` repo
- Local path: `./enhancement-proposals/`
- When the publish phase asks for the docs repo, provide this path

### File Path Conventions

When publishing PRDs and design documents to the enhancement-proposals repo:

- Skip the "release" question — use `enhancements` as the fixed directory prefix
- Feature directory: `enhancements/<feature-slug>/` (e.g., `enhancements/storage-network/`)
- PRD filename: `prd.md`
- Design (EP) filename: `design.md`
- Both files live in the same directory: `enhancements/<slug>/prd.md` and `enhancements/<slug>/design.md`

### Fork-Based Workflow

Resolve remotes via the vendored `resolve-remotes.sh` (see [Git Workflow](#git-workflow) above). Push to `$PUSH_REMOTE`, never to `$UPSTREAM_REMOTE`.

### Feature Dimensions Context

Both PRD and design ingest phases must read all files in `.design/context/`:

- **`osac-dimensions.md`** — Cross-cutting dimensions (services, personas, tenant onboarding, inventory, provisioning, networking, storage, installation, E2E testing, documentation, UI) that OSAC features should address where relevant — see `osac-dimensions.md`'s own triage rule for which dimensions apply to a given feature. Use it to guide clarifying questions during PRD clarify and persona/user-story scope during PRD draft (see Personas and `osac-docs/personas.md`); ensure the design covers the dimensions that actually apply.
- **`review-patterns.md`** — Common design reviewer feedback themes, anti-patterns, and the design reference library. Use during PRD draft and design draft to anticipate reviewer expectations.

### Component Conventions

Design and implement ingest phases must read the `AGENTS.md` of each component repo affected by the feature. These contain authoritative conventions for API design, database patterns, testing, and build tooling that the generic workspace rules summarize but do not replace.

For features involving the fulfillment-service API (proto definitions, services, request/response patterns), `osac/fulfillment-service/AGENTS.md` points to [`osac/fulfillment-service/docs/API.md`](osac/fulfillment-service/docs/API.md) — the canonical API design guidelines. Read it before drafting or reviewing proto schemas.

### Template Overrides

- Design template: `.design/templates/design.md` (EP format with PRD-aware modifications)
- Design section guidance: `.design/templates/section-guidance.md`
- PRD template: `.prd/templates/prd.md` (user stories by persona, In Scope/Out of Scope instead of FR-N/NFR-N)

## Jira Conventions

- OSAC uses Jira **Tasks** (not Stories) for implementation work — in the **implement** workflow, "story" references mean Tasks in this project
- Use `jira` CLI for Jira access (e.g., `jira issue view OSAC-1234 --plain`), not Jira MCP
- Planning artifacts live in `.planning/`

### Mandatory Component

OSAC requires a **Component** on every created issue — Jira rejects creates
without one. Any automation creating an OSAC issue must set it:

- Inherit from the parent: epics/stories take the parent Feature's component(s)
  (parent has multiple → give each child the matching subset from the parent's
  set; confirm with the driver before creating).
- **Never invent a component** or use one the parent lacks. If none fits, or the
  parent has none, stop and ask the driver.
- Set on create — MCP `fields: {"components": [{"name": "<name>"}]}` / `jira` CLI
  `-C "<name>"`; match component strings exactly.

## AI-Assisted Workflows

See [`AI-assisted-development-workflow.md`](AI-assisted-development-workflow.md) for the full workflow: Feature → PRD → Design → Jira sync → Implement.

Installed via `bootstrap.sh` from [flightctl/ai-workflows](https://github.com/flightctl/ai-workflows). Available in Claude Code, Cursor, and other AI tools (command syntax varies by tool).

### Development Workflows

- **bugfix** — Systematic bug fix: assess → reproduce → diagnose → fix → test → review → document → pr
- **implement** — Task-to-code: ingest Jira task → plan → code (TDD) → validate → publish PR

Both workflows are phase-based — you can jump to any phase directly (e.g., `bugfix:fix`, `implement:code`).

### PRD and Design Workflows

Two-stage enhancement proposal flow. See the Enhancement Proposals section above for docs repo, file path conventions, and templates.

**Stage 1 — PRD:** ingest → clarify → draft → publish → respond

**Stage 2 — Design (EP):** ingest → research → draft → publish → respond → decompose → sync

**Single-step (legacy):** `/ep.create` (registered legacy skill name; see `CLAUDE.md` for Claude command syntax)

### E2E Test Workflows

Two complementary skills for E2E tests, available from the `osac-workspace/` root:

- **e2e** (ai-workflows) — Full story-to-test workflow: `/e2e:ingest` a Jira [QE] story → `/e2e:plan` scenarios → `/e2e:code` tests → `/e2e:validate` → `/e2e:publish` PR. Framework-agnostic — discovers osac-test-infra's pytest patterns during ingest.
- **debug-e2e** (osac-test-infra) — Debug a failing Prow CI job using build logs and gathered OSAC artifacts. Use after tests exist and fail in CI.

The `/e2e` workflow writes tests in `osac-test-infra/tests/` following the conventions in `osac-test-infra/.claude/skills/e2e.md` (gRPC client patterns, K8s client patterns, wait helpers, pytest fixtures). The `/debug-e2e` skill reads Prow logs and OSAC gathered artifacts to diagnose failures.

### Skill discovery

OSAC-native skill definitions live in [`osac-project/osac-ai-skills`](https://github.com/osac-project/osac-ai-skills). This workspace is a **consumer**: `./bootstrap.sh` vendors that repo (`.osac-ai-skills/` or `~/.osac-ai-skills`) and materializes a local `skills/` overlay (per-skill symlinks plus ai-workflows links). Edit skills only in `osac-ai-skills`; re-run `./bootstrap.sh` (or `tools/link-agent-skills.sh`) to refresh.

Agent discovery after bootstrap:

| Agent | Skill path | Phase commands |
|-------|------------|----------------|
| Claude Code | `.claude/skills/` → `skills/` | `.claude/commands/` (ai-workflows) |
| Cursor | `.cursor/skills/` → `skills/` | `.cursor/commands/` (ai-workflows) |
| Gemini CLI | `.gemini/skills/` → `skills/` | — |
| GitHub Copilot | `AGENTS.md` conventions only | — |

`.claude/`, `.cursor/`, and `.gemini/` are gitignored except project settings; bootstrap recreates agent skill symlinks via `tools/link-agent-skills.sh` (thin wrapper around the vendored fan-out).

Consumers that skip `./bootstrap.sh` (for example the jira-autofix `osac-workspace` profile) must import `osac-ai-skills` themselves and run the same consumer fan-out — otherwise OSAC-native skills will be missing after clone.

`osac` also has its own root `AGENTS.md`/`tools/bootstrap.sh` upstream (`OSAC-3557`), which
installs the same ai-workflows skills for someone cloning `osac` standalone, outside this
workspace. **Don't run `osac/tools/bootstrap.sh` from within `osac-workspace`** — this
workspace's own `./bootstrap.sh` and skill-linking above already cover `osac/` as a
component; running both would install two separate, out-of-sync `.ai-workflows` clones.

### Skill authoring and skillsaw

Author and lint skills in [`osac-ai-skills`](https://github.com/osac-project/osac-ai-skills) (skillsaw CI, `metadata.version` bumps, eval harness). This workspace no longer runs skillsaw or skill-version-check CI.

### Available Skills

**OSAC repo-local skills** (in `skills/`):

- **create-pr** — Fork-based PR creation on component repos
- **report-bug** — File a Jira bug without fixing
- **quick-fix** — Unattended bug fix with Jira ticket and PR
- **osac-feature** — Create OSAC Jira Features
- **jira-task-management** — Manage Jira issues via jira-cli
- **capture-tasks-from-meeting-notes** — Extract action items from meeting notes into Jira
- **generate-status-report** — Generate project status reports from Jira
- **design-review** — Review design documents against template requirements and architectural patterns
- **prd-review** — Review PRDs
- **milestone-scope** — Milestone readiness assessment
- **osac-demo-recording** — asciinema API demo recordings
- **presentation** — Red Hat Marp slide decks
- **osac-cluster** — Boot and manage OSAC development clusters via cluster-tool
- **osac-release** — Publish OSAC Helm chart versions across component repos

## Architecture

```text
fulfillment-service    gRPC/REST API server, PostgreSQL, resource lifecycle
osac-operator          Kubernetes operator, provisions via AAP + Hosted Control Planes
osac-aap               Ansible playbooks for VM and network provisioning
osac-installer         Kustomize overlays, deploys all components to OpenShift
osac-test-infra        E2E test playbooks against fulfillment-service gRPC API
osac-ui                Web console (React, PatternFly 6, pnpm workspace)
enhancement-proposals  Design documents and RFCs
osac-docs              Architecture docs and guides
```

### Resource Hierarchy

```text
Tenant → namespace and network isolation
ClusterOrder → OpenShift clusters via Hosted Control Planes
VirtualNetwork → L2 network with CIDR (child of NetworkClass)
  ├── Subnet → CIDR range within VirtualNetwork
  └── SecurityGroup → firewall rules
ComputeInstance → KubeVirt VM, attached to Subnets + SecurityGroups
PublicIPPool → IP address ranges
  └── PublicIP → allocated from pool, attached to ComputeInstance
```

### Operator Architecture (osac-operator)

The osac-operator uses controller-runtime to reconcile OSAC custom resources on Kubernetes. Key patterns:

- **All controllers follow the same reconciliation pattern**: finalizer → status update → provisioning/deprovisioning lifecycle
- **Shared provisioning lifecycle**: Controllers use `provisioning.RunProvisioningLifecycle()` for provision and manual deprovision handling
- **CRD types**: ClusterOrder, ComputeInstance, Tenant, VirtualNetwork, Subnet, SecurityGroup, PublicIPPool, PublicIP
- **Multi-cluster support**: Controllers use `multicluster-runtime` for management/workload cluster separation
- **Management-state annotation**: All controllers should check `osac.openshift.io/management-state` and skip reconciliation when set to `Unmanaged`
- **Namespace isolation**: Networking controllers filter to a configured namespace via `NetworkingNamespacePredicate`

When fixing bugs or adding features, **check all controllers** that follow the same pattern — a bug in one controller likely exists in others. A missing feature in one controller is also a bug if all controllers are expected to behave consistently.

## UI Reference (osac-ux)

`osac-ux/` is cloned read-only from [osac-project/osac-ux](https://github.com/osac-project/osac-ux).
No PRs are created against it from backend workflow sessions (no `fork` remote).

### What to read during /design:research and /implement:ingest

| Path | Purpose |
|------|---------|
| `osac-ux/libs/ui-components/src/pages/tenant/` | Tenant screens — form fields, list columns, actions |
| `osac-ux/libs/ui-components/src/pages/provider/` | Provider admin screens |
| `osac-ux/libs/ui-components/src/pages/admin/` | Tenant admin screens |
| `osac-ux/libs/ui-components/src/api/v1/` | @temp-api types — use as primary proto field input |
| `osac-ux/apps/e2e/cypress/e2e/flows/` | User journeys for Cypress scenario planning |

### @temp-api types are primary proto input

For **any EP** (new resource or existing resource enhancement), check whether
a matching `@temp-api` file exists at `osac-ux/libs/ui-components/src/api/v1/<resource>.ts`.
If it does, read it and use the TypeScript fields as the source for proto field names
(converting camelCase → snake_case). The EP must include a `## UX Alignment` section
with a field-by-field mapping table and a justification for any deviation.

For existing resources, the @temp-api file may contain fields the UI needs but the
backend has not yet returned — these are real requirements, not speculation.

### API coverage audit (one-time and on-demand)

To surface the full backlog of existing API gaps against the current UI, run:

```bash
cd osac-ux && node scripts/gen-api-diff.mjs
```

This compares all live UI routes against the backend OpenAPI spec and lists
uncovered or mismatched fields. Use the output as input when scoping EP work,
not as a file to commit or reference statically.

### Known deviations — flag these in the EP, do not copy from @temp-api

| @temp-api pattern | Correct fulfillment-service design |
|---|---|
| Sub-resource actions: `POST .../attach`, `POST .../restore` | Standalone `*_attachments` resource (pattern: `public_ip_attachments`) |
| `storageClass: 'ssd' \| 'nvme' \| 'standard'` string union | `storage_tier_id: string` reference to StorageTier resource |
| `spec.storageClassName`, `spec.storageBackend` in StorageTier | Private API only — omit from public proto |
| `status.secretAccessKey?: string` on create response | Separate `Create*Response` proto message |
| `AiEnvironment.spec.rhoaiVersion`, `gatewayEndpoint` | RHOAI operator fields — verify these belong in public API before adding |

## Common Fix Locations (osac/fulfillment-service)

Use this table to go directly to the right file for common bug patterns instead of grepping from scratch:

| Bug pattern | File(s) to check |
|-------------|-----------------|
| `unknown object type` or unhandled type in switch | `internal/servers/generic_server.go` — `setPayload()` switch statement |
| Public API missing field (Create/Update not persisting a field) | `internal/servers/*_server.go` — `Create()` and `Update()` methods |
| Table rendering missing or incorrect column | `internal/rendering/tables/*.yaml` — table definition files |

## OpenShift Deployment

The Kustomize `manifests/` directory was removed from `fulfillment-service` — Helm is
now the only supported deployment method, and installation requires cert-manager, a
PostgreSQL operator, and Keycloak to be set up first. See
[`osac/fulfillment-service/docs/INSTALL.md`](osac/fulfillment-service/docs/INSTALL.md)
for the full OpenShift installation guide (that guide's first step is enabling HTTP/2,
shown below).

```bash
oc annotate ingresses.config.openshift.io cluster ingress.operator.openshift.io/default-enable-http2=true
```

Once deployed, verify with the `osac` CLI (see INSTALL.md's "Verify the installation" for the full
sequence, including extracting the CA bundle):

```bash
export token=$(kubectl create token -n osac client)
export route=$(kubectl get route -n osac fulfillment-api -o json | jq -r '.spec.host')
grpcurl -insecure -H "Authorization: Bearer ${token}" ${route}:443 fulfillment.v1.VirtualNetworks/List
```

## Reference Documentation

| Location | Content |
|----------|---------|
| `.planning/codebase/ARCHITECTURE.md` | System design and layers |
| `.planning/codebase/CONVENTIONS.md` | Naming and coding patterns |
| `.planning/codebase/STACK.md` | Technology stack |
| `.planning/codebase/TESTING.md` | Test patterns and frameworks |
| `.planning/codebase/STRUCTURE.md` | File organization |
| [`docs/architecture/`](https://github.com/osac-project/docs/tree/main/architecture) | High-level diagrams and design documents |
| [`enhancement-proposals/`](https://github.com/osac-project/enhancement-proposals) | RFCs and design proposals |

## Workspace Layout

```text
bootstrap.sh              # Clone/update all component repos
Makefile                   # Distrobox dev environment targets
Containerfile              # Dev container image (Fedora 42 + all tools)
AGENTS.md                  # Tool-agnostic project conventions (this file)
CLAUDE.md                  # Claude Code project instructions
.claude/settings.json      # Pre-approved shell commands
.claude/rules/             # Architecture, protobuf, cross-repo conventions
.claude/hooks/             # Workflow hooks
.design/templates/         # PRD and design template overrides
.design/context/           # Feature dimensions and review patterns
skills/                    # AI skills (PRD/design workflows, Jira, bug fix, demo recording)
tools/pr-notify/           # PR dashboard generator
docs/pr-dashboard/         # Static site for PR dashboard (GitHub Pages)
.github/workflows/         # CI (pr-dashboard.yml)
```
