#!/bin/bash
set -euo pipefail

GITHUB_ORG="osac-project"
NO_FORK=false
FORK_REMOTE_NAME="fork"

declare -A FORK_OVERRIDES=()
if [[ -f "$(dirname "$0")/fork-overrides.sh" ]]; then
  source "$(dirname "$0")/fork-overrides.sh"
fi

usage() {
  cat <<'EOF'
Usage: ./bootstrap.sh [--no-fork] [--fork-name NAME]

Sets up the OSAC workspace by cloning all component repos.

By default, each repo is forked to your GitHub account and cloned with:
  origin     = osac-project/<repo>  (upstream source, PR target)
  <fork-name> = <your-username>/<repo>  (push target for feature branches)

Options:
  --no-fork          Clone directly from osac-project without forking.
                     Useful for read-only access or CI environments.
  --fork-name NAME   Name for the push remote (default: fork).
                     Use any name you prefer — the vendored osac-ai-skills
                     resolve-remotes.sh detects remotes by URL, not by name.
  --help             Show this help message.

Prerequisites:
  - gh CLI installed and authenticated (gh auth login)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-fork) NO_FORK=true; shift ;;
    --fork-name)
      [[ -n "${2:-}" ]] || { echo "Error: --fork-name requires a value"; usage; exit 1; }
      FORK_REMOTE_NAME="$2"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

# Verify gh CLI for fork workflow
if [ "$NO_FORK" = false ]; then
  if ! command -v gh &>/dev/null; then
    echo "❌ Error: gh CLI is not installed."
    echo "Install it (https://cli.github.com/) or use --no-fork for read-only clone."
    exit 1
  fi
  if ! gh auth status &>/dev/null; then
    echo "❌ Error: gh CLI is not authenticated."
    echo "Run 'gh auth login' or use --no-fork for read-only clone."
    exit 1
  fi
  GH_USER=$(gh api user -q .login)
  GIT_PROTOCOL=$(gh config get git_protocol 2>/dev/null || echo "https")
  echo "🚀 Setting up OSAC workspace for GitHub user: $GH_USER"
else
  echo "🚀 Setting up OSAC workspace (read-only, no forks)..."
fi

get_fork_url() {
  local repo="$1"
  local fork_repo="${FORK_OVERRIDES[$repo]:-$repo}"
  if [ "$GIT_PROTOCOL" = "ssh" ]; then
    echo "git@github.com:${GH_USER}/${fork_repo}.git"
  else
    echo "https://github.com/${GH_USER}/${fork_repo}.git"
  fi
}

ensure_fork_remote() {
  local repo="$1"
  # Ensure fork exists on GitHub, then verify it
  if ! gh repo fork "${GITHUB_ORG}/${repo}" --clone=false 2>/dev/null; then
    if ! gh repo view "${GH_USER}/${repo}" &>/dev/null; then
      echo "❌ Failed to fork ${GITHUB_ORG}/${repo}. Skipping fork remote."
      return 1
    fi
  fi
  local url
  url=$(get_fork_url "$repo")
  git -C "$repo" remote add fork "$url"
  git -C "$repo" fetch fork
}

REPOS=(
  "osac"
  "osac-test-infra"
  "enhancement-proposals"
  "docs"
)

for repo in "${REPOS[@]}"; do
  if [ -d "$repo" ]; then
    echo "📦 Updating $repo..."
    (cd "$repo" && git fetch origin && git rebase origin/main --autostash)
    # Add fork remote to existing repos that don't have one yet
    # (e.g., previously cloned with --no-fork)
    if [ "$NO_FORK" = false ] && ! git -C "$repo" remote get-url fork &>/dev/null; then
      echo "🍴 Adding fork remote for existing repo $repo..."
      ensure_fork_remote "$repo" || true
    fi
  else
    echo "📥 Cloning $repo..."
    git clone "https://github.com/${GITHUB_ORG}/${repo}.git"

    if [ "$NO_FORK" = false ]; then
      echo "🍴 Adding fork remote for $repo..."
      ensure_fork_remote "$repo" || true
    fi
  fi
done

# Install ai-workflows (bugfix, implement, etc.)
AI_WORKFLOWS_REPO="flightctl/ai-workflows"
AI_WORKFLOWS_DIR=""
# Prefer existing ~/.ai-workflows if present; otherwise clone locally
if [ -d "${HOME}/.ai-workflows" ]; then
  AI_WORKFLOWS_DIR="$(readlink -f "${HOME}/.ai-workflows")"
  echo "📦 Updating ai-workflows (${AI_WORKFLOWS_DIR})..."
  (cd "$AI_WORKFLOWS_DIR" && git fetch origin && git rebase origin/main --autostash)
elif [ -d ".ai-workflows" ]; then
  AI_WORKFLOWS_DIR="$(pwd)/.ai-workflows"
  echo "📦 Updating ai-workflows (.ai-workflows)..."
  (cd "$AI_WORKFLOWS_DIR" && git fetch origin && git rebase origin/main --autostash)
else
  AI_WORKFLOWS_DIR="$(pwd)/.ai-workflows"
  echo "📥 Cloning ai-workflows..."
  git clone "https://github.com/${AI_WORKFLOWS_REPO}.git" ".ai-workflows"
fi
# Must run before ai-workflows' install.sh: on a from-scratch clone, nothing
# under .claude/, .cursor/, or .gemini/ exists yet, so link-agent-skills.sh
# can freely create the .claude/skills -> ../skills (etc.) umbrella symlinks.
# install.sh's own `mkdir -p "<agent>/skills"` + targeted `ln -sfn .../<wf>`
# calls are non-destructive against an existing directory symlink -- they
# follow it and land each ai-workflows entry inside the shared skills/ tree.
# Reversing this order breaks a from-scratch bootstrap: install.sh would
# create .claude/skills (etc.) as a real directory first, and safe_symlink
# refuses to replace a real directory with a symlink.
#
# Export the vendor dir this script just resolved/updated/cloned above so the
# wrapper uses that exact directory instead of independently re-resolving one
# -- the wrapper's own resolve_osac_ai_skills_dir() has no way to know this
# script already rejected a stale/invalid ~/.osac-ai-skills or .osac-ai-skills
# in favor of the other, and could otherwise silently link skills from a
# different vendor than the one just fetched/rebased/cloned.
echo "🔗 Linking agent skill directories to skills/..."
OSAC_AI_SKILLS_VENDOR_DIR="${OSAC_AI_SKILLS_DIR}" tools/link-agent-skills.sh --all
echo "🔧 Installing ai-workflows skills..."
"$AI_WORKFLOWS_DIR/install.sh" claude --project . --workflows bugfix,implement
"$AI_WORKFLOWS_DIR/install.sh" cursor --project . --workflows bugfix,implement

echo ""
echo "✅ Workspace ready! All repos are on their latest main branch."
echo ""
echo "📂 Available repos:"
for repo in "${REPOS[@]}"; do
  if [ -d "$repo" ]; then
    branch=$(git -C "$repo" branch --show-current 2>/dev/null || echo "unknown")
    origin_url=$(git -C "$repo" remote get-url origin 2>/dev/null || echo "not set")
    fork_url=$(git -C "$repo" remote get-url fork 2>/dev/null || echo "not set")
    echo "   $repo (branch: $branch)"
    echo "     origin: $origin_url"
    if [ "$fork_url" != "not set" ]; then
      echo "     $FORK_REMOTE_NAME: $fork_url"
    fi
  fi
done

if [ "$NO_FORK" = true ]; then
  echo ""
  echo "💡 Cloned in read-only mode. To contribute, re-run without --no-fork"
  echo "   or add your fork manually:"
  echo "   cd <repo> && git remote add <name> \$(gh config get git_protocol | grep -q ssh && echo git@github.com: || echo https://github.com/)\$(gh api user -q .login)/<repo>.git"
fi
