# Tasks

## 1. Bounded Open-items excerpt in the SessionStart reminder

- [x] 1.1 Add an `extract_open_excerpt()` helper to `home/dot_claude/skills/setup-memory-workflow/scripts/executable_check-drift.sh` that reads `~/.local/share/basic-memory/$PROJECT/status/$PROJECT-current-status.md`, extracts lines between the `## Open` heading and the next `##` heading, caps at 15 lines with a `... (N more open items — see the status note)` truncation marker when exceeded, and prints nothing (empty string, not an error) when the note is missing, unreadable, or has no `## Open` section — verify by running the function directly against a hand-written fixture note with (a) a short Open list, (b) an Open list over 15 lines, (c) no Open heading, (d) a missing file, and checking stdout matches the expected case in each
- [x] 1.2 Add an `__OPEN_EXCERPT__` placeholder to `assets/hook-message.txt.template`, written so that when the placeholder substitutes to an empty string the rendered message has no dangling header or blank section (e.g. the excerpt block is its own line(s), not interpolated mid-sentence) — verify by rendering the template with an empty substitution and confirming the output is byte-identical to today's message
- [x] 1.3 Wire `extract_open_excerpt()`'s output into `render()`'s substitution in `canonical_hook_cmd()` (new `sed` replacement for `__OPEN_EXCERPT__`, alongside the existing `__PROJECT__`/`__SMW_VERSION__` ones) — verify by running `check-drift.sh check` in a scratch project with a fixture status note and confirming the rendered `.claude/settings.local.json` hook command contains the expected excerpt text
- [x] 1.4 Bump `SMW_VERSION` in `executable_check-drift.sh` by 1 — verify `check-drift.sh check` in an already-installed scratch project now reports `DRIFT` for the SessionStart hook entry, and `check-drift.sh update` repairs it to the new rendered content

## 2. Current-status note bloat signal in `drift-warn`

- [x] 2.1 Extend `cmd_drift_warn()` to check `~/.local/share/basic-memory/$PROJECT/status/$PROJECT-current-status.md` against `save-session-maintenance`'s existing thresholds (total ≥~8,000 chars via `wc -c`, ≥200 lines via `wc -l`, or any single line/entry ≥~800 chars via the `awk '{ print length }' | sort -rn` pattern already documented in `assets/save-session-maintenance-skill.md.template`), printing `[setup-memory-workflow] current-status note looks oversized — run /save-session-maintenance to triage it.` when any threshold is crossed — independent of, and in addition to, the existing version-drift line — verify by running `check-drift.sh drift-warn` against three fixture notes (under all thresholds, over the total-size threshold, over the single-entry threshold) and confirming the expected line is present/absent in each case
- [x] 2.2 Confirm the note-bloat check degrades silently (no output for that signal, no non-zero exit propagated past `drift-warn`'s own `|| true` caller) when the status note file doesn't exist yet — verify by running `check-drift.sh drift-warn` in a project that has never run `/save-session` and confirming it exits 0 with only the pre-existing version-drift behavior (if any)
- [x] 2.3 Confirm `cmd_drift_warn` still prints the pre-existing version-drift line unchanged when only that condition applies, and both lines when both apply — verify by running `check-drift.sh drift-warn` with a stale save-session skill version alongside both a bloated and a non-bloated fixture note

## 3. Documentation and changelog

- [x] 3.1 Update `home/dot_claude/skills/setup-memory-workflow/CHANGELOG.md` with an entry for the new `SMW_VERSION`, describing both changes (bounded excerpt, note-bloat drift-warn signal) — verify the entry follows the existing changelog's format for prior version bumps
- [x] 3.2 Update `SKILL.md`'s "Updating the canonical templates" section to mention the new `__OPEN_EXCERPT__` placeholder alongside the existing `__PROJECT__`/`__SMW_VERSION__` ones — verify by reading the updated section back and confirming it names the new placeholder and its source (`extract_open_excerpt()`)
- [x] 3.3 Append a short "Implemented" note to the "Comparative lessons" section of `docs/architecture/setup-memory-workflow.md` (items 1 and 5) pointing at this change's final location once archived — verify the note names the change and renders correctly as markdown

## 4. End-to-end verification

- [x] 4.1 In a disposable scratch git repo, run `check-drift.sh check` fresh (no prior install), confirm all pieces including the new excerpt render correctly with a fixture `/save-session`-written status note already in basic-memory, then run a second `check-drift.sh check` and confirm everything reports `UP-TO-DATE`
- [x] 4.2 In the same scratch repo, simulate a stale install (revert `SMW_VERSION`-dependent content, keep an old marker), run `check-drift.sh check` and confirm `DRIFT` is reported for the hook piece, then `check-drift.sh update` and confirm it converges to `UP-TO-DATE`
- [x] 4.3 Run `shellcheck` against the modified `executable_check-drift.sh` and confirm no new warnings beyond the pre-existing baseline

## Workflow follow-up

- Run `check-drift.sh update` in this (chezmoi) repo's own working copy if it has `setup-memory-workflow` installed on itself, to dogfood the change before archiving.
- Archive this change once implementation and verification tasks above are complete and reviewed.
- Verify the archived spec delta merges cleanly into `openspec/specs/setup-memory-workflow/spec.md`.
