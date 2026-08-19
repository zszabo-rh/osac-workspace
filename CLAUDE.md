# CLAUDE.md

## Project Context

OSAC (Open Sovereign AI Cloud) is a fulfillment system for provisioning Kubernetes clusters and compute instances with networking capabilities. Primary languages: Go, YAML, Python. Primary tools: kubectl, jira CLI, gh CLI.

## Critical Rules

- **`osac-workspace/` is the project root** — all work happens from here; component `CLAUDE.md` files are loaded via progressive disclosure
- **Read component CLAUDE.md first** before making changes in any component repo
- **Never skip tenant isolation metadata** (`osac.openshift.io/tenant`, `osac.io/owner-reference` annotations) in new resources
- **Always `buf lint` before committing** proto changes; regenerate with `buf generate`
- **Fork-based workflow**: always push to `fork` remote, never to `origin`. PRs go from `fork/<branch>` to `origin/main`
- When debugging Kubernetes operators, check for stale vendor directories and cached images before rebuilding

## Detailed docs (read on demand)
Full reference (repo map, deployment coordination, fix-location table, commands, operator architecture, workflows) is in `docs/CLAUDE-reference.md` — read it when you need it.

- Detailed rules: `.claude/rules/` (protobuf-conventions, cross-repo-workflow, architecture-patterns, gsd-jira-integration)
- Use `jira` CLI for Jira (not MCP). `/bugfix`, `/implement`, `/e2e` workflows available.
