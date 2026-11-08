---
name: save-session-maintenance
description: Roll over an oversized session log and triage an oversized status note. Never invoked by the model on its own initiative — runs only on explicit manual invocation (/save-session-maintenance).
disable-model-invocation: true
---
<!-- setup-memory-workflow-version:19 -->

This skill owns all size/rollover/triage logic for basic-memory notes in this project. It runs
decoupled from any particular save — on its own trigger below, never as part of a
`save-session` invocation.

## Trigger

Manual only, via `/save-session-maintenance`. The thresholds below describe when running it is
worthwhile, not an automatic trigger — this skill is never invoked by the model's own
mid-conversation judgment, since its triage work is judgment-heavy and higher-risk than a
routine note edit.

## Anchor to the project root

Before touching any `.claude/...` path below, confirm you're at this project's root (the
working directory can drift over a long session, e.g. a `cd` for an unrelated task or
entering a git worktree):

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$PROJECT_ROOT"
[ -f ".claude/skills/save-session-maintenance/SKILL.md" ] || {
  echo "STOP: $PROJECT_ROOT doesn't look like this project (missing .claude/skills/save-session-maintenance/SKILL.md) — the working directory may have drifted to an unrelated repository."
  exit 1
}
```

If that check fails, stop and tell the user rather than continuing against the wrong directory.

## Step 1 — Roll over an oversized session log

Search basic-memory project "chezmoi" for the most recent session note using search_notes
with query "chezmoi session".

Check that note's size (read_note, or `wc -l` on its file under
`~/.local/share/basic-memory/chezmoi/`). If at or over 300 lines, roll it over — large
session logs get skipped by agents that would otherwise read them:
1. Find the note's earliest dated entry (its first `## YYYY-MM-DD` header) — that date names
   the archived copy.
2. Create a note titled `Session Log — <earliest-date>` in the project's `sessions/`
   directory, with the same frontmatter style as the project's other session logs
   (title/type/permalink/tags) and the full body of the note being rolled over. Give it a
   one-line banner: "Archived, <earliest-date> → <today>. Continues from
   [[<prior archived log>]]" (only if a prior one exists) "— continuation lives in
   [[<active note's title>]]."
3. If a prior archived log already links forward to this note (a "continuation lives in"
   banner or a `leads_to` relation), repoint it at the new archived note instead — keep the
   chain unbroken.
4. Replace the active note's body with just a short banner: "Continues from
   [[<new archived note>]]." Keep its title and permalink exactly as they were, so
   `save-session`'s own search keeps finding it as the most recent session note.

If under 300 lines, nothing to do — move on to Step 2.

## Step 2 — Triage an oversized status note

Read the current status note:
  identifier: "chezmoi/status/chezmoi-current-status"
  project: "chezmoi"

Check for all three independent signals — any one means triage:

1. **Read failure.** A size/token-limit error on the read IS the signal — skip straight to
   triage regardless of the thresholds below. (In Claude Code, a failed read_note/read_content
   call saves the full content to a local temp file the error points to — inspect/edit via
   that path with `wc`/`grep`/`jq` instead of retrying the read.) This is also the signal
   `save-session`'s own "On failure" step reports.
2. **Total size.** If the read succeeded, treat the note as oversized at or over roughly 8,000
   characters (`wc -c`, or the length read_note returned). Line count (≥200) is a secondary
   trigger for the "many distinct items" growth pattern, distinct from #3's "few items growing
   forever."
3. **Single-entry length.** Independently, check for any individual line/bullet/paragraph over
   roughly 800 characters (`awk '{ print length }' | sort -rn` against the temp file, or
   eyeball read_note's output). One entry that long is the anti-pattern itself, not a symptom
   of general growth, and needs condensing even if the note as a whole is still small.

If none of the three signals are present, there's nothing to do — go to "On completion" and
log a no-op.

If the `memory-defrag` skill is installed, invoke it against this note instead of triaging by
hand — that's exactly its job ("bloated file >300 lines → split into focused files", "stale
entries → remove or archive"), and its audit → plan → execute → verify → log workflow gives
repeatable, logged output. Point it at this note specifically; don't let it wander into
unrelated memory files.

If not installed, triage manually using the same split: stable reference material or a
still-real known issue moves to an existing or new note under `reference/` or
`known-issues/`, with a one-line `See [[Note Title]]` pointer left behind; content of
uncertain future value gets archived rather than deleted.

Either way, for anything leaving this note, prefer the `memory-lifecycle` skill's
archive-never-delete pattern if installed: `move_note` into an `archive/`-style location
rather than copy-and-delete — it preserves the permalink, so existing `[[wiki-links]]` into
that content keep resolving. Reserve outright deletion for content that's flatly wrong or
superseded, not merely old.

Repeat until all three signals are clear (read succeeds, under ~8,000 characters and 200
lines, no single entry over ~800 characters).

## On completion

Confirm both note titles and permalinks (and the final status-note size, if triaged) to the
user.
