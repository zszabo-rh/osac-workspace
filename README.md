# OSAC Project

Development workspace for the Open Sovereign AI Cloud (OSAC) project. This repo provides a meta-workspace that bootstraps all OSAC components for cross-component development and testing, with [Claude Code](https://docs.anthropic.com/en/docs/claude-code) and [GSD workflow](https://github.com/cyanheads/gsd) integration pre-configured.

## Prerequisites

- **git**
- **[gh CLI](https://cli.github.com/)**: Install and authenticate with `gh auth login` (required for fork workflow; use `--no-fork` if you only need read-only access)

## Getting Started

```bash
# Clone the workspace
git clone https://github.com/osac-project/osac-workspace.git
cd osac-workspace

# Bootstrap all component repos with fork setup (requires gh CLI)
./bootstrap.sh

# Or clone read-only without forking
./bootstrap.sh --no-fork
```

The bootstrap script clones all OSAC repos into the workspace. Each repo is an independent Git repository on its `main` branch. By default, remotes are named `origin` (upstream) and `fork` (push target). Use `--fork-name <name>` to choose a different push remote name (e.g., `--fork-name origin` for the conventional layout where `origin` is your fork and `upstream` is the project repo).

`resolve-remotes.sh` (vendored via `osac-ai-skills`, at `~/.osac-ai-skills` or `./.osac-ai-skills`) detects remotes by URL, so all skills and hooks work regardless of naming.

Use `--no-fork` if you only need read-only access or are running in CI. To override fork repo names (e.g., if your fork of `docs` is named `osac-docs`), copy `fork-overrides.sh.example` to `fork-overrides.sh` and edit it.

## Components

| Component | Description |
|-----------|-------------|
| [osac](https://github.com/osac-project/osac) | Mono-repo: fulfillment-service + osac-operator + osac-aap + osac-installer + bare-metal-fulfillment-operator + osac-csi-driver (see subdirectories below) |
| `osac/fulfillment-service` | gRPC/REST API server with PostgreSQL backend — manages VirtualNetworks, Subnets, SecurityGroups, ComputeInstances |
| `osac/osac-operator` | Kubernetes operator for deploying OpenShift clusters via Hosted Control Planes |
| `osac/osac-aap` | Ansible Automation Platform roles and playbooks for VM and network provisioning |
| `osac/osac-installer` | Installation manifests, prerequisites, and demo scripts |
| `osac/bare-metal-fulfillment-operator` | Kubernetes operator for bare metal fulfillment |
| `osac/osac-csi-driver` | CSI storage driver, routes to vendor backends via fulfillment-service storage tiers |
| [osac-test-infra](https://github.com/osac-project/osac-test-infra) | Integration testing infrastructure |
| [enhancement-proposals](https://github.com/osac-project/enhancement-proposals) | Design documents and enhancement proposals |
| [docs](https://github.com/osac-project/docs) | Architecture documentation, diagrams, and design guides |

## What's Included

This workspace provides a pre-configured AI-assisted development environment:

| File | Purpose |
|------|---------|
| `bootstrap.sh` | Clones or updates all component repos to latest `main` — re-run anytime to sync |
| `CLAUDE.md` | Project instructions Claude Code reads automatically — build commands, architecture patterns, conventions |
| `.claude/settings.json` | Pre-approved shell commands (git, ls, cat, etc.) so Claude doesn't prompt for routine operations |
| `.planning/config.json` | GSD workflow configuration (parallelization, verification, auto-advance) |
| `skills/` | AI skills for Claude Code — EP generation, Jira management, bug fix workflows, demo recording |
| `.gitignore` | Ignores cloned repos, `.planning/`, `.claude/`, credentials, editor files, and build artifacts |

## Setup

After running `./bootstrap.sh` to clone all repos:

1. **kubeconfig**: Place your cluster kubeconfig at `./kubeconfig` (gitignored)
2. **Tools**: `buf`, `grpcurl`, `kubectl`, `jq`, [`rg`](https://github.com/BurntSushi/ripgrep)
3. **Jira CLI**: `go install github.com/ankitpokhrel/jira-cli/cmd/jira@latest` (or `brew install ankitpokhrel/jira-cli/jira-cli`)
4. **GSD workflow**: `npx get-shit-done-cc@latest` (run from workspace root)
   - GSD hooks in `.claude/settings.json` are already configured and will no-op if GSD is not installed

To update all repos to latest `main` at any time, simply re-run:
```bash
./bootstrap.sh
```

## Quick Reference

```bash
# Build and test fulfillment-service
cd osac/fulfillment-service
go build ./...
ginkgo run -r internal

# Test API against a running cluster
export KUBECONFIG=./kubeconfig
export NAMESPACE=<your-namespace>
ROUTE=$(kubectl get route -n $NAMESPACE fulfillment-api -o jsonpath='{.spec.host}')
TOKEN=$(kubectl create token -n $NAMESPACE admin)

# List resources via REST
curl -sk -H "Authorization: Bearer $TOKEN" "https://$ROUTE/api/fulfillment/v1/virtual_networks" | jq
curl -sk -H "Authorization: Bearer $TOKEN" "https://$ROUTE/api/fulfillment/v1/subnets" | jq
curl -sk -H "Authorization: Bearer $TOKEN" "https://$ROUTE/api/fulfillment/v1/compute_instances" | jq

# List resources via gRPC
grpcurl -insecure -H "Authorization: Bearer $TOKEN" $ROUTE:443 osac.public.v1.VirtualNetworks/List
```

## GSD Workflow

Once you have Claude Code running in this workspace, use GSD commands to plan and execute work:

```
/gsd:new-project     # Initialize project with requirements gathering
/gsd:plan-phase      # Plan the next phase of work
/gsd:execute-phase   # Execute a planned phase
/gsd:progress        # Check current project status
/gsd:next            # Advance to the next logical step
```

| Task Type | GSD Command | When to Use |
|-----------|-------------|-------------|
| Epic / new feature | `/gsd:new-project` | Starting a multi-phase initiative |
| Jira ticket | `/gsd:quick` | Single-ticket work with commit tracking |
| Tiny fix | `/gsd:fast` | One-file fixes, no planning overhead |
| Check status | `/gsd:progress` | See where you are in the project |
| Next step | `/gsd:next` | Auto-advance to the next logical action |

GSD manages all state under `.planning/` — milestones, phases, plans, and verification are created as you work.

## Enhancement Proposals

This workspace includes skills for drafting and submitting OSAC Enhancement Proposals with Claude Code.

**Create an EP from requirements or meeting notes:**

```
/ep.create
```

Provide rough requirements, meeting notes, or a Jira ticket (e.g., `OSAC-XXXXX`) and the skill will:

1. Explore the OSAC codebase and existing proposals for context
2. Ask clarifying questions before drafting
3. Generate a template-compliant EP under `enhancement-proposals/enhancements/<feature-slug>/README.md`
4. Submit a PR to [osac-project/enhancement-proposals](https://github.com/osac-project/enhancement-proposals) on approval
5. Iterate on reviewer feedback

**Convert an approved EP into Jira work items:**

```
/ep.to-jira
```

This creates a Jira epic with ordered sub-tasks (proto, backend, controller, tests, docs) and a complexity assessment.

**Prerequisites:** `gh` (authenticated), `jira` CLI, `rg`

## Architecture

```
NetworkClass (platform-defined)
  └── VirtualNetwork (tenant L2 network with CIDR)
        ├── Subnet (CIDR range within VirtualNetwork)
        └── SecurityGroup (firewall rules)
              └── ComputeInstance (KubeVirt VM, attached to Subnet + SecurityGroups)
```

See `CLAUDE.md` for detailed development instructions and conventions.
