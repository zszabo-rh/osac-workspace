# Review: osac-operator#213 — MGMT-24034: Add osac-console-proxy

## PR Info
- URL: https://github.com/osac-project/osac-operator/pull/213
- Jira: MGMT-24034 (parent: OSAC-20 dedicated VM clusters)
- Author: sk-ilya (Ilya Skornyakov)
- Created: 2026-05-03
- Base: main <- console-proxy
- Dependent: fulfillment-service#487 merges AFTER this

## Round 1 — 2026-05-06

### Context
- Commits reviewed: 8 commits
- Files changed: 51 (+2770 -136)
- CI status: ALL PASSING
- Other reviewers: Adrien Gentil (11 human comments, active), CodeRabbit (19 bot comments)

### Findings
| # | Severity | Category | File:Line | Finding | Status |
|---|----------|----------|-----------|---------|--------|
| 1 | Major | security | clusterrole-secret-reader.yaml | Cluster-wide Secret read — too broad for production (Adrien flagged) | OPEN |
| 2 | Major | completeness | apiservice.yaml | Namespace hardcoded to `osac` — installer overlay compatibility unclear | OPEN |
| 3 | Major | architecture | Containerfile | Both binaries in same image — works but adds unused binary to each deployment | OPEN |
| 4 | Minor | documentation | PR description | Auto-generated, lacks architecture summary for git history | OPEN |
| 5 | Minor | conventions | deployment.yaml:22 | imagePullPolicy inconsistency (Adrien flagged) | OPEN |
| 6 | Minor | conventions | .golangci.yml:24 | goconst.ignore-tests repo-wide lint relaxation | OPEN |
| 7 | Minor | documentation | CLAUDE.md | Should add one-line mention of console-proxy binary | OPEN |
| 8 | Minor | completeness | controller changes | 6 controllers have 1-line changes — verify intentional | OPEN |
| 9 | Nitpick | documentation | docs/vmaas-dedicated-cluster | Architecture doc placement (Adrien vs author disagree) | OPEN |

### Missing Dependency PRs
- osac-installer: overlay integration for console-proxy manifests (Adrien flagged)
- fulfillment-service#487: linked, correct merge order

### Recommendation
COMMENT ONLY — high quality code, comprehensive tests and docs. Address Adrien's unresolved comments.
