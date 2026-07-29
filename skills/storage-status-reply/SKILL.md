---
name: storage-status-reply
description: "Reply to the latest WG-OSAC-Storage status bot with a formatted accomplishments / risks / key effort update. Gathers data from Jira (closed + in-progress tickets), GitHub (merged PRs), and context from the storage architecture doc and previous replies."
---

# WG-OSAC-Storage Status Reply

Post a status update to the latest `*Please update your status*` thread in `wg-osac-storage`.

## Target format (from real team examples)

```
*Accomplishments*
• :merged2: <https://redhat.atlassian.net/browse/OSAC-1957|OSAC-1957> merged to osac-operator — Storage controller now uses Backend API registration instead of AAP availability heuristic (<https://github.com/osac-project/osac-operator/pull/NNN|osac-operator#NNN>)

*Risks & Challenges*
• <https://redhat.atlassian.net/browse/OSAC-1992|OSAC-1992> blocked on fulfillment-service PR #887 (CHANGES_REQUESTED) merging first

*Key effort*
• OSAC-1957 implementation complete, PR ready for review
• Reviewing osac-test-infra PR #138 (CaaS storage E2E)
```

**Rules:**
- Section headers: `*bold*`
- Bullets: `•`
- Jira links: `<https://redhat.atlassian.net/browse/OSAC-XXXX|OSAC-XXXX>`
- PR links: `<https://github.com/osac-project/REPO/pull/N|REPO#N>`
- Status emojis: `:merged2:` (merged PR), `:in-progress:` (active), `:stop:` (reverted/blocked), `:check:` (done)
- Keep it concise — 3–5 bullets total across all sections

---

## Process

### Step 0: Establish current date

```bash
date "+%A, %Y-%m-%d"
```

### Step 1: Find the latest status report message

Search `wg-osac-storage` (channel ID: `C0B6USDQ85S`) for the most recent bot message matching `"Please update your status"`:

```
mcp__slack__get_channel_history(channel_id="C0B6USDQ85S", limit=50)
```

Scan messages newest-first for one where the text contains `Please update your status`. Record its `thread_ts` — this is what we reply to.

### Step 2: Find the previous reply date (time window for accomplishments)

Read the thread of the **previous** status report (the one before today's) to find Zoltan's (`@zszabo`) last reply:

```
mcp__slack__get_thread(channel_id="C0B6USDQ85S", thread_ts=<previous_status_report_ts>)
```

If Zoltan replied, use that reply's timestamp as `SINCE_DATE`. If no previous reply found, use 7 days ago as the default window.

Convert `SINCE_DATE` to `YYYY-MM-DD` for Jira queries:
```bash
date -d "@SINCE_EPOCH" "+%Y-%m-%d"
```

### Step 3: Gather accomplishments

Run these in parallel.

#### 3a: Jira — tickets closed since last reply

```bash
JIRA_LOGIN=$(grep '^login:' ~/.config/.jira/.config.yml | sed 's/login: //')
JIRA_TOKEN=$(grep '^token:' ~/.config/.jira/.config.yml | sed 's/token: //')
JIRA_SERVER=$(grep '^server:' ~/.config/.jira/.config.yml | sed 's/server: //')

curl -s -u "${JIRA_LOGIN}:${JIRA_TOKEN}" \
  "${JIRA_SERVER}/rest/api/3/search/jql?jql=assignee+%3D+currentUser()+AND+status+%3D+Closed+AND+updated+%3E%3D+'${SINCE_DATE}'+ORDER+BY+updated+DESC&maxResults=10&fields=summary,status,updated" \
  | python3 -c "
import sys, json
d = json.load(sys.stdin)
for i in d.get('issues', []):
    print(i['key'], '|', i['fields']['summary'])
"
```

Also check for tickets moved to "Code Review" (PR-submitted state):
```bash
curl -s -u "${JIRA_LOGIN}:${JIRA_TOKEN}" \
  "${JIRA_SERVER}/rest/api/3/search/jql?jql=assignee+%3D+currentUser()+AND+status+%3D+'Code+Review'+AND+updated+%3E%3D+'${SINCE_DATE}'&maxResults=5&fields=summary,status" \
  | python3 -c "
import sys, json
d = json.load(sys.stdin)
for i in d.get('issues', []):
    print(i['key'], '|', i['fields']['summary'])
"
```

#### 3b: GitHub — merged PRs by zszabo in storage-related repos

```bash
gh pr list --repo osac-project/osac-operator --state merged --author zszabo-rh \
  --json number,title,mergedAt --jq \
  ".[] | select(.mergedAt >= \"${SINCE_DATE}\") | \"\(.number) | \(.title) | \(.mergedAt)\""

gh pr list --repo osac-project/osac-aap --state merged --author zszabo-rh \
  --json number,title,mergedAt --jq \
  ".[] | select(.mergedAt >= \"${SINCE_DATE}\") | \"\(.number) | \(.title) | \(.mergedAt)\""

gh pr list --repo osac-project/osac-test-infra --state merged --author zszabo-rh \
  --json number,title,mergedAt --jq \
  ".[] | select(.mergedAt >= \"${SINCE_DATE}\") | \"\(.number) | \(.title) | \(.mergedAt)\""
```

### Step 4: Gather risks & challenges

#### 4a: Jira — open tickets with blocking dependencies

```bash
curl -s -u "${JIRA_LOGIN}:${JIRA_TOKEN}" \
  "${JIRA_SERVER}/rest/api/3/search/jql?jql=assignee+%3D+currentUser()+AND+status+NOT+IN+(Closed,Done)+AND+project+%3D+OSAC+ORDER+BY+updated+DESC&maxResults=10&fields=summary,status,issuelinks,priority" \
  | python3 -c "
import sys, json
d = json.load(sys.stdin)
for i in d.get('issues', []):
    links = i['fields'].get('issuelinks', [])
    blocked_by = [l['inwardIssue']['key'] for l in links if l.get('type', {}).get('inward') == 'is blocked by' and l.get('inwardIssue')]
    print(i['key'], '|', i['fields']['status']['name'], '|', i['fields']['summary'], '| blocked by:', blocked_by)
"
```

#### 4b: GitHub — open PRs by zszabo awaiting review

```bash
gh pr list --repo osac-project/osac-operator --author zszabo-rh --state open \
  --json number,title,reviewDecision,updatedAt
```

### Step 5: Gather key effort (in-progress work)

```bash
curl -s -u "${JIRA_LOGIN}:${JIRA_TOKEN}" \
  "${JIRA_SERVER}/rest/api/3/search/jql?jql=assignee+%3D+currentUser()+AND+status+%3D+'In+Progress'+AND+project+%3D+OSAC+ORDER+BY+updated+DESC&maxResults=5&fields=summary,status" \
  | python3 -c "
import sys, json
d = json.load(sys.stdin)
for i in d.get('issues', []):
    print(i['key'], '|', i['fields']['summary'])
"
```

Also check the storage architecture doc for current context:
```bash
head -5 artifacts/osac-storage-architecture-overview.md
```

And check what PR is currently open from Zoltan that needs review:
```bash
gh pr list --repo osac-project/osac-operator --author zszabo-rh --state open \
  --json number,title,reviewDecision
```

### Step 6: Synthesize and draft the message

Using data from Steps 3–5, draft the Slack message.

**Accomplishments rules:**
- Each merged PR → one bullet with `:merged2:` emoji, Jira ticket link, short description, PR link
- Each closed Jira ticket (no corresponding PR) → bullet with `:check:` and Jira link
- Focus on the work done since `SINCE_DATE`. Omit old work.

**Risks & Challenges rules:**
- Only real blockers or stall risks, not speculation
- If a PR is stuck waiting for review: flag it with how long it's been open
- If a ticket is blocked by another ticket: flag the dependency
- If nothing meaningful, omit the section or write "None at this time"

**Key effort rules (from team examples):**
- 1–3 bullets describing what you're actively working on RIGHT NOW
- This is the current sprint focus, not completed work
- Can include: upcoming PR to submit, review you're doing, meeting prep
- In Will's replies it's the next concrete action (e.g., "Land PR #377 once CI passes")

**Formatting reminders:**
- Use `<jira-url|OSAC-XXXX>` for Jira links
- Use `<gh-url|repo#N>` for PR links
- Status emojis: `:merged2:` `:in-progress:` `:check:` `:stop:` `:changes-requested:`
- Bold section headers with `*...*`
- Plain `•` bullets (not `-`)

### Step 7: Present for review and post

Show the drafted message to the user:

```
Here's the draft status reply for wg-osac-storage:

---
[MESSAGE]
---

Post this to the thread? (y/n)
```

If approved, post to the status report thread:

```
mcp__slack__post_message(
    channel_id="C0B6USDQ85S",
    message=<formatted_message>,
    thread_ts=<status_report_ts>
)
```

Confirm with: "Posted ✓ — replied to the [DATE] status report thread."

### Error handling

- **No status report found**: "No status report found in wg-osac-storage in the last 7 days."
- **Jira unavailable**: Gather accomplishments from GitHub only. Note in the draft that Jira data is missing.
- **No previous reply found**: Use 7 days as the default window. Note this in the draft.
