# Spec Delta

## MODIFIED Requirements

### Requirement: Skill is distributed as per-project rendered copies, not a shared reference
The `save-session` skill and the `SessionStart` hook configuration SHALL each be rendered from a canonical template into the target project's own `.claude/` directory (or `.claude/settings.local.json`, for the hook), with a version marker (`setup-memory-workflow-version:N`) embedded in each rendered piece. The `crash-recovery-hook` and `PreToolUse` write-guard hook are deliberate exceptions to the version-marker part of this guarantee — see their own scenario below.

#### Scenario: Missing piece is created unconditionally
- **WHEN** `check-drift.sh check` finds a piece (skill file, script, hook entry, or `.mcp.json` entry) missing from the current project
- **THEN** it renders the current canonical template into place directly — creating a missing piece is always safe and requires no confirmation

#### Scenario: Two projects have independent copies
- **WHEN** the workflow is installed in two different projects
- **THEN** each project has its own physically separate rendered files — editing one project's installed copy has no effect on the other

#### Scenario: One canonical copy serves every enabled project
- **WHEN** considering the retired plugin-era guarantee this scenario originally described — that two projects with the plugin enabled ran the exact same shared skill/hook content, with no per-project rendered copy of any of it
- **THEN** it is deliberately inverted, not preserved: each project now has its own independently rendered copy (see "Two projects have independent copies" above) — this is the whole point of returning to a copy-based distribution, since a single shared copy is exactly what made runtime `$PROJECT` resolution necessary and skippable in the first place

#### Scenario: Updating the plugin updates every consumer
- **WHEN** considering the retired plugin-era guarantee this scenario originally described — that changing the canonical plugin content and updating the marketplace propagated to every enabled project automatically, with no per-project drift-check or repair step
- **THEN** it is deliberately inverted, not preserved: canonical template changes now reach an installed project only when `check-drift.sh update` (or `apply`) is explicitly run there — propagation is opt-in and per-project again, in exchange for eliminating the plugin's own weaker update story (a commit-SHA-pinned cache with no `needsUpdate` signal, confirmed stale on a real install during this change's own investigation)

#### Scenario: PreToolUse write-guard hook is a deliberate exception
- **WHEN** this requirement's version-marker guarantee is considered against the `PreToolUse` write-guard hook
- **THEN** it does not apply to that piece — the guard script itself is a single, static file deployed machine-wide (not rendered per project) and carries no `setup-memory-workflow-version:N` marker; only the fixed hook *entry* pointing at it is managed per project, and its drift is detected by literal command-string comparison instead (see the dedicated "PreToolUse write-guard hook" requirement below)

#### Scenario: Crash-recovery hook is a deliberate exception
- **WHEN** this requirement's version-marker guarantee is considered against the `crash-recovery-hook` `SessionStart` entry
- **THEN** it does not apply to that piece either, for the same reason as the `PreToolUse` write-guard hook: the script itself is static and deployed machine-wide, with no project-specific substitution needed, and only the fixed hook *entry* pointing at it is tracked per project

## REMOVED Requirements

### Requirement: `sync-memory` pieces are part of the distributed set
**Reason**: `sync-memory` is retired as a capability entirely (see the `sync-memory` spec delta in this same change) — nothing in `setup-memory-workflow` distributes it any longer.
**Migration**: An existing installed project should `rm -rf .claude/skills/sync-memory/`; `check-drift.sh` no longer checks for, creates, or repairs any `sync-memory-*` piece.

## ADDED Requirements

### Requirement: Crash-recovery hook detects a session that ended without a completed save
A `SessionStart` hook piece (`crash-recovery-hook`) SHALL detect, without spawning any new process, when the most recent prior session's transcript was not the session that last completed `save-session`'s own evaluation for this project (by session-ID identity, not transcript mtime — an earlier mtime-based design was proven unsound), and SHALL surface a catch-up instruction to the current session via hook stdout rather than performing the save itself.

#### Scenario: Prior session has no completed save
- **WHEN** a new session starts and the most recent prior session transcript's (excluding the session now starting) own session ID does not match the session ID recorded in `.claude/.last-saved-session`
- **THEN** the hook prints a catch-up instruction to stdout naming that prior transcript's path, which Claude Code injects as a system-reminder into the current, already-running session — no `claude -p` or any other new process is spawned

#### Scenario: Prior session was already saved
- **WHEN** a new session starts and the most recent prior session transcript's session ID matches the session ID recorded in `.claude/.last-saved-session`
- **THEN** the hook prints nothing and exits zero

#### Scenario: save-session marks its own completion
- **WHEN** `save-session` reaches either its "On success" step or its Step 0 no-op/skip outcome
- **THEN** it writes its own `$CLAUDE_CODE_SESSION_ID` into `.claude/.last-saved-session` (content, not just mtime), so a normal completed evaluation (saved or legitimately skipped) always advances the identity the crash-recovery hook compares against

#### Scenario: Currently-starting session is excluded
- **WHEN** the crash-recovery hook scans prior transcripts in the same directory as the session now starting
- **THEN** it excludes the transcript whose filename matches the current session's own `session_id`
