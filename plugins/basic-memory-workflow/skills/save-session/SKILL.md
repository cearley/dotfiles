---
name: save-session
description: Save today's session to basic-memory. Run at end of every coding session.
---

## Step 1 — Resolve the project and ensure prerequisites

Run (this skill and its scripts are bundled in the `basic-memory-workflow` plugin, not
copied per-project):
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/resolve-project-name.sh"
```
Use its stdout as `$PROJECT` for every step below. If it exits non-zero, stop — this
project has no git root to derive an identity from.

Check basic-memory is installed:
```bash
which basic-memory
```
If missing, tell the user to run `uv tool install basic-memory` (not `uvx` or `pip`) and
stop — nothing else can proceed without it.

Register the project (safe to run every time — exits 0 with a notice if already
registered, never re-creates anything):
```bash
basic-memory project add "$PROJECT" "$HOME/.local/share/basic-memory/$PROJECT"
```

## Step 2 — Append to the session log

Search basic-memory project "$PROJECT" for the most recent session note using
search_notes with query "$PROJECT session".

Append an update with edit_note (operation="append") including:
- Date (use the currentDate value from context)
- What was changed or decided today (decisions, findings, discoveries)
- Any items resolved this session

Do NOT include open items or next steps here — those go in Step 3.
Never overwrite the existing note — always append.

## Step 3 — Update the current status note

Read the current status note:
  identifier: "$PROJECT/status/$PROJECT-current-status"
  project: "$PROJECT"

Then update it with edit_note (operation="find_replace" or "replace_section") to reflect:
- Any items resolved this session — move from Open to Resolved
- Any new open items or next steps discovered
- Any environment facts that changed (new deployments, confirmed config, etc.)
- Update the "Last updated" date at the top

Treat the existing Open list as the baseline, not a blank page. Preserve every item
already there — remove or move one to Resolved only if it was actually addressed this
session, by name. Never regenerate the Open section from scratch based only on what this
session touched; unrelated open work must survive untouched. If the project tracks
in-flight work in a machine-readable form (issue tracker, OpenSpec changes, TODO file),
spot-check that every still-active item there has a matching Open entry before saving.

This note is the authoritative source for current state. Keep it accurate and tidy.

Confirm both note titles and permalinks after saving.
