# Create bootstrap tasks

**Read this file after bootstrap epic parent linkage is verified.**

**Requires [bash-patterns.md](bash-patterns.md) sourced first** — helpers (`collect_keys_from_jql`,
`require_osac_key`, `new_temp`) must already be defined.

## Gate task summary

Create documentation gate tasks under the bootstrap epic. Line 1 of each body
matches Jira AC text; PRD and Design add a workflow hint on line 2. Every task
body includes `Feature: ${KEY}` on its own line. Do **not** reference
`/ux-design` or `/ui-design`.

| Summary | Labels | Body (lines in `$TASK_BODY`) | When |
|---------|--------|------------------------------|------|
| PRD | (none) | 1: Draft, submit, and merge the Product Requirements Document. 2: Use `/prd` workflow. 3: Feature: ${KEY} | Always |
| Design | (none) | 1: Draft, submit, and merge the technical Design / Enhancement Proposal. 2: Use `/design` workflow. 3: Feature: ${KEY} | Always |
| UX Design | `osac-ux` | 1: Draft, submit, and merge the UX specification. 2: Feature: ${KEY} | `REQUIRES_UI=yes` |
| UI Design | `osac-ui` | 1: Draft, submit, and merge the UI design document. 2: Feature: ${KEY} | `REQUIRES_UI=yes` |

Apply gate-task labels only on the task they describe — do **not** put `osac-ux`
on UI Design or `osac-ui` on UX Design. PRD and Design have no labels
(universal gates, not UX- or UI-specific work).

## Duplicate check

For each gate task, duplicate-check with exact summary (substitute task name in
JQL — summaries are literal: `PRD`, `Design`, `UX Design`, `UI Design`):

```bash
TASK_SUMMARY="PRD"   # or Design, UX Design, UI Design
collect_keys_from_jql "parent = ${EPIC_KEY} AND type = Task AND summary = \"${TASK_SUMMARY}\""
if [ "$KEY_COUNT" -gt 1 ]; then
  echo "Multiple tasks named ${TASK_SUMMARY} under epic — ask user" >&2
  exit 1
fi
if [ "$KEY_COUNT" -eq 1 ]; then
  # reuse FIRST_KEY as TASK_* for this summary; skip create
fi
```

## Task creation order

Create tasks in order: **PRD → Design → UX Design → UI Design** (last two only
when `REQUIRES_UI=yes`). Reuse temps via `new_temp` each iteration.

Task create with `-P "${EPIC_KEY}"` is safe — Jira only rejects `-P` on **Epic
create** when the parent is a Feature; tasks under an epic accept `-P` normally.

## PRD task

```bash
TASK_BODY=$(new_temp osac-bootstrap-task)
add_temp "$TASK_BODY"
OUT=$(new_temp osac-jira-task-out)
add_temp "$OUT"
ERR=$(new_temp osac-jira-task-err)
add_temp "$ERR"

cat >"$TASK_BODY" <<EOF
Draft, submit, and merge the Product Requirements Document.

Use \`/prd\` workflow.

Feature: ${KEY}
EOF

jira issue create -t Task --project OSAC -s "PRD" \
  --template "$TASK_BODY" \
  -P "${EPIC_KEY}" --no-input --raw >"$OUT" 2>"$ERR" </dev/null

TASK_PRD=$(jq -r '.key // empty' "$OUT")
require_osac_key "$TASK_PRD" "task PRD" "$OUT" "$ERR"
```

Repeat for Design (change summary, body, and labels per the table).

## UX Design task

When `REQUIRES_UI=yes`:

```bash
cat >"$TASK_BODY" <<EOF
Draft, submit, and merge the UX specification.

Feature: ${KEY}
EOF

jira issue create -t Task --project OSAC -s "UX Design" \
  --template "$TASK_BODY" \
  -P "${EPIC_KEY}" --label osac-ux --no-input --raw >"$OUT" 2>"$ERR" </dev/null

TASK_UX=$(jq -r '.key // empty' "$OUT")
require_osac_key "$TASK_UX" "task UX Design" "$OUT" "$ERR"
```

## UI Design task

```bash
cat >"$TASK_BODY" <<EOF
Draft, submit, and merge the UI design document.

Feature: ${KEY}
EOF

jira issue create -t Task --project OSAC -s "UI Design" \
  --template "$TASK_BODY" \
  -P "${EPIC_KEY}" --label osac-ui --no-input --raw >"$OUT" 2>"$ERR" </dev/null

TASK_UI=$(jq -r '.key // empty' "$OUT")
require_osac_key "$TASK_UI" "task UI Design" "$OUT" "$ERR"
```

UX/UI task bodies omit the `/prd` or `/design` workflow line — see table above.

## Error handling

On any empty task key, stop and report Feature key, epic key, completed task
keys, plus `$ERR` and error JSON from `$OUT`.
