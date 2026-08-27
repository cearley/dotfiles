---
name: save-session-maintenance
description: Roll over an oversized session log and triage an oversized status note. Never invoked by the model on its own initiative — runs only on explicit manual invocation (/save-session-maintenance).
disable-model-invocation: true
---
<!-- setup-memory-workflow-version:12 -->

This skill owns all size/rollover/triage logic for basic-memory notes in this project. It
runs decoupled from any particular save — on its own trigger (see the "Trigger" section
below), never as part of a `save-session` invocation.

## Trigger

This skill is invoked manually, via `/save-session-maintenance`, when a user wants to run
it. Its thresholds below describe when running it is worthwhile, not a trigger that fires on
its own.

It is never invoked by the model's own mid-conversation judgment — this skill's triage work
is judgment-heavy and higher-risk than a routine note edit, and should only run via one of
the two triggers above.

## Anchor to the project root

Before touching any `.claude/...` path below, confirm you're actually at this project's
root. Claude Code's own working directory can drift over a long session — an earlier `cd`
for an unrelated task, or entering a git worktree — and every relative path in this skill
assumes the project root, not wherever the shell currently happens to be:

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$PROJECT_ROOT"
[ -f ".claude/skills/save-session-maintenance/SKILL.md" ] || {
  echo "STOP: $PROJECT_ROOT doesn't look like this project (missing .claude/skills/save-session-maintenance/SKILL.md) — the working directory may have drifted to an unrelated repository."
  exit 1
}
```

If that check fails, stop here and tell the user what happened rather than continuing
against a directory that isn't actually this project.

## Step 1 — Roll over an oversized session log

Search basic-memory project "chezmoi" for the most recent session note using
search_notes with query "chezmoi session".

Check that note's size (read_note, or `wc -l` on its file under
`~/.local/share/basic-memory/chezmoi/`). If it is at or over 300 lines, roll it over —
large session logs get skipped by agents that would otherwise read them:
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
   [[<new archived note>]]." Keep its title and permalink exactly as they were, so
   `save-session`'s own search keeps finding it as "the most recent session note."

If the note is under 300 lines, there is nothing to do for this step — move on to Step 2.

## Step 2 — Triage an oversized status note

Read the current status note:
  identifier: "chezmoi/status/chezmoi-current-status"
  project: "chezmoi"

Check for all three independent signals — any one of them means triage:

1. **Read failure.** If the read itself failed with a size/token-limit error, that IS the
   signal — skip straight to triage regardless of the thresholds below. (In Claude Code
   specifically, a failed read_note/read_content call saves the full content to a local
   temp file the error message points to — inspect and edit via that file's path with
   `wc`/`grep`/`jq`/local tools instead of retrying the read.) This is also the signal
   `save-session`'s own "On failure" step reports to the user.
2. **Total size.** If the read succeeded, treat the note as oversized once its total
   content is at or over roughly 8,000 characters (`wc -c`, or the length of what
   read_note returned). Line count (≥200 lines) remains a secondary trigger for the "many
   distinct items" growth pattern, distinct from #3's "few items growing forever."
3. **Single-entry length.** Independently of the totals above, check for any individual
   line/bullet/paragraph over roughly 800 characters (`awk '{ print length }' | sort -rn`
   against the same local temp file works well here, or eyeball it in what read_note
   returned). One entry that long is the anti-pattern itself, not a symptom of general
   growth, and needs condensing even if the note as a whole is still small.

If none of the three signals are present, there is nothing to do — go to "On completion"
below and log a no-op.

If the `memory-defrag` skill is installed, invoke it against this note instead of triaging
by hand — that's exactly its job ("bloated file >300 lines → split into focused files",
"stale entries → remove or archive"), and its audit → plan → execute → verify → log
workflow gives repeatable, logged output instead of ad hoc judgment calls. Point it at this
note specifically; don't let it wander into unrelated memory files.

If `memory-defrag` isn't installed, triage manually using the same split: content that's
stable reference material or a still-real known issue moves to an existing or new note
under `reference/` or `known-issues/`, with a one-line `See [[Note Title]]` pointer left
behind; content of uncertain future value gets archived rather than deleted.

Either way, for anything leaving this note, prefer the `memory-lifecycle` skill's
archive-never-delete pattern if installed: `move_note` into an `archive/`-style location
rather than copy-and-delete — it preserves the permalink, so any existing
`[[wiki-links]]` into that content keep resolving. Reserve outright deletion for content
that's flatly wrong or superseded, not merely old.

Repeat until all three signals are clear (read succeeds, under ~8,000 characters and 200
lines, no single entry over ~800 characters).

## On completion

Confirm both note titles and permalinks (and the final status-note size, if triaged) to the
user.
