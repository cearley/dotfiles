---
name: save-session
description: Save today's session to basic-memory — fast, append-only (session log entry + status-note Open/Resolved edit), no size checks or triage. Invoke proactively, without asking for confirmation, whenever the session has produced decision-worthy content (an architectural decision, a resolved open item, a persistable finding) — gate this on substantial tool-call/conversation activity, not on whether any file was edited. Also run at explicit user request (/save-session) or when the user signals they're wrapping up.
---
<!-- setup-memory-workflow-version:19 -->

## Anchor to the project root

Before touching any `.claude/...` path below — including Step 0's own marker touch — confirm
you're at this project's root (the working directory can drift over a long session, e.g. a
`cd` for an unrelated task or entering a git worktree):

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$PROJECT_ROOT"
[ -f ".claude/skills/save-session/SKILL.md" ] || {
  echo "STOP: $PROJECT_ROOT doesn't look like this project (missing .claude/skills/save-session/SKILL.md) — the working directory may have drifted to an unrelated repository."
  exit 1
}
```

If that check fails, stop and tell the user rather than continuing against the wrong directory.

Pass `project="chezmoi"` explicitly on every basic-memory call in this skill — never omit
it even though the schema marks it optional (the server doesn't remember a project chosen on
an earlier call, and silent fallback to a different project can go unnoticed). After each write
call (edit_note, write_note), check the result's `project` field matches `chezmoi` before
the next call.

## Step 0 — Decide whether to run this automatically, without asking

Before invoking this skill on your own initiative (not an explicit `/save-session`), apply a
cheap mechanical pre-filter first, then judgment:

1. **Mechanical pre-filter.** Has this session made a non-trivial number of tool calls, or
   spanned more than a couple of exchanges? A single trivial lookup fails this filter — stop
   (recording the session as evaluated first, so the crash-recovery hook knows it was
   considered):
   ```bash
   TRANSCRIPT=$(find "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects" -name "$CLAUDE_CODE_SESSION_ID.jsonl")
   TURN_COUNT=$(jq -c 'select(.type=="user" and (.toolUseResult // null)==null and (.isMeta // false)==false)' "$TRANSCRIPT" | wc -l)
   echo "$CLAUDE_CODE_SESSION_ID:$TURN_COUNT" > .claude/.last-saved-session
   ```
   This is deliberately **not** file-edit-gated — a purely exploratory session (research,
   design discussion, `/opsx:explore`) can pass it despite touching no files, while a
   one-typo-fix session touches a file but may not be save-worthy.
2. **Judgment.** If the pre-filter passes, decide whether the session produced something worth
   persisting: a decision, a resolved open item, a finding, a convention established or
   corrected. If yes, run the steps below directly — do not ask "should I save this session?"
   and wait for a yes. If no, stop (recording evaluated, same snippet as above).

When invoked explicitly (`/save-session`, or the user says they're done), skip straight to
Step 1 — this gate is only for the model's own unprompted initiative.

## Step 1 — Read the current status note, and resolve the active session-log note from it

Read the current status note (project="chezmoi" explicitly):
  identifier: "chezmoi/status/chezmoi-current-status"
  project: "chezmoi"

Its canonical location is `status/chezmoi-current-status` — if this is the project's
first-ever save and the note doesn't exist yet, create it there, not at a freely-chosen title.

If the read fails with a size/token-limit error, don't work around it (chunked reads, inline
summarization, trimming) — report the failure (see "On failure") and stop. A note too large to
read needs deliberate restructuring, not an improvised fix.

Otherwise, before editing, find the active session-log note: take the **last** wikilink
(`[[...]]`) in the most recent dated entry of its Status Summary section — that's the note
Step 2 appends to. Don't search for it: a status note kept accurate by this skill's own past
runs already names the right note, and a fresh `search_notes` query risks ranking a stale,
similarly-named note above it (this happened once — real content landed on a superseded log
because a broader search outranked the actually-active one). If the most recent entry has **no**
wikilink — a brand-new project, or a note predating this convention — fall back to
`search_notes` with query "chezmoi session"; this is the only case where searching is right.

Update the status note with edit_note (project="chezmoi", operation="find_replace" or
"replace_section") to reflect:
- Items resolved this session — move from Open to Resolved
- New open items or next steps discovered
- Environment facts that changed (new deployments, confirmed config, etc.)
- The "Last updated" date at the top

Treat the existing Open list as the baseline, not a blank page — preserve every item already
there, removing or moving one to Resolved only if it was actually addressed this session, by
name. Never regenerate Open from scratch based only on what this session touched; unrelated
open work must survive untouched. If the project tracks in-flight work elsewhere (issue
tracker, OpenSpec changes, TODO file), spot-check that every still-active item there has a
matching Open entry.

Make a targeted edit only — move items, add new ones, update the date. Don't restructure or
resize the note as a whole; a full-body rewrite risks colliding with unrelated content. End
each updated Status Summary entry with a wikilink to today's session-log note — the next
save's Step 1 depends on that link being accurate.

If the edit fails after a successful read, report the failure (see below) and stop.

## Step 2 — Append to the session log

Before writing the entry, check `sessions recent` / `sessions context <id>` (claude-session-index)
as an input — use it to curate which decisions/facts/problems actually belong in the entry
rather than drafting a raw transcript recap.

Append today's update directly with edit_note (project="chezmoi", operation="append") to
the note resolved in Step 1, including:
- Date (use the currentDate value from context)
- What was changed or decided today (decisions, findings, discoveries)
- Items resolved this session

Do NOT include open items or next steps here — those went into Step 1's status-note edit.
Never overwrite the note — always append, and don't check its size or restructure it here;
that needs deliberate judgment a single append shouldn't attempt.

## On success

Record this session as evaluated so the crash-recovery hook knows it was saved:
```bash
TRANSCRIPT=$(find "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects" -name "$CLAUDE_CODE_SESSION_ID.jsonl")
TURN_COUNT=$(jq -c 'select(.type=="user" and (.toolUseResult // null)==null and (.isMeta // false)==false)' "$TRANSCRIPT" | wc -l)
echo "$CLAUDE_CODE_SESSION_ID:$TURN_COUNT" > .claude/.last-saved-session
```

Confirm both note titles and permalinks to the user.

## On failure

Tell the user which step failed and what the error was, then stop. Don't attempt remediation —
a note too large to read, or an edit that fails after a successful read, needs deliberate
handling, not an improvised fix squeezed into a routine save.
