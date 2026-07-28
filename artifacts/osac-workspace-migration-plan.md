# Migration Plan: claude-workspace-osac → osac-workspace

## Context

The OSAC team is standardizing on `osac-project/osac-workspace` as the shared development workspace. You currently use a custom `claude-workspace-osac` with 15+ months of accumulated artifacts, skills, rules, memories, and active feature branches. The goal is to migrate to the team standard without losing any work, while keeping both workspaces running during an interim period.

---

## 1. Detailed Comparison

### Structure

| Aspect | Your custom workspace | Team osac-workspace |
|--------|----------------------|---------------------|
| **Component repos** | 9 git submodules (`.gitmodules`) | 7 repos cloned by `bootstrap.sh` (not submodules) |
| **Extra repos** | `github-config`, `osac-ui` (rarely used) | Not included |
| **Remote naming** | `origin` = fork, `upstream` = osac-project | `origin` = osac-project, `fork` = personal fork |
| **CLAUDE.md** | 89 lines (lean index, Tier 1 optimized) | 126 lines (includes GSD workflow, operator architecture, quick reference) |
| **`.claude/rules/`** | 7 files (395 lines) — component dev guides | 4 files (224 lines) — protobuf, cross-repo, architecture, GSD-Jira |
| **`.claude/settings.json`** | 36 lines — gofmt hook + basic permissions | 112 lines — GSD hooks (9 hooks) + basic permissions |
| **`.planning/codebase/`** | 7 files (generated) | 7 files (1948 lines, maintained) |
| **Artifacts** | 70+ files (2.2M) — training, meetings, architecture, PRs | None (artifacts are personal) |
| **THREAT_MODEL.md** | 76 lines (template) | None |

### Skills & Workflows

| Aspect | Your custom workspace | Team osac-workspace |
|--------|----------------------|---------------------|
| **Skills location** | Global (`~/.claude/skills/`) | Workspace-local (`skills/` symlinked to `.claude/skills/`) |
| **OSAC skills count** | 0 workspace-level, 14 global | 12 workspace-level skills |
| **Overlap** | — | — |
| **fix-bug** | Global `/bugfix` (6-phase, generic) | Workspace `fix-bug` (Jira-integrated, OSAC-specific) |
| **EP workflows** | None | `ep-create`, `ep-review`, `ep-to-jira` (3 skills) |
| **Jira management** | Global `/triage` | `jira-task-management`, `capture-tasks-from-meeting-notes`, `generate-status-report` |
| **PR creation** | None specific | `create-pr` (fork-based, repo-specific validation) |
| **Bug reporting** | None | `report-bug`, `osac-feature` |
| **Demo recording** | None | `osac-demo-recording` |
| **Commands** | None workspace-level | 13 slash commands (`/fix-bug`, `/ep.create`, `/jira.md`, etc.) |
| **Agents** | None workspace-level | 1 (`fix-bug.md` agent) |
| **GSD workflow** | None | Full GSD integration (10 hooks, state tracking, Jira mapping) |

### What you have that osac-workspace doesn't

| Asset | Description | Action |
|-------|-------------|--------|
| **artifacts/** (2.2M, 70+ files) | Training guides, meeting transcripts, architecture docs, PR reviews, dev diary | Move to new workspace or keep in a separate archive |
| **THREAT_MODEL.md** | Structured 8-section security template | Propose upstream or keep in fork |
| **7 component dev rules** | fulfillment-dev.md, osac-operator-dev.md, etc. | Merge with osac-workspace's 4 rules (different content, complementary) |
| **settings.local.json** (312 lines) | 230+ Bash permissions, Jira/Slack MCP access | Recreate in new workspace (personal, not shared) |
| **gofmt PostToolUse hook** | Auto-format Go files after edits | Propose upstream or add to fork |
| **Global skills** | `/implement`, `/bugfix`, `/self-review-gate`, `/coffee-update`, etc. | Stay global — work in any workspace |

### What osac-workspace has that you don't

| Asset | Description | Value |
|-------|-------------|-------|
| **GSD workflow** | 10 hooks for phase-based work with Jira state mapping | High — structured lifecycle management |
| **EP workflows** | 3 skills for enhancement proposals | High — team standard for proposals |
| **13 slash commands** | `/fix-bug`, `/ep.create`, `/jira.md`, `/report-bug`, etc. | High — team conventions |
| **bootstrap.sh** | One-command workspace setup with fork detection | Medium — replaces manual submodule setup |
| **Cross-repo workflow rules** | Git worktree strategy, DCO signing, AI attribution | Medium — team conventions |
| **Protobuf conventions rule** | Proto naming, API structure patterns | Medium — team standard |

---

## 2. Customization Strategy for the Fork

The osac-workspace `.gitignore` is designed for personal customization:

**Tracked (shared with team):**
- `.claude/hooks/`, `.claude/settings.json`, `.claude/rules/`, `.claude/skills` (symlink), `.claude/commands/`, `.claude/agents/`, `.claude/workflows/`
- `skills/`, `CLAUDE.md`, `bootstrap.sh`, `.planning/codebase/`

**Not tracked (personal):**
- `.claude/settings.local.json` — your personal permissions
- `.planning/config.json` — your GSD state and Jira mapping
- `.planning/STATE.md` — your current phase
- All cloned component repos (`fulfillment-service/`, etc.)
- `kubeconfig`, `.env*`, credentials
- `artifacts/` — NOT in gitignore, so this needs attention

**Recommended fork workflow:**

```
upstream (osac-project/osac-workspace)
    ↓ git pull --rebase
your fork (zszabo-rh/osac-workspace) — main branch tracks upstream
    ↓ git checkout -b personal/customizations
personal/customizations branch — your additions:
    - artifacts/ directory
    - THREAT_MODEL.md
    - Additional .claude/rules/ files
    - Any custom skills not pushed upstream
```

**But simpler approach:** Since `.claude/settings.local.json` is gitignored and component repos are gitignored, most personal state is automatically excluded. The main items that need your fork branch are:

1. **artifacts/** — Add to your fork or move to a separate repo
2. **Extra rules** — Contribute upstream or keep in fork branch
3. **Extra component repos** (github-config, osac-ui) — Clone manually alongside bootstrap'd repos

---

## 3. Migration Steps

### Phase 0: Preparation (before anything changes)

1. **Backup everything:**
   ```bash
   # Run a manual backup
   ~/projects/claude-backup/backup.sh
   # Also snapshot the workspace
   ~/projects/claude-backup/workspace-backup.sh
   ```

2. **Document active feature branches:**
   - `fulfillment-service`: `OSAC-748-console-authconfig-fix` + 6 others
   - `osac-aap`: `feature/mgmt-23826-tenant-storage-provision` + 6 others
   - `osac-operator`: `feature/mgmt-23828-tenant-storage-provisioning` + 5 others
   - `osac-installer`: `MGMT-23998-console-rbac` + 7 others
   - These live in your GitHub forks — they're safe regardless of workspace changes

3. **Ensure your fork of osac-workspace is up-to-date:**
   ```bash
   cd /tmp/osac-workspace  # or wherever the clone is
   git fetch origin  # origin = your fork
   git fetch upstream  # add upstream if not set
   git rebase upstream/main
   git push origin main
   ```

### Phase 1: Set up the new workspace (keep old one running)

1. **Clone your fork to projects:**
   ```bash
   cd ~/projects
   git clone git@github.com:zszabo-rh/osac-workspace.git
   cd osac-workspace
   git remote add upstream https://github.com/osac-project/osac-workspace.git
   ```

2. **Run bootstrap to clone component repos:**
   ```bash
   ./bootstrap.sh
   ```
   This clones all 7 repos with fork-based remotes. Note: remote naming is different from your current workspace (`origin` = upstream, `fork` = your fork).

3. **Restore feature branches** in component repos:
   ```bash
   cd fulfillment-service
   git fetch fork
   git checkout OSAC-748-console-authconfig-fix  # etc.
   cd ..
   ```
   Repeat for each component with active branches. The branches exist in your forks, so `git fetch fork && git checkout <branch>` restores them.

5. **Create `.claude/settings.local.json`** — Port your personal permissions:
   - Copy from old workspace: `cp ~/projects/claude-workspace-osac/.claude/settings.local.json ~/projects/osac-workspace/.claude/settings.local.json`
   - Review and update any hardcoded paths from `claude-workspace-osac` to `osac-workspace`

### Phase 2: Migrate assets

1. **Copy artifacts:**
   ```bash
   cp -r ~/projects/claude-workspace-osac/artifacts ~/projects/osac-workspace/
   ```
   Add `artifacts/` to your fork if you want it versioned, or add to `.gitignore` to keep it local.

2. **Copy THREAT_MODEL.md:**
   ```bash
   cp ~/projects/claude-workspace-osac/THREAT_MODEL.md ~/projects/osac-workspace/
   ```

3. **Merge rules** — Compare and decide per file:

   | Your rule | osac-workspace equivalent | Action |
   |-----------|--------------------------|--------|
   | `fulfillment-dev.md` (110 lines) | None | Copy to fork — contains detailed dev commands |
   | `osac-operator-dev.md` (53 lines) | `architecture-patterns.md` (65 lines) | Compare content — may be complementary |
   | `osac-aap-dev.md` (42 lines) | None | Copy to fork |
   | `osac-installer-dev.md` (57 lines) | None | Copy to fork |
   | `osac-testing.md` (54 lines) | None | Copy to fork |
   | `osac-ui-dev.md` (30 lines) | None | Copy to fork |
   | `moc-hypershift1.md` (49 lines) | None | Copy to fork — propose upstream later |
   | None | `protobuf-conventions.md` (54 lines) | Already in team workspace |
   | None | `cross-repo-workflow.md` (59 lines) | Already in team workspace |
   | None | `gsd-jira-integration.md` (46 lines) | Already in team workspace |

4. **Copy tools/ if present:**
   ```bash
   cp -r ~/projects/claude-workspace-osac/tools ~/projects/osac-workspace/
   ```

### Phase 3: Verify the new workspace

1. Start a Claude Code session in `~/projects/osac-workspace/`
2. Run `/context` — verify CLAUDE.md and rules load correctly
3. Test a skill: `/fix-bug` or `/ep.create` — verify team skills work
4. Test your globals: `/implement`, `/self-review-gate` — verify global skills work
5. Check that component repos have correct remotes: `cd fulfillment-service && git remote -v`
6. Verify GSD hooks are active (statusline should show GSD state)

### Phase 4: Update backup system

Edit `/home/zszabo/projects/claude-backup/workspace-backup.sh`:
```bash
WORKSPACES=(
    "$HOME/projects/osac-workspace"           # NEW: team standard
    "$HOME/projects/claude-workspace-osac"     # KEEP during interim
    "$HOME/projects/claude-workspace-assisted"
    "$HOME/projects/claude-workspace-personal"
)
```

### Phase 5: Interim period (2-4 weeks)

- **Use osac-workspace** for all new work
- **Keep claude-workspace-osac** for reference and any in-progress work that's hard to transfer
- **Don't start new feature branches** in the old workspace
- After all active branches are merged or transferred, archive the old workspace:
  ```bash
  mv ~/projects/claude-workspace-osac ~/projects/archive/claude-workspace-osac
  ```
- Remove from backup list

### Phase 6: Contribute upstream (optional, ongoing)

Items worth proposing to `osac-project/osac-workspace`:
- Your 7 component dev rules (after team review)
- `THREAT_MODEL.md` template
- `gofmt` PostToolUse hook
- Any improvements from your Tier 1-3 work that the team would benefit from

---

## 4. Skill Portability Summary

| Skill | Location | Workspace-specific? | Action |
|-------|----------|---------------------|--------|
| `/implement` | Global | No | Works in any workspace |
| `/bugfix` | Global | No | Works in any workspace (overlaps with osac-workspace's `/fix-bug`) |
| `/self-review-gate` | Global | No | Works in any workspace |
| `/ralph` | Global | No | Works in any workspace |
| `/triage` | Global | No | Works in any workspace |
| `/review-pr` | Global | No | Works in any workspace |
| `/coffee-update` | Global | No | Works in any workspace |
| `/retro` | Global | No | Works in any workspace |
| `/teach-me` | Global | No | Works in any workspace |
| `/generate-codebase-docs` | Global | No | Works in any workspace |
| `/handover` | Global | OSAC/Assisted-specific | Works from any workspace |
| `/beaker` | Global | Assisted-specific | Works from any workspace |
| `/storage-update` | Global | OSAC-specific | Works from any workspace |
| `/word-of-the-day` | Global | No | Works in any workspace |

**Key insight:** All your skills are global. None are workspace-local. They will all work in the new workspace without any changes.

---

## 5. Named Sessions & Memory Migration

### Named Sessions

Session metadata is stored at `~/.claude/sessions/<pid>.json` with `cwd` field referencing the workspace path. Your active OSAC sessions:

| Session | CWD | Status |
|---------|-----|--------|
| "OSAC Storage provisioning (new)" | `~/projects/claude-workspace-osac` | idle |
| "OSAC Morning update" | `~/projects/claude-workspace-osac` | idle |

**Can you resume old sessions from the new workspace?**

Yes — `claude --resume <session-id>` works regardless of CWD. You can resume a session started in `claude-workspace-osac` while your terminal is in `osac-workspace`. The session transcript references the original CWD, but Claude will use whatever files exist at that path.

**However:** If the old workspace is archived/removed, file references in the session context will be stale (pointing to `~/projects/claude-workspace-osac/fulfillment-service/...` which no longer exists). The session will work but Claude won't be able to read/edit files at those old paths.

**Recommended approach for active named sessions:**

1. **During interim period:** Continue resuming old sessions from the old workspace directory. Start new sessions from the new workspace.
2. **When ready to archive old workspace:** Create a symlink so old paths still resolve:
   ```bash
   ln -s ~/projects/osac-workspace ~/projects/claude-workspace-osac
   ```
   This makes both paths point to the same directory. Old session file references keep working.
3. **For truly important sessions** (like "OSAC Storage provisioning"): Start a new session in the new workspace, use `/compact` to summarize your prior work, and reference the topic. The OSAC storage architecture context is already captured in artifacts and memory — a new session will pick it up naturally.

### Memory

Claude Code stores memories by workspace path (`~/.claude/projects/-home-zszabo-projects-claude-workspace-osac/memory/`). When you start working in `~/projects/osac-workspace/`, a **new** memory directory will be created at `~/.claude/projects/-home-zszabo-projects-osac-workspace/memory/`.

**Recommended:** Copy the most valuable memory files to the new path:
```bash
mkdir -p ~/.claude/projects/-home-zszabo-projects-osac-workspace/memory/
cp ~/.claude/projects/-home-zszabo-projects-claude-workspace-osac/memory/osac-architecture.md \
   ~/.claude/projects/-home-zszabo-projects-claude-workspace-osac/memory/osac-coding-patterns.md \
   ~/.claude/projects/-home-zszabo-projects-osac-workspace/memory/
```
Then create a new `MEMORY.md` in the new path, referencing the copied files. Other memories (session-specific notes, completed task details) can be left behind — they'll age out naturally.

---

## 6. Risk Mitigation

| Risk | Mitigation |
|------|-----------|
| Lose active feature branches | Branches are in GitHub forks — `git fetch fork` restores them |
| Lose artifacts | Copy before migration, verify after |
| Lose permissions | Copy `settings.local.json`, update paths |
| GSD hooks conflict with your global hooks | Your global hooks (statusline, context-monitor, cost-tracker) are in `~/.claude/settings.json`. osac-workspace hooks are in `.claude/settings.json` (project-level). **Project-level hooks run in addition to global hooks** — they don't replace them. Verify no conflicts. |
| Remote naming confusion | Old: `origin`=fork, `upstream`=osac-project. New: `origin`=osac-project, `fork`=your-fork. Document this clearly. |
| Old workspace falls out of sync | Don't use it for new work during interim. Archive after 2-4 weeks. |

---

## 7. Artifact Cleanup (during migration)

### Keep (current):
- `dev-diary.md`, `osac-storage-architecture-overview.md`
- `training-osac-storage-*.md`, `training-k8s-storage-for-osac-caas.md`
- `osac-roadmap-2026.md`, `demo-org-storage-provisioning.md`, `demo-monitor.sh`
- `reviews/*.md` (6 files)
- `provisioning-workflow.md`, `troubleshooting.md`, `ci-cd.md`, `templates-system.md`
- `Storage API Flow Reference.txt`
- `quota-feature-project-plan.md`, `quota-presentation.html`, `quota-presentation.md`, `quota-proposal-review-findings.txt` (quota feature continuing)

### Archive (move to `artifacts/archive/`):
- `MGMT-22670-*` (3 files — completed serial console feature)
- `mgmt-23329-pr-descriptions.md`
- `DRAFT_ OSAC metering.md`
- `poc3-demo-v3.txt`
- `OSAC VMaaS Demo March 2026.pdf`

### Delete:
- `OSAC_install_V2.txt` (superseded)
- `BEAKER_INSTALLATION_GUIDE.md` (Assisted-specific, not OSAC)

### Review before deleting:
- `OSAC_Developer_Onboarding_Guide.docx` — check if superseded by training guides
- `osac-training-guide.md` / `onboarding-training.md` — check for overlap with newer training docs

### Meeting transcripts:
- Replace `meeting_transcripts/` (29 files, 930K) with a single `meeting_transcripts/processed-meetings.md` log file tracking:
  - Meeting name, date, whether notes were processed, key action items extracted
- Delete all raw transcript files (they can be re-fetched from Google Meet/Gemini)

---

## Verification Checklist

- [ ] New workspace cloned and bootstrap'd at `~/projects/osac-workspace/`
- [ ] All 7+ component repos present with correct remotes
- [ ] Active feature branches restored in component repos
- [ ] `artifacts/` copied and accessible
- [ ] `THREAT_MODEL.md` copied
- [ ] Component dev rules merged into `.claude/rules/`
- [ ] `.claude/settings.local.json` created with personal permissions
- [ ] `/context` shows reasonable initial context
- [ ] Team skills work (`/fix-bug`, `/ep.create`)
- [ ] Global skills work (`/implement`, `/self-review-gate`)
- [ ] GSD hooks active (statusline shows state)
- [ ] Backup system updated to include new workspace
- [ ] Old workspace marked as read-only / archive candidate
