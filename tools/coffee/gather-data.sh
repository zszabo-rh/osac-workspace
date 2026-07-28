#!/usr/bin/env bash
# gather-data.sh — coffee-update external data collection for OSAC workspace
# Runs ALL external queries in one shot and outputs structured labeled sections.
# AI reads this output once instead of issuing 10+ individual bash calls.
#
# Output sections (parse by looking for "=== SECTION ==="):
#   EMAIL_FETCH, TRANSCRIPT_STATUS, INBOX_SCAN, JIRA_TICKETS, GITHUB_PRS, GIT_ACTIVITY
#
# Usage: bash tools/coffee/gather-data.sh
set -o pipefail

WORKSPACE="$HOME/projects/osac-workspace"
TRANSCRIPTS="$WORKSPACE/artifacts/meeting_transcripts"
ORG="osac-project"
REPOS="fulfillment-service osac-operator osac-aap osac-installer osac-test-infra enhancement-proposals"
JIRA_PROJECT="OSAC"
NOW=$(date +%s)
TODAY=$(date +%Y-%m-%d)

# Day-of-week for inbox lookback (1=Mon needs 3d, others 1d)
DOW=$(date +%u)
INBOX_WINDOW=$([[ "$DOW" -eq 1 ]] && echo "3d" || echo "1d")

sep() { echo ""; echo "=== $1 ==="; }

# ── Email fetch + transcript inventory ─────────────────────────────────────────
sep "EMAIL_FETCH"
if command -v gws >/dev/null 2>&1; then
  echo "gws: available"

  # Gemini transcript emails (last 2 days)
  RAW_T=$(gws gmail +triage --max 10 \
    --query "from:gemini-notes@google.com subject:(OSAC OR innabox OR fulfillment) newer_than:2d" \
    --format json 2>/dev/null || echo '{"messages":[]}')
  COUNT_T=$(echo "$RAW_T" | jq '.messages | length' 2>/dev/null || echo 0)
  echo "gemini_found: $COUNT_T"

  if [[ "$COUNT_T" -gt 0 ]]; then
    while IFS=$'\t' read -r id subject; do
      safe=$(echo "$subject" | tr -cd '[:alnum:] .,_-' | xargs)
      fname="$TRANSCRIPTS/${safe}.txt"
      if [[ -f "$fname" ]]; then
        echo "exists: $(basename "$fname")"
      else
        if gws gmail +read --id "$id" --headers > "$fname" 2>/dev/null; then
          echo "saved: $(basename "$fname")"
        else
          echo "save_failed: $id"
          rm -f "$fname"
        fi
      fi
    done < <(echo "$RAW_T" | jq -r '.messages[] | "\(.id)\t\(.subject)"' 2>/dev/null)
  fi

  # Weekly report emails (last 7 days)
  RAW_W=$(gws gmail +triage --max 5 \
    --query "from:alkaplan@redhat.com subject:\"OSAC weekly report\" newer_than:7d" \
    --format json 2>/dev/null || echo '{"messages":[]}')
  COUNT_W=$(echo "$RAW_W" | jq '.messages | length' 2>/dev/null || echo 0)
  echo "weekly_found: $COUNT_W"

  if [[ "$COUNT_W" -gt 0 ]]; then
    while IFS=$'\t' read -r id subject; do
      safe=$(echo "$subject" | tr -cd '[:alnum:] .,_-' | xargs)
      fname="$TRANSCRIPTS/${safe}.eml"
      if [[ -f "$fname" ]]; then
        echo "exists: $(basename "$fname")"
      else
        if gws gmail +read --id "$id" --headers > "$fname" 2>/dev/null; then
          echo "saved: $(basename "$fname")"
        else
          echo "save_failed: $id"
          rm -f "$fname"
        fi
      fi
    done < <(echo "$RAW_W" | jq -r '.messages[] | "\(.id)\t\(.subject)"' 2>/dev/null)
  fi
else
  echo "gws: not_available"
fi

# ── Transcript staleness + unprocessed list ────────────────────────────────────
sep "TRANSCRIPT_STATUS"
NEWEST=$(ls -t "$TRANSCRIPTS" 2>/dev/null | head -1)
if [[ -n "$NEWEST" ]]; then
  MTIME=$(stat -c %Y "$TRANSCRIPTS/$NEWEST" 2>/dev/null || echo 0)
  AGE_H=$(( (NOW - MTIME) / 3600 ))
  echo "newest: $NEWEST"
  echo "age_hours: $AGE_H"
  [[ $AGE_H -gt 36 ]] && echo "WARNING: transcript folder is ${AGE_H}h old — possible missed meetings"
else
  echo "no_transcripts_yet"
fi

echo ""
echo "-- unprocessed --"
find "$TRANSCRIPTS" \( -name "*.txt" -o -name "*.eml" \) 2>/dev/null | sort | while IFS= read -r f; do
  if ! head -1 "$f" 2>/dev/null | grep -q "^\[PROCESSED"; then
    echo "$f"
  fi
done

# ── Inbox scan ──────────────────────────────────────────────────────────────────
sep "INBOX_SCAN"
if command -v gws >/dev/null 2>&1; then
  gws gmail +triage --max 50 --query "is:unread newer_than:${INBOX_WINDOW}" --format json 2>/dev/null \
    | jq -r '.messages[] | "[\(.from | split("<")[0] | ltrimstr(" ") | rtrimstr(" "))] \(.subject)"' 2>/dev/null \
    || echo "inbox_scan_failed"
else
  echo "gws: not_available"
fi

# ── Jira open tickets ──────────────────────────────────────────────────────────
sep "JIRA_TICKETS"
JIRA_LOGIN=$(grep '^login:' ~/.config/.jira/.config.yml 2>/dev/null | sed 's/login: //')
JIRA_TOKEN=$(grep '^token:' ~/.config/.jira/.config.yml 2>/dev/null | sed 's/token: //')
JIRA_SERVER=$(grep '^server:' ~/.config/.jira/.config.yml 2>/dev/null | sed 's/server: //')
echo "assignee: ${JIRA_LOGIN:-unknown}"
echo ""

_jira_search() {
  local status_jql="$1" max="${2:-10}"
  if [[ -z "$JIRA_TOKEN" ]]; then echo "jira_failed"; return; fi
  curl -s -u "${JIRA_LOGIN}:${JIRA_TOKEN}" \
    "${JIRA_SERVER}/rest/api/3/search/jql?jql=project%3D${JIRA_PROJECT}%20AND%20assignee%3DcurrentUser()%20AND%20${status_jql}%20ORDER%20BY%20updated%20DESC&maxResults=${max}&fields=summary,status,priority,updated" \
    | python3 -c "
import sys, json
d = json.load(sys.stdin)
issues = d.get('issues', [])
if not issues:
    print('(none)')
for i in issues:
    f = i['fields']
    upd = f.get('updated', '')[:10]
    pri = f.get('priority', {}).get('name', '?')
    print(f'{i[\"key\"]}\t{f[\"status\"][\"name\"]}\t{pri}\t{upd}\t{f[\"summary\"]}')
" 2>/dev/null || echo "jira_failed"
}

echo "-- in_progress --"
_jira_search "status%3D%22In%20Progress%22"
echo ""
echo "-- code_review --"
_jira_search "status%3D%22Code%20Review%22"
echo ""
echo "-- to_do (top 5) --"
_jira_search "status%3D%22To%20Do%22" 5

# ── GitHub PRs (list + reviews + inline comments per PR) ──────────────────────
sep "GITHUB_PRS"
BOT_FILTER='test("bot|coderabbitai|openshift-ci|dependabot"; "i")'

for repo in $REPOS; do
  PRS_JSON=$(gh pr list --repo "$ORG/$repo" --author @me --state open \
    --json number,title,reviewDecision,updatedAt,createdAt,statusCheckRollup 2>/dev/null)
  [[ "$PRS_JSON" == "[]" || -z "$PRS_JSON" ]] && continue

  echo ""
  echo "-- $repo --"
  # Summary line per PR
  echo "$PRS_JSON" | jq -r '.[] |
    "PR #\(.number): \(.title)\n  review:\(.reviewDecision) | updated:\(.updatedAt[:10]) | ci:\(if .statusCheckRollup then ([.statusCheckRollup[] | .conclusion // "pending"] | unique | join(",")) else "?" end)"'

  # Reviews and recent inline comments per PR (non-bot only)
  while IFS= read -r num; do
    echo ""
    echo "  [PR #${num} reviews]"
    gh api "repos/$ORG/$repo/pulls/$num/reviews" 2>/dev/null \
      | jq -r --argjson bot "$BOT_FILTER" \
        '.[] | select(.user.login | '"$BOT_FILTER"' | not) |
         "  \(.user.login) \(.state) at \(.submitted_at[:10])"' 2>/dev/null \
      || true

    echo "  [PR #${num} recent comments (non-bot, last 10)]"
    gh api "repos/$ORG/$repo/pulls/$num/comments" 2>/dev/null \
      | jq -r '[.[] | select(.user.login | '"$BOT_FILTER"' | not)] |
         sort_by(.created_at) | reverse | .[0:10][] |
         "  \(.user.login) at \(.created_at[:10]) on \(.path): \(.body | split("\n")[0] | .[0:120])"' 2>/dev/null \
      || true
  done < <(echo "$PRS_JSON" | jq -r '.[].number')
done

# ── Git activity (last 7 days, by current git user) ────────────────────────────
sep "GIT_ACTIVITY"
GIT_AUTHOR=$(git config user.name 2>/dev/null || echo "Zoltan")
find "$WORKSPACE" -maxdepth 2 -name ".git" -type d 2>/dev/null | sort | while IFS= read -r gitdir; do
  repo_dir="${gitdir%/.git}"
  name=$([[ "$repo_dir" == "$WORKSPACE" ]] && echo "osac-workspace" || basename "$repo_dir")
  commits=$(git -C "$repo_dir" log --oneline --author="$GIT_AUTHOR" --since="7 days ago" 2>/dev/null | head -10)
  [[ -z "$commits" ]] && continue
  echo "-- $name --"
  echo "$commits"
done

sep "END"
