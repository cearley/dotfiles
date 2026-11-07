# Tasks

## 1. `specstory-dedupe-history` tool

- [x] 1.1 Write `home/dot_local/bin/executable_specstory-dedupe-history` (Python 3): `fd --hidden
      --type d --full-path '\.specstory/history$' <root>` discovery (default root `$HOME`,
      overridable by positional arg); recursive `**/*.md` glob per history dir; group by embedded
      `Claude Code Session <uuid>` / `Session <uuid>` header; for each 2+ group, byte-prefix check
      (smaller file's full bytes vs. the head of the larger file). Verify: run against this repo's
      `.specstory/history/` with no `--apply` and confirm the printed manifest lists all 39 known
      duplicate groups and flags the one known non-prefix pair
      (`2026-10-08_13-31-30Z-i-just-ran-brew.md` / `2026-10-08_13-31-30Z.md`) as a conflict, not a
      safe deletion.
- [x] 1.2 Add `--apply` (performs deletion of confirmed-safe files only) and dry-run-by-default
      behavior (no flag = report only, delete nothing). Verify: run without `--apply` twice in a
      row and confirm zero files are deleted and the manifest is identical both times.
- [x] 1.3 `chezmoi apply` on this Mac, then run `specstory-dedupe-history` (dry-run) from `$HOME`
      and inspect the full manifest before applying. Verify: manifest's byte-reclaim total is
      close to the ~9.7MB estimate from `/research`. **Correction (2026-11-06):** this repo's own
      backlog is actually ~382KB safely reclaimable, not ~9.7MB — see design.md's
      "Post-Implementation Finding" for why. The $HOME-wide run (done, see below) found ~20.5MB
      safely reclaimable across all projects, confirming the tool's real value, just not for the
      reason originally estimated.
- [x] 1.4 Run `specstory-dedupe-history --apply` on this Mac. Verify: re-running the dry-run
      afterward shows zero remaining safe-to-remove duplicates and the one flagged conflict pair
      still present untouched. Verified (2026-11-07): user ran `--apply` against real `$HOME`
      data; subsequent dry-run shows "Safe-to-remove duplicates: none" and all 293 conflict
      pairs (including the originally-flagged `9eef183d-...` pair) present and unchanged.

## 2. Stop hook session-scoping fix

- [x] 2.1 Write `home/dot_local/bin/executable_specstory-sync-session` (plain bash): read
      `session_id` from the hook's stdin JSON via `jq -r '.session_id // empty'`, then run
      `specstory sync claude -s "$SESSION_ID"`. Verify: pipe a synthetic
      `{"session_id": "<real-recent-uuid-from-statistics.json>"}` payload through it by hand and
      confirm it runs the scoped `specstory sync` form (check via `--console` output or
      `statistics.json`'s `last_updated` for just that session).
- [x] 2.2 Edit the `Stop` hook command in all four persona settings files
      (`home/dot_claude/.claude-settings.json`, `home/dot_claude-personal/.claude-settings.json`,
      `home/dot_claude-bedrock/.claude-settings.json`, `home/dot_claude-work/.claude-settings.json`)
      from `"specstory sync --providers claude"` to `"specstory-sync-session"`. Verify:
      `chezmoi diff` shows the intended one-line change in exactly these four files, nothing else.
- [x] 2.3 `chezmoi apply`, then end a trivial real session and confirm via `statistics.json`'s
      `last_updated` field that exactly one file was touched for that session's UUID, with no new
      duplicate file created. Verified (2026-11-07) in `~/work/hcom` (bedrock persona): a fresh
      session's `last_updated` matched its `end_timestamp`, and exactly one history file was
      created (`2026-11-07_16-00-25Z-what-is-2-2.md`), no duplicate. Note: two earlier attempts in
      reused/stale terminal panes showed no sync at all — traced to a stale cached `hcom`
      settings snapshot for that pane (`~/.hcom/integrations/claude/<hash>/settings.json`), not a
      defect in the hook or its chezmoi-managed config (confirmed correct throughout); a genuinely
      fresh pane picked up the change correctly.

## 3. Retire `sync-memory`

- [x] 3.1 In `${CLAUDE_CONFIG_DIR}/skills/setup-memory-workflow/scripts/executable_check-drift.sh`
      (source: `home/dot_claude/skills/setup-memory-workflow/scripts/executable_check-drift.sh`),
      remove the `sync-memory-skill` and `sync-memory-script` pieces from `cmd_check`,
      `cmd_update`, `cmd_apply`, and the usage-comment/piece-name lists. Bump `SMW_VERSION` 15 →
      16. Verify: `check-drift.sh check` in this project no longer prints a `== sync-memory ... ==`
      section, and `check-drift.sh apply sync-memory-skill` now errors as an unknown piece.
- [x] 3.2 Delete `home/dot_claude/skills/setup-memory-workflow/assets/sync-memory-skill.md.template`
      and `home/dot_claude/skills/setup-memory-workflow/scripts/executable_sync-memory.py.template`.
      Verify: `grep -r sync-memory home/dot_claude/skills/setup-memory-workflow/` returns nothing
      outside the CHANGELOG entry added in 3.3. **Gap found and fixed (2026-11-07):** deleting
      the source files doesn't make chezmoi remove the already-*deployed* copies — `chezmoi
      status`/`diff`/`managed` all showed clean while the two old files still sat in
      `~/.claude/skills/setup-memory-workflow/` on this machine. Added `home/.chezmoiremove`
      (chezmoi's declarative mechanism for exactly this) listing both paths; `chezmoi apply`
      confirmed both actually removed. This affects every machine that had the skill deployed
      before this change — see tasks.md's Mac Studio section.
- [x] 3.3 Add a `## v16` entry to
      `home/dot_claude/skills/setup-memory-workflow/CHANGELOG.md` documenting the removal (dormant
      3 months, wrong note target, superseded by the new crash-recovery hook) and the manual
      `rm -rf .claude/skills/sync-memory/` migration step for already-installed projects. Verify:
      entry references `SMW_VERSION 16`. **Upgraded (2026-11-06, user-approved):** rather than a
      manual migration step, added an automated `migrate_sync_memory()` to `migrations.sh`
      (matching this skill's own established convention for legacy-artifact cleanup), wired in
      unconditionally alongside `migrate_hook_config`. Already-installed projects self-heal on
      their next `check-drift.sh check`/`update`/`apply` — no manual `rm -rf` needed.
- [x] 3.4 `chezmoi apply`, then run `check-drift.sh check` in this project and manually
      `rm -rf .claude/skills/sync-memory/ .specstory/.sync-memory-state.json`. Verify: a
      subsequent `check-drift.sh check` run is clean (no errors, no mention of sync-memory).
      Verified (2026-11-07): `chezmoi apply` deployed `SMW_VERSION=16`, `migrate_sync_memory`,
      and the `.chezmoiremove` cleanup from 3.2's note; `check-drift.sh check` in this project
      prints no `== sync-memory ... ==` section and reports `UP-TO-DATE: crash-recovery hook`.
      The manual `rm -rf` had already happened automatically via `migrate_sync_memory()` during
      earlier verification passes.

## 4. Crash-recovery hook

- [x] 4.1 Write `home/dot_claude/skills/setup-memory-workflow/scripts/executable_crash-recovery-hook.sh`
      (static, no chezmoi templating) by adapting
      `~/.claude-personal/skills/setup-memory-workflow/scripts/session-start-maintenance-check.sh.template`
      lines 117–148: keep the stdin JSON parsing, the prior-transcript loop (excluding the
      starting session), and the mtime comparison against `.claude/.last-saved-session`; replace
      the `spawn_headless(...)` call with a plain `echo` of the same catch-up instruction text to
      stdout; drop `spawn_headless()` itself and the unrelated maintenance size-trigger section
      (lines 51–115) entirely. Verify: pipe a synthetic stdin payload (`session_id`,
      `transcript_path` pointing at a scratch dir with one old-mtime fake `.jsonl` and no
      `.last-saved-session` file) through it by hand and confirm it echoes the catch-up
      instruction and exits 0 with no process spawned (`ps` shows nothing new). **Superseded
      (2026-11-07):** code-review found the mtime comparison itself unsound — `touch`ing the
      marker mid-session always makes that session's own transcript mtime advance past the touch
      (the touch's own tool-result write happens after it), so the hook fired on every saved
      session, not just crashed ones. Confirmed via an Alloy model (exhaustive bounded check, no
      counterexample found for the fix). Replaced the mtime comparison with an identity
      comparison: the marker now stores the session ID that last saved (via
      `$CLAUDE_CODE_SESSION_ID`, confirmed available to Bash tool calls), and the hook fires only
      when the latest prior transcript's own session ID doesn't match the marker's content. Also
      more robust than a time-based fix would have been under concurrent same-project sessions
      (per the Alloy model's `identityEqualsFix` check). **Known limitation (2026-11-07,
      accepted):** still no liveness check — a session still genuinely running concurrently in
      the same project directory can be misidentified as crashed. See design.md's Risks section
      for why this was deliberately not built (same-project-same-instant concurrency only;
      failure mode is a harmless spurious catch-up, not data loss). **Fix applied (2026-11-07):**
      a real-world sanity check on the Mac Studio found the catch-up instruction fired correctly
      but the model never surfaced it unprompted — it silently sat on the instruction and kept
      answering normal requests, only revealing it when explicitly asked what system-reminders it
      received. The existing `SYSTEM REMINDER` project-context reminder earns its reliability from
      explicit "before responding to the user... do not skip this" framing; the catch-up text
      never had that. First pass over-corrected: forcing the model to interrupt the user's actual
      first request every time, "even if that message is about something else entirely," turned
      out risky in a way not apparent until a later finding (see 4.5's note on first-install
      false positives) — with the marker freshly deployed across ~30 projects on two machines,
      forced interruption would fire on essentially every project's next session, almost always a
      false positive from the rollout itself, not a real crash. Settled on a middle ground: keep
      "don't silently hold onto it, mention it somewhere in your response" and the explicit
      ask-first gate, but drop the forced-interruption framing — surfacing stays required, timing
      stays the model's judgment call. (No per-project redeployment needed either way — this
      script is the single global static file per Decision 5, so editing it and running
      `chezmoi apply` once per machine updates every project's hook immediately.)
- [x] 4.2 Wire `crash-recovery-hook` into `check-drift.sh` as a new piece, mirroring the existing
      `write-guard-hook` piece exactly: a `== crash-recovery hook ==` section in `cmd_check`/
      `cmd_update`, a case in `cmd_apply`, and a second `SessionStart` hook entry (alongside the
      existing reminder, not merged into its command string) pointing at the fixed global script
      path. Verify: `check-drift.sh check` on a project missing the piece reports `CREATED` and
      adds the entry; a second `check` reports `UP-TO-DATE`.
- [x] 4.3 Edit `home/dot_claude/skills/setup-memory-workflow/assets/save-session-skill.md.template`:
      add `touch .claude/.last-saved-session` to both the Step 0 no-op/skip path and the "On
      success" step. Verify: manually run `/save-session` (or trigger its no-op path on a trivial
      session) and confirm the marker file's mtime advances each time. **Fix applied
      (2026-11-06):** the initial implementation put these touches in Step 0, which ran *before*
      the template's own "Anchor to the project root" section — the exact cwd-drift scenario that
      section exists to guard against, meaning the marker could be touched relative to the wrong
      directory. Reordered the template so "Anchor to the project root" now runs first, before
      Step 0, so every `.claude/...` path (including the marker) is always correctly anchored.
      **Superseded (2026-11-07):** per 4.1's note, `touch` was replaced with
      `echo "$CLAUDE_CODE_SESSION_ID" > .claude/.last-saved-session` at all three sites, so the
      marker records *which* session last saved, not just *when*.
- [x] 4.4 `chezmoi apply` in this project, run `check-drift.sh check` to confirm `crash-recovery-hook`
      reports `CREATED`, then re-run to confirm `UP-TO-DATE`. Verified (2026-11-07): temporarily
      removed just the crash-recovery `SessionStart` entry from `.claude/settings.local.json`
      (leaving the reminder entry untouched), ran `check-drift.sh check` against the
      `chezmoi apply`-deployed global script — reported `CREATED`; ran again — reported
      `UP-TO-DATE`; diffed the regenerated file against a pre-test backup — byte-identical.
- [x] 4.5 End-to-end verification: craft a fake prior transcript with an old mtime and ensure
      `.claude/.last-saved-session` predates it (or doesn't exist); start a fresh session and
      confirm its `SessionStart` hook output includes the catch-up reminder. Separately, run
      `/save-session` normally, confirm the marker's mtime advances, and confirm a subsequent
      `SessionStart` does *not* re-fire the reminder for that same already-saved session.
      Verified (2026-11-07) with three real, live sessions in an isolated scratch project
      (`/tmp/crash-recovery-e2e-test`, cleaned up after): session A (trivial exchange, never
      invoked save-session, no marker written — genuinely "never evaluated"); session B's
      `SessionStart` reminders, read back verbatim by the model itself, included the exact
      catch-up instruction naming session A's transcript path and ID; session B then recorded
      itself as evaluated (`echo "$CLAUDE_CODE_SESSION_ID" > .claude/.last-saved-session`,
      simulating `save-session`'s own marker write without real basic-memory writes for
      throwaway test data); session C's reminders, again read back verbatim, showed no
      catch-up for session B. Both halves of the acceptance criterion confirmed on real,
      unmodified `SessionStart` hook behavior — note the criterion's literal "mtime" framing is
      superseded by the identity-based redesign noted in 4.1/4.3; what was actually verified is
      the content-match mechanism that replaced it. **Real-world confirmation (2026-11-07):** on
      the Mac Studio, the hook fired for session `4d337cc5-...` in the chezmoi project, which had
      genuinely saved correctly — via the *old* save-session template, 5 days before the marker
      mechanism was deployed there at all. This is the known "first install sees pre-existing
      history as a crash" limitation (see design.md's Risks section) occurring exactly as
      predicted: a one-time, self-correcting false positive. The model's own behavior confirmed
      the design worked as intended — it investigated, found nothing new to save, declined to
      create a duplicate entry, and proactively flagged the apparent discrepancy rather than
      silently acting on it. No code change needed for this; it motivated the wording-softening
      in 4.1's note instead (forced interruption would have fired this same false positive on
      every one of the ~30 projects just updated, on their next session).

## 5. Clean up dead leftover files

- [x] 5.1 (this Mac) Delete
      `~/.claude-personal/skills/setup-memory-workflow/scripts/session-start-maintenance-check.sh.template`
      and `~/.claude-personal/skills/setup-memory-workflow/scripts/session-end-save-hook.sh.template`
      — confirmed unreferenced by `check-drift.sh` or any live hook config, and fully superseded
      by task 4's `crash-recovery-hook`. Verify: `grep -rl "session-start-maintenance-check\|session-end-save-hook"`
      across `~/.claude-personal/`, `~/.claude/`, and this repo's `home/` returns nothing.
- [x] 5.2 (Mac Studio) Same deletion as 5.1, run on the Mac Studio: delete
      `~/.claude-personal/skills/setup-memory-workflow/scripts/session-start-maintenance-check.sh.template`
      and `~/.claude-personal/skills/setup-memory-workflow/scripts/session-end-save-hook.sh.template`
      on that machine (confirm first whether they exist there at all — they may be specific to
      this Mac's abandoned `autonomous-save-session` branch work). Verify: same grep as 5.1, run
      on the Mac Studio. Verified (2026-11-07): neither file exists on the Mac Studio (confirmed
      via `ls` returning "No such file or directory" for both) — they really were specific to
      this Mac's abandoned branch history, not something that ever existed there. Nothing to
      delete; task satisfied trivially.

## Workflow follow-up

- Run `openspec validate specstory-cleanup-and-crash-recovery --strict` and `/opsx:verify` before
  archiving.
- Archive the change once all tasks above are checked and verified on this Mac; re-run
  `specstory-dedupe-history --apply` on the Mac Studio after its own `chezmoi apply` picks up the
  new scripts (not a tracked task here — a separate, per-machine manual step).
