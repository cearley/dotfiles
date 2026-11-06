# Tasks

## 1. `specstory-dedupe-history` tool

- [ ] 1.1 Write `home/dot_local/bin/executable_specstory-dedupe-history` (Python 3): `fd --hidden
      --type d --full-path '\.specstory/history$' <root>` discovery (default root `$HOME`,
      overridable by positional arg); recursive `**/*.md` glob per history dir; group by embedded
      `Claude Code Session <uuid>` / `Session <uuid>` header; for each 2+ group, byte-prefix check
      (smaller file's full bytes vs. the head of the larger file). Verify: run against this repo's
      `.specstory/history/` with no `--apply` and confirm the printed manifest lists all 39 known
      duplicate groups and flags the one known non-prefix pair
      (`2026-10-08_13-31-30Z-i-just-ran-brew.md` / `2026-10-08_13-31-30Z.md`) as a conflict, not a
      safe deletion.
- [ ] 1.2 Add `--apply` (performs deletion of confirmed-safe files only) and dry-run-by-default
      behavior (no flag = report only, delete nothing). Verify: run without `--apply` twice in a
      row and confirm zero files are deleted and the manifest is identical both times.
- [ ] 1.3 `chezmoi apply` on this Mac, then run `specstory-dedupe-history` (dry-run) from `$HOME`
      and inspect the full manifest before applying. Verify: manifest's byte-reclaim total is
      close to the ~9.7MB estimate from `/research`.
- [ ] 1.4 Run `specstory-dedupe-history --apply` on this Mac. Verify: re-running the dry-run
      afterward shows zero remaining safe-to-remove duplicates and the one flagged conflict pair
      still present untouched.

## 2. Stop hook session-scoping fix

- [ ] 2.1 Write `home/dot_local/bin/executable_specstory-sync-session` (plain bash): read
      `session_id` from the hook's stdin JSON via `jq -r '.session_id // empty'`, then run
      `specstory sync claude -s "$SESSION_ID"`. Verify: pipe a synthetic
      `{"session_id": "<real-recent-uuid-from-statistics.json>"}` payload through it by hand and
      confirm it runs the scoped `specstory sync` form (check via `--console` output or
      `statistics.json`'s `last_updated` for just that session).
- [ ] 2.2 Edit the `Stop` hook command in all four persona settings files
      (`home/dot_claude/.claude-settings.json`, `home/dot_claude-personal/.claude-settings.json`,
      `home/dot_claude-bedrock/.claude-settings.json`, `home/dot_claude-work/.claude-settings.json`)
      from `"specstory sync --providers claude"` to `"specstory-sync-session"`. Verify:
      `chezmoi diff` shows the intended one-line change in exactly these four files, nothing else.
- [ ] 2.3 `chezmoi apply`, then end a trivial real session and confirm via `statistics.json`'s
      `last_updated` field that exactly one file was touched for that session's UUID, with no new
      duplicate file created.

## 3. Retire `sync-memory`

- [ ] 3.1 In `${CLAUDE_CONFIG_DIR}/skills/setup-memory-workflow/scripts/executable_check-drift.sh`
      (source: `home/dot_claude/skills/setup-memory-workflow/scripts/executable_check-drift.sh`),
      remove the `sync-memory-skill` and `sync-memory-script` pieces from `cmd_check`,
      `cmd_update`, `cmd_apply`, and the usage-comment/piece-name lists. Bump `SMW_VERSION` 15 →
      16. Verify: `check-drift.sh check` in this project no longer prints a `== sync-memory ... ==`
      section, and `check-drift.sh apply sync-memory-skill` now errors as an unknown piece.
- [ ] 3.2 Delete `home/dot_claude/skills/setup-memory-workflow/assets/sync-memory-skill.md.template`
      and `home/dot_claude/skills/setup-memory-workflow/scripts/executable_sync-memory.py.template`.
      Verify: `grep -r sync-memory home/dot_claude/skills/setup-memory-workflow/` returns nothing
      outside the CHANGELOG entry added in 3.3.
- [ ] 3.3 Add a `## v16` entry to
      `home/dot_claude/skills/setup-memory-workflow/CHANGELOG.md` documenting the removal (dormant
      3 months, wrong note target, superseded by the new crash-recovery hook) and the manual
      `rm -rf .claude/skills/sync-memory/` migration step for already-installed projects. Verify:
      entry references `SMW_VERSION 16`.
- [ ] 3.4 `chezmoi apply`, then run `check-drift.sh check` in this project and manually
      `rm -rf .claude/skills/sync-memory/ .specstory/.sync-memory-state.json`. Verify: a
      subsequent `check-drift.sh check` run is clean (no errors, no mention of sync-memory).

## 4. Crash-recovery hook

- [ ] 4.1 Write `home/dot_claude/skills/setup-memory-workflow/scripts/executable_crash-recovery-hook.sh`
      (static, no chezmoi templating) by adapting
      `~/.claude-personal/skills/setup-memory-workflow/scripts/session-start-maintenance-check.sh.template`
      lines 117–148: keep the stdin JSON parsing, the prior-transcript loop (excluding the
      starting session), and the mtime comparison against `.claude/.last-saved-session`; replace
      the `spawn_headless(...)` call with a plain `echo` of the same catch-up instruction text to
      stdout; drop `spawn_headless()` itself and the unrelated maintenance size-trigger section
      (lines 51–115) entirely. Verify: pipe a synthetic stdin payload (`session_id`,
      `transcript_path` pointing at a scratch dir with one old-mtime fake `.jsonl` and no
      `.last-saved-session` file) through it by hand and confirm it echoes the catch-up
      instruction and exits 0 with no process spawned (`ps` shows nothing new).
- [ ] 4.2 Wire `crash-recovery-hook` into `check-drift.sh` as a new piece, mirroring the existing
      `write-guard-hook` piece exactly: a `== crash-recovery hook ==` section in `cmd_check`/
      `cmd_update`, a case in `cmd_apply`, and a second `SessionStart` hook entry (alongside the
      existing reminder, not merged into its command string) pointing at the fixed global script
      path. Verify: `check-drift.sh check` on a project missing the piece reports `CREATED` and
      adds the entry; a second `check` reports `UP-TO-DATE`.
- [ ] 4.3 Edit `home/dot_claude/skills/setup-memory-workflow/assets/save-session-skill.md.template`:
      add `touch .claude/.last-saved-session` to both the Step 0 no-op/skip path and the "On
      success" step. Verify: manually run `/save-session` (or trigger its no-op path on a trivial
      session) and confirm the marker file's mtime advances each time.
- [ ] 4.4 `chezmoi apply` in this project, run `check-drift.sh check` to confirm `crash-recovery-hook`
      reports `CREATED`, then re-run to confirm `UP-TO-DATE`.
- [ ] 4.5 End-to-end verification: craft a fake prior transcript with an old mtime and ensure
      `.claude/.last-saved-session` predates it (or doesn't exist); start a fresh session and
      confirm its `SessionStart` hook output includes the catch-up reminder. Separately, run
      `/save-session` normally, confirm the marker's mtime advances, and confirm a subsequent
      `SessionStart` does *not* re-fire the reminder for that same already-saved session.

## 5. Clean up dead leftover files

- [ ] 5.1 Delete
      `~/.claude-personal/skills/setup-memory-workflow/scripts/session-start-maintenance-check.sh.template`
      and `~/.claude-personal/skills/setup-memory-workflow/scripts/session-end-save-hook.sh.template`
      — confirmed unreferenced by `check-drift.sh` or any live hook config, and fully superseded
      by task 4's `crash-recovery-hook`. Verify: `grep -rl "session-start-maintenance-check\|session-end-save-hook"`
      across `~/.claude-personal/`, `~/.claude/`, and this repo's `home/` returns nothing.

## Workflow follow-up

- Run `openspec validate specstory-cleanup-and-crash-recovery --strict` and `/opsx:verify` before
  archiving.
- Archive the change once all tasks above are checked and verified on this Mac; re-run
  `specstory-dedupe-history --apply` on the Mac Studio after its own `chezmoi apply` picks up the
  new scripts (not a tracked task here — a separate, per-machine manual step).
