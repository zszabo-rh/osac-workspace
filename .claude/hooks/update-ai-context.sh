#!/usr/bin/env bash
# SessionStart hook: fetch+rebase osac-workspace (if on main) and ai-workflows
# so the AI agent always has the latest CLAUDE.md, rules, and skills.

# CLAUDE_PROJECT_DIR is the documented, invocation-independent way to locate
# the project root from a hook (https://code.claude.com/docs/en/hooks). Fall
# back to the old $0-relative derivation only if it's somehow unset.
WORKSPACE_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"

sync_repo() {
  local dir="$1" name="$2" upstream_remote="${3:-origin}" only_on_main="${4:-false}"
  [[ -d "$dir" ]] || return 0

  local branch
  branch="$(git -C "$dir" branch --show-current 2>/dev/null)" || return 0

  if [[ "$only_on_main" == "true" && "$branch" != "main" ]]; then
    git -C "$dir" fetch "$upstream_remote" -q 2>/dev/null || true
    local behind
    behind=$(git -C "$dir" rev-list "HEAD..${upstream_remote}/main" --count 2>/dev/null || echo "?")
    if [[ "$behind" == "0" ]]; then
      echo "$name: on '$branch', up to date with main"
    else
      echo "$name: on '$branch', $behind commits behind main — consider running: git merge ${upstream_remote}/main"
    fi
    return 0
  fi

  if ! git -C "$dir" fetch "$upstream_remote" -q 2>/dev/null; then
    echo "$name: fetch failed"
    return 0
  fi

  local head_before head_after
  head_before="$(git -C "$dir" rev-parse HEAD)"

  # Use merge (not rebase) so local artifact commits are never replayed —
  # they sit on top of the merge commit, no conflict possible.
  if git -C "$dir" merge "${upstream_remote}/main" --no-edit -X ours -q >/dev/null 2>&1; then
    head_after="$(git -C "$dir" rev-parse HEAD)"
    if [[ "$head_before" == "$head_after" ]]; then
      echo "$name: up to date"
    else
      echo "$name: updated"
    fi
  else
    git -C "$dir" merge --abort 2>/dev/null || true
    echo "$name: merge conflict, skipped"
  fi
}

sync_repo "$WORKSPACE_DIR" "osac-workspace" "upstream" true
sync_repo "${HOME}/.ai-workflows" "ai-workflows" "origin"
