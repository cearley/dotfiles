# Tasks

## 1. Fix BM 1.x tool-call guidance in save-session-skill.md.template

- [x] 1.1 In the template's BM 1.x write contract section, add a concrete, correctly-shaped
  `bm_edit(command="find_replace", find_text=..., content=..., expected_checksum=...)` example
  showing `content` (not `replace_text`) as the replacement argument. Verify by grepping the
  rendered template for `replace_text` and confirming zero matches, and for `content=` next to
  `find_replace` confirming at least one match.
- [x] 1.2 Remove/correct the nonexistent `bm_read(page=...)` pattern, documenting
  `start_line`/`end_line`/`max_tokens` as the only pagination arguments. Verify by grepping the
  template for `bm_read(` + `page` and confirming zero matches.
- [x] 1.3 Add a lightweight grep-based assertion (in the skill's existing bashunit suite, or an
  equivalent documentation check) that the template contains the corrected `find_replace`
  example and no `bm_read(page=...)` reference, so a future edit can't silently reintroduce
  either bug. Verify by running the new check and confirming it passes against the current
  template, then fails if either bug is reintroduced locally (a quick manual sanity check,
  reverted after).

## 2. Add a deterministic oversized-note check callable from the save path

- [x] 2.1 Add a `status-bloat` subcommand to `executable_check-drift.sh` that wraps
  `lib-status-note.sh`'s existing `check_status_note_bloat()`, exiting 0 when the current-status
  note is under all three thresholds and 1 when any threshold is met or exceeded, with no
  behavior change to `check_status_note_bloat()` itself. Verify with
  `tests/lint-shell home/dot_claude/skills/setup-memory-workflow/scripts/executable_check-drift.sh`
  and a manual run against a known-small fixture note (expect exit 0).
- [x] 2.2 Add a bashunit test covering `status-bloat`'s exit code against four fixtures: under
  all thresholds, at/over the character threshold, at/over the line threshold, and at/over the
  single-line-length threshold. Verify by running the `setup-memory-workflow` bashunit suite and
  confirming all four new cases pass.

## 3. Cap Status Summary entries and gate growth when the note is already oversized

- [x] 3.1 Rewrite Step 1's entry-authoring instructions in `save-session-skill.md.template` to
  require the 5-line explicit-line format (a date line, 1-3 short content lines/bullets, a
  `Detail: [[...]]` line) instead of a single flowing prose paragraph, including a worked
  example. Verify by confirming the template's own example entry is 5 lines or fewer and uses
  explicit line breaks, not one run-on paragraph.
- [x] 3.2 Add the oversized-gate step to Step 1: call `check-drift.sh status-bloat` before
  drafting a new entry, and on a nonzero exit write only a short pointer line (noting the save
  occurred and that `/save-session-maintenance` is needed) instead of a full capped entry.
  Verify by tracing the rewritten Step 1 text against both scenarios in
  `specs/setup-memory-workflow/spec.md` ("Status note is already oversized at save time" and
  "Status note is under threshold at save time") and confirming the instructions cover both.

## 4. Remove the duplicate identity check from save's Preflight

- [x] 4.1 Remove the `check-drift.sh check` call from `save-session-skill.md.template`'s
  Preflight, keeping only `check-drift.sh authorize`. Verify by grepping the template's
  Preflight section for `check-drift.sh check` and confirming zero matches there, while
  confirming `save-session-maintenance-skill.md.template`'s Step 0 still calls `check-drift.sh
  check` unchanged.

## 5. Collapse the SessionStart hook chain to one library-sourcing pass

- [x] 5.1 Extract `check-drift.sh drift-warn`'s check logic into a function (e.g.
  `check_drift_warn()`) in `lib-status-note.sh` or a new `lib-drift-warn.sh`, called by both
  `check-drift.sh drift-warn` (unchanged CLI entry point) and directly by
  `executable_session-reminder.sh` in-process, removing the second subprocess invocation from
  the `SessionStart` hook chain. Verify with `tests/lint-shell` on every modified/new script
  file.
- [x] 5.2 Confirm `check-drift.sh drift-warn` run standalone after the refactor produces
  identical output to before it, against the same fixture project. Verify by capturing output
  before and after the refactor and diffing byte-for-byte.
- [x] 5.3 Update the `SessionStart` hook registration (wherever it chains
  `session-reminder.sh; check-drift.sh drift-warn`) to invoke only `session-reminder.sh`, which
  now also performs the drift-warn check in-process. Verify by running the updated hook command
  against a fixture project and confirming stdout contains both the reminder output and the
  drift-warn output exactly as before.

## 6. Version bump and rollout prep

- [x] 6.1 Bump `SMW_VERSION` to the next integer and update both skill templates' version
  markers. Verify by grepping the skill directory for the old version number and confirming
  zero remaining references outside `CHANGELOG.md`'s own history.
- [x] 6.2 Add a new `CHANGELOG.md` entry describing all changes from tasks 1-5 (tool-call fixes,
  entry cap + oversized gate, Preflight scope cut, hook-chain collapse). Verify by reading the
  entry back and confirming it names every file touched across those task groups.
- [x] 6.3 Run the full `setup-memory-workflow` bashunit suite plus `tests/lint-shell --all`
  scoped to this skill's scripts, and confirm all pass. Verify via the suite's exit code and
  final pass/fail count.

## Workflow follow-up

- Deploy the new version locally via `check-drift.sh update` in this repo's own checkout
  (dogfooding) and confirm `/save-session` runs clean end to end at least once.
- Run `/opsx:verify` against this change once implementation is complete.
- Archive the change with `/opsx:archive`, syncing the `setup-memory-workflow` main spec.
- Separately and explicitly, run `/save-session-maintenance` to triage the already-oversized
  live status note — not part of this change's implementation, per proposal.md - Non-goals.
- Roll the new version out to other projects/machines via the existing
  `bulk-update-memory-workflow` sweep, once confirmed stable here.
