---
name: save-session
description: Save today's session to basic-memory — fast, append-only (session log entry + status-note Open/Resolved edit), no size checks or triage. Invoke proactively, without asking for confirmation, whenever the session has produced decision-worthy content (an architectural decision, a resolved open item, a persistable finding) — gate this on substantial tool-call/conversation activity, not on whether any file was edited. Also run at explicit user request (/save-session) or when the user signals they're wrapping up.
---
<!-- setup-memory-workflow-version:12 -->

## Step 0 — Decide whether to run this automatically, without asking

Before invoking this skill on your own initiative (not an explicit `/save-session` from the
user), apply a cheap mechanical pre-filter first, then judgment:

1. **Mechanical pre-filter.** Has this session made a non-trivial number of tool calls, or
   spanned more than a couple of exchanges? A single trivial lookup (e.g. one factual
   question, one tool call, done) fails this filter — stop here, nothing to save. This filter
   is deliberately **not** based on whether any file was edited — a purely exploratory
   session (research, design discussion, `/opsx:explore`) can pass it and be entirely
   save-worthy despite touching no files, while a session that only fixes one typo touches a
   file but may not be.
2. **Judgment.** If the pre-filter passes, decide whether the session actually produced
   something worth persisting: a decision, a resolved open item, a finding, a convention
   established or corrected. If yes, run the steps below directly — do **not** ask the user
   "should I save this session?" and wait for a yes. If no, stop here.

When invoked explicitly (`/save-session`, or the user says they're done), skip straight to
Step 1 — this gate is only for the model's own unprompted initiative.

## Anchor to the project root

Before touching any `.claude/...` path below, confirm you're actually at this project's
root. Claude Code's own working directory can drift over a long session — an earlier `cd`
for an unrelated task, or entering a git worktree — and every relative path in this skill
assumes the project root, not wherever the shell currently happens to be:

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$PROJECT_ROOT"
[ -f ".claude/skills/save-session/SKILL.md" ] || {
  echo "STOP: $PROJECT_ROOT doesn't look like this project (missing .claude/skills/save-session/SKILL.md) — the working directory may have drifted to an unrelated repository."
  exit 1
}
```

If that check fails, stop here and tell the user what happened rather than continuing
against a directory that isn't actually this project.

## Step 1 — Append to the session log

Search basic-memory project "chezmoi" for the most recent session note using
search_notes with query "chezmoi session".

Append today's update directly with edit_note (operation="append") including:
- Date (use the currentDate value from context)
- What was changed or decided today (decisions, findings, discoveries)
- Any items resolved this session

Do NOT include open items or next steps here — those go in Step 2. Never overwrite the
existing note — always append. This step performs one quick append — don't check the
note's size or restructure it here; that requires deliberate judgment a single append
shouldn't attempt.

## Step 2 — Update the current status note

Read the current status note:
  identifier: "chezmoi/status/chezmoi-current-status"
  project: "chezmoi"

If the read fails with a size/token-limit error, don't work around it (chunked reads, inline
summarization, ad hoc trimming) — report the failure (see "On failure" below) and stop. A note
too large to read needs deliberate restructuring, not an improvised fix squeezed into a
routine save.

Otherwise, update it with edit_note (operation="find_replace" or "replace_section") to
reflect:
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

This note is the authoritative source for current state. Keep it accurate and tidy. This
step makes a targeted edit only — move resolved items, add new ones, update the date.
Don't restructure or resize the note as a whole here; a rushed full-body rewrite risks
colliding with unrelated content.

If the edit itself fails after a successful read, report the failure (see below) and stop.

## On success

Confirm both note titles and permalinks to the user.

## On failure

Tell the user which step failed and what the error was, then stop. Do not attempt any
remediation — a note too large to read, or an edit that fails after a successful read, needs
deliberate handling rather than an improvised fix squeezed into a routine save.
