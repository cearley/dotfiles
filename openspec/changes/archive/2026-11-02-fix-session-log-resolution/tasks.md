# Tasks

## 1. Fix the canonical template

- [x] 1.1 In `home/dot_claude/skills/setup-memory-workflow/assets/save-session-skill.md.template`,
  reorder so Step 2 (read the current status note) runs before Step 1 (append to the
  session log), and rewrite Step 1 to extract the active session-log note from the last
  wikilink in the status note's most recent Status Summary entry instead of issuing a
  `search_notes` call — falling back to the prior search-based behavior only when no
  wikilink is found. Verify by rendering the template with `sed` substitution (same
  `render()` logic `check-drift.sh` uses) against a scratch `__PROJECT__` value and
  reading the output for correct step order and no leftover unrendered placeholders.
- [x] 1.2 Bump `SMW_VERSION` in
  `home/dot_claude/skills/setup-memory-workflow/scripts/executable_check-drift.sh` and
  confirm with `bash -n` and `shellcheck` that the script is still syntactically and
  lint clean.
- [x] 1.3 Update `home/dot_claude/skills/setup-memory-workflow/CHANGELOG.md` with a new
  version entry describing the incident (title-mode search found the right note; a
  follow-up broader search plus an `updated_at` comparison across stale notes picked the
  wrong one) and the fix, matching the style of the existing v13 entry.
- [x] 1.4 Update `home/dot_claude/skills/setup-memory-workflow/SKILL.md` wherever it
  describes Step 1/Step 2 ordering or behavior, so the rendered skill and the
  skill-authoring doc stay consistent. (Checked: `SKILL.md`'s own "Step 1/Step 2"
  headings describe the unrelated `check-drift.sh` check/repair workflow, not
  `save-session`'s internal steps — nothing there needed changing.)

## 2. Verify the self-heal path on this project

- [x] 2.1 Run `check-drift.sh check` in a scratch git repo seeded with the old-version
  rendered `save-session` skill (same pattern used for the write-guard-hook change) and
  confirm it reports `DRIFT` for `save-session-skill`, then `apply save-session-skill`
  (or `update`) repairs it to the new version marker and new Step ordering/content.
- [x] 2.2 Run `check-drift.sh check` in this repo (`chezmoi` itself, already installed)
  and confirm it reports `DRIFT` for `save-session-skill` at the old `SMW_VERSION`; apply
  the update and confirm a follow-up `check` reports `UP-TO-DATE`.

## 3. Mark the stale chezmoi session-log notes as superseded

- [x] 3.1 Via basic-memory MCP tools (project `chezmoi`), edit each of the five stale
  notes — `sessions/Session Log — 2026-06-03.md`, `2026-07-15.md`, `2026-08-01.md`,
  `2026-08-12.md`, `2026-08-19.md` — adding a clear "superseded by `[[Chezmoi Session
  Notes]]`" marker near the top of each, consistent with the `Status Archive —
  2026-08-17` precedent. Verify by reading each note back and confirming the marker is
  present and the note's own content/history is otherwise untouched.
- [x] 3.2 Confirm none of the five notes' permalinks or titles changed (archive-never-
  delete convention — this is a content edit, not a move), by comparing permalinks
  before and after.

## 4. Final verification

- [x] 4.1 `openspec validate fix-session-log-resolution --strict` passes clean.
- [x] 4.2 Re-read the rendered `save-session-skill.md.template` output end-to-end (not
  just the diffed section) to confirm Step 1/Step 2 read naturally in the new order and
  no other step references the old ordering.

## Workflow follow-up

- Sync the `setup-memory-workflow` spec delta into the main spec (`openspec sync` /
  `/opsx:sync`), then archive the change: `openspec archive fix-session-log-resolution --yes`.
- Verify the archived result (`/opsx:verify` or equivalent) before considering this done.
