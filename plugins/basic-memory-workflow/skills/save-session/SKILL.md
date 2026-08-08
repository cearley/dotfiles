---
name: save-session
description: Save today's session to basic-memory. Run at end of every coding session.
---

## Step 1 — Resolve the project and ensure prerequisites

Run (this skill and its scripts are bundled in the `basic-memory-workflow` plugin, not
copied per-project):
```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/resolve-project-name.sh"
```
Use its stdout as `$PROJECT` for every step below. If it exits non-zero, stop — this
project has no git root to derive an identity from.

Check basic-memory is installed:
```bash
which basic-memory
```
If missing, tell the user to run `uv tool install basic-memory` (not `uvx` or `pip`) and
stop — nothing else can proceed without it.

The project itself is already registered with basic-memory by this point — the
`SessionStart` hook (`ensure-project-registered.sh`) guarantees that before any skill or
MCP tool call happens in this session, so there is nothing to do here.

## Step 2 — Append to the session log

Search basic-memory project "$PROJECT" for the most recent session note using
search_notes with query "$PROJECT session".

Before appending, check that note's size (read_note, or `wc -l` on its file under
`~/.local/share/basic-memory/$PROJECT/`). If it is at or over 300 lines, roll it over
first — large session logs get skipped by agents that would otherwise read them:
1. Find the note's earliest dated entry (its first `## YYYY-MM-DD` header) — that date
   names the archived copy.
2. Create a new note titled `Session Log — <earliest-date>` in the project's
   `sessions/` directory, with the same frontmatter style as the project's other
   session logs (title/type/permalink/tags) and the full body of the note being rolled
   over. Give it a one-line banner: "Archived, <earliest-date> → <today>. Continues
   from [[<prior archived log>]]" (only if a prior one exists) "— continuation lives in
   [[<active note's title>]]."
3. If a prior archived log already links forward to this note (a "continuation lives
   in" banner or a `leads_to` relation), repoint it at the new archived note instead of
   skipping ahead to the active one — keep the chain unbroken.
4. Replace the active note's body with just a short banner: "Continues from
   [[<new archived note>]]." Keep its title and permalink exactly as they were, so this
   same search keeps finding it as "the most recent session note."

Then append today's update with edit_note (operation="append") including:
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
