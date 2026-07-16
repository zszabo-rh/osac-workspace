# Reusable bash patterns

**Read this file before any `jira issue create` or `jira issue edit`.**

Define once before any Jira create: source `tools/jira-safe-create.sh` (see
`jira-task-management` Safe create pattern), then define skill-specific helpers
below. Reference these from each create step instead of duplicating key
validation or `--plain` parsing.

## Source safe-create script

```bash
source "$(git rev-parse --show-toplevel)/tools/jira-safe-create.sh"
```

## Key validation and JQL helpers

```bash
# After jq -r '.key // empty' — stop on empty/malformed keys
require_osac_key() {
  local key=$1 label=$2 out=$3 err=$4
  if ! [[ "${key}" =~ ^OSAC-[0-9]+$ ]]; then
    echo "Invalid or empty ${label} key: ${key:-<empty>}" >&2
    cat "$err" >&2
    jq -r '.errorMessages[]? // .errors? // empty' "$out" 2>/dev/null >&2
    exit 1
  fi
}

# Parse KEY column from jira issue list --plain (skip header row).
# jira-cli --plain is tab-separated: TYPE, KEY, SUMMARY, … — column 2 is KEY.
# If layout changes, fall back to first OSAC-NNNN token on the line.
parse_plain_keys() {
  tail -n +2 | while IFS= read -r line; do
    [ -z "$line" ] && continue
    key=$(printf '%s\n' "$line" | awk -F'\t' '$2 ~ /^OSAC-[0-9]+$/ {print $2; exit}')
    if [ -n "$key" ]; then
      echo "$key"
    else
      printf '%s\n' "$line" | grep -Eo 'OSAC-[0-9]+' | head -1
    fi
  done
}

# Collect keys for JQL into variables (bash 3.2 / zsh — no mapfile).
# Usage: read keys from list_keys_for_jql "…" into FIRST_KEY and KEY_COUNT.
list_keys_for_jql() {
  jira issue list -q "$1" --plain | parse_plain_keys
}

collect_keys_from_jql() {
  local jql=$1
  FIRST_KEY=""
  KEY_COUNT=0
  local k
  while IFS= read -r k; do
    [ -z "$k" ] && continue
    KEY_COUNT=$((KEY_COUNT + 1))
    FIRST_KEY=$k
  done < <(list_keys_for_jql "$jql")
}
```

## Fix version helpers

```bash
# Fetch OSAC fix-version candidates (exclude 0.0 — pre-team legacy bucket —
# and the literal "Backlog" release, which collides with this skill's own
# "backlog" sentinel for "no fix version"; see validate_fix_version).
# jira release list does NOT support useful --plain output; parse tab format.
# Columns: ID, NAME, RELEASED, DESCRIPTION
# Output: one version name per line, newest first (sort -Vr).
list_fix_version_suggestions() {
  jira release list -p OSAC 2>/dev/null \
    | awk -F'\t' 'NR>1 && $2 != "0.0" && tolower($2) != "backlog" && $3 == "false" {print $2}' \
    | sort -Vr
}

# Validate user-chosen version. Returns: backlog | <version> | invalid
# backlog only when user explicitly says backlog/none/skip (not empty string).
validate_fix_version() {
  local choice
  choice=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')
  case "$choice" in
    backlog|none|skip) echo "backlog"; return 0 ;;
    '') echo "invalid"; return 0 ;;
  esac
  if list_fix_version_suggestions | grep -Fxq "$1"; then
    echo "$1"
  else
    echo "invalid"
  fi
}

# Set fixVersion on Feature when FIX_VERSION is not backlog.
# Run after require_osac_key on Feature KEY, before assign/bootstrap; use </dev/null>.
# jira issue edit --fix-version appends; safe on new Features (empty fixVersions).
# Returns 1 on edit failure (non-fatal — does not exit) so the caller can avoid
# copying an unset version onto the bootstrap epic. Backlog is not a failure.
apply_feature_fix_version() {
  local key=$1 version=$2
  [ "$version" = "backlog" ] && return 0
  local err
  err=$(new_temp osac-jira-fixver-err)
  add_temp "$err"
  if ! jira issue edit "$key" --fix-version "$version" --no-input 2>"$err" </dev/null; then
    echo "Fix version edit failed for ${key} (${version}) — set manually:" >&2
    echo "  jira issue edit ${key} --fix-version \"${version}\" --no-input </dev/null" >&2
    cat "$err" >&2
    return 1
  fi
}
```

## Bootstrap epic metadata

```bash
# After bootstrap epic parent verified. Label at create; copy fix version here.
# Re-run safe on reuse: add label if missing; set fix version only when epic has none.
# Caller passes "backlog" for fix_version when the Feature edit did not succeed,
# so a failed Feature update never results in a copied version on the epic.
apply_bootstrap_epic_metadata() {
  local epic_key=$1 feature_key=$2 fix_version=$3
  local err
  err=$(new_temp osac-jira-bootstrap-meta-err)
  add_temp "$err"

  if ! jira issue edit "$epic_key" -l bootstrap --no-input 2>>"$err" </dev/null; then
    echo "Bootstrap label edit failed for ${epic_key} — set manually:" >&2
    echo "  jira issue edit ${epic_key} -l bootstrap --no-input </dev/null" >&2
    cat "$err" >&2
  fi

  [ "$fix_version" = "backlog" ] && return 0

  local epic_version_count
  epic_version_count=$(jira issue view "$epic_key" --raw 2>/dev/null \
    | jq -r '[.fields.fixVersions[]?.name] | length')
  [ "${epic_version_count:-0}" -gt 0 ] && return 0

  if ! jira issue edit "$epic_key" --fix-version "$fix_version" --no-input 2>>"$err" </dev/null; then
    echo "Bootstrap fix version copy failed for ${epic_key} (${fix_version}) — set manually:" >&2
    echo "  jira issue edit ${epic_key} --fix-version \"${fix_version}\" --no-input </dev/null" >&2
    cat "$err" >&2
    return 0
  fi
}
```

## Safe-create rules

Safe-create rules (all create/edit steps):
- Append **`</dev/null`** to every `jira issue create` and `jira issue edit` — jira-cli
  blocks on stdin in non-TTY shells ([jira-cli#948](https://github.com/ankitpokhrel/jira-cli/issues/948))
- Run `jira issue create` directly — not inside `$(...)`
- Write bodies to `--template` files; capture stdout/stderr to temps
- Allow up to 3 minutes per operation; **never kill** and retry
- Before retry, re-search Jira — duplicate creates are worse than slow creates
- If stdout is slow, poll Jira (`jira issue view`) instead of killing the in-flight command

## Example create pattern

```bash
BODY=$(new_temp osac-feature-body)
add_temp "$BODY"
OUT=$(new_temp osac-jira-out)
add_temp "$OUT"
ERR=$(new_temp osac-jira-err)
add_temp "$ERR"
# ... jira issue create ... >"$OUT" 2>"$ERR" </dev/null
KEY=$(jq -r '.key // empty' "$OUT")
require_osac_key "$KEY" "Feature" "$OUT" "$ERR"
```

## Duplicate search pattern

```bash
collect_keys_from_jql "parent = ${EPIC_KEY} AND type = Task AND summary = \"PRD\""
# KEY_COUNT == 1 → reuse FIRST_KEY; KEY_COUNT > 1 → ask user; 0 → create
```
