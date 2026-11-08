# Spec Delta

## MODIFIED Requirements

### Requirement: SessionStart reminder hook includes a bounded status-note excerpt
The `SessionStart` reminder hook SHALL include a size-bounded excerpt of the current-status note's Open items directly in its injected message, derived from a cheap local file read with no MCP call and no new process spawned beyond ordinary local utilities, and SHALL fall back to today's instruction-only message whenever that excerpt cannot be produced. When the excerpt is non-empty, the injected message SHALL also state the date the excerpt was captured. `check-drift.sh check` SHALL report a change limited to the excerpt's own content — the rendered hook command's embedded `setup-memory-workflow-version:N` marker unchanged — as a distinct `STALE-EXCERPT` state, separate from `DRIFT`. The injected message, including the excerpt, SHALL be framed as background context that current user or tool input takes precedence over, not as a directive that must be completed before anything else. The message SHALL condition its instruction to call `search_notes`/`recent_activity` on the excerpt being insufficient, rather than commanding that call unconditionally, and SHALL name user phrasing that indicates a direct resume or status request as overriding that default.

#### Scenario: Status note readable and under the excerpt size cap
- **WHEN** a session starts and the project's current-status note file is present and its Open-items excerpt is at or under the fixed size cap
- **THEN** the injected reminder includes that excerpt in addition to the existing instruction to call `search_notes`/`recent_activity`

#### Scenario: Excerpt exceeds the size cap
- **WHEN** the Open-items section is larger than the fixed excerpt size cap
- **THEN** the hook truncates the excerpt to the cap with a visible truncation indicator, rather than growing the injected message unbounded or failing

#### Scenario: Status note missing or unreadable
- **WHEN** the current-status note file cannot be found or read at the expected local path
- **THEN** the hook emits today's instruction-only reminder message, unchanged, with no error surfaced beyond that — this is purely additive and never regresses the existing behavior

#### Scenario: Excerpt reflects only local file state, never a live query
- **WHEN** the excerpt is produced
- **THEN** it is read directly from the note's file on disk under `~/.local/share/basic-memory/`, not retrieved via any MCP tool call or other query that could block or spawn a process

#### Scenario: Excerpt includes its capture date
- **WHEN** the excerpt is non-empty
- **THEN** the injected message states the date the excerpt was captured, so a reader can judge how fresh it might be without the excerpt itself being recomputed live

#### Scenario: check distinguishes an excerpt-only change from real template drift
- **WHEN** `check-drift.sh check` finds the installed hook command's embedded version marker matches the current `SMW_VERSION`, but the full command string still differs from canonical because only the baked excerpt text (or its capture date) changed
- **THEN** it reports `STALE-EXCERPT`, not `DRIFT`, for that piece — `check-drift.sh update` still repairs it the same unconditional way `DRIFT` is repaired

#### Scenario: Real version or template drift still reports DRIFT
- **WHEN** the installed hook command's embedded version marker differs from the current `SMW_VERSION`, regardless of what the excerpt contains
- **THEN** `check-drift.sh check` reports `DRIFT`, not `STALE-EXCERPT`, consistent with every other templated piece

#### Scenario: Reminder is framed as background context, not a directive that overrides current input
- **WHEN** the `SessionStart` reminder (including any excerpt) would otherwise conflict with the user's current request or the model's in-progress task
- **THEN** the reminder's wording explicitly defers to current user and tool input, rather than commanding an action that must be completed first

#### Scenario: Real memory retrieval is conditional on the excerpt's sufficiency
- **WHEN** the injected excerpt (with its capture date) already covers what the current turn needs
- **THEN** the reminder's wording does not command an unconditional `search_notes`/`recent_activity` call — it names that call as something to make only if the excerpt turns out to be insufficient, stale, or missing

#### Scenario: Direct resume or status-request phrasing overrides the default
- **WHEN** the user's message uses direct resume or status-request language (for example, "what's the current status," "where did we leave off," "let's resume/continue")
- **THEN** the reminder's own wording names this kind of phrasing as a signal that should override the "only if insufficient" default, prompting the real `search_notes`/`recent_activity` call regardless of how fresh the excerpt looks — detected by the model reading the user's message in the same turn, with no additional hook or runtime mechanism

### Requirement: drift-warn surfaces current-status note bloat, not just version drift
The `drift-warn` subcommand SHALL check both the current-status note's size and the active session-log note's size, using the `$PROJECT` value it already resolves on every invocation, and SHALL print a suggestion to run `/save-session-maintenance` when either is oversized — in addition to its existing save-session-skill version-drift check. It SHALL NOT invoke `/save-session-maintenance` or any repair itself under any condition.

#### Scenario: Current-status note is bloated
- **WHEN** `drift-warn` runs and the current-status note's total size or any single entry is at or over the same thresholds `save-session-maintenance` already defines (total size roughly 8,000 characters or 200 lines, or any single entry roughly 800 characters)
- **THEN** it prints a line suggesting `/save-session-maintenance`, in addition to (not instead of) its existing version-drift line if that also applies

#### Scenario: Current-status note is not bloated
- **WHEN** `drift-warn` runs and none of the note-bloat thresholds are crossed
- **THEN** it prints nothing for this signal (independent of whatever the version-drift check prints)

#### Scenario: drift-warn never performs the maintenance itself
- **WHEN** `drift-warn` detects bloat
- **THEN** it only prints a suggestion — it never invokes `/save-session-maintenance`, `check-drift.sh update`, or any other remediation on its own

#### Scenario: No new identity resolution is introduced
- **WHEN** `drift-warn` evaluates the note-bloat signal
- **THEN** it uses the same `$PROJECT` value `resolve_project()` already computes at the top of every `check-drift.sh` invocation — no new or additional identity resolution path is added for this signal

#### Scenario: Active session-log note is bloated
- **WHEN** `drift-warn` runs and the active session-log note — the most recently modified note under the project's `sessions/` directory — is at or over `save-session-maintenance`'s own session-log rollover threshold (300 lines)
- **THEN** it prints a line suggesting `/save-session-maintenance`, independent of (and in addition to) whatever the current-status-note-bloat and version-drift lines print

#### Scenario: Active session-log note is not bloated
- **WHEN** `drift-warn` runs and the active session-log note is under the rollover threshold
- **THEN** it prints nothing for this signal

#### Scenario: No session-log note exists yet
- **WHEN** `drift-warn` runs and the project's `sessions/` directory under basic-memory is missing or contains no notes
- **THEN** it prints nothing for this signal and exits 0, degrading the same way every other signal in this subcommand does when its input is absent

#### Scenario: Active log identified by recency, not by re-parsing note content
- **WHEN** `drift-warn` evaluates the session-log bloat signal
- **THEN** it identifies the active session-log note as the most recently modified file under the project's `sessions/` directory, rather than re-deriving it from the current-status note's wikilinks — the resolution mechanism `save-session`'s own Step 1 uses — so this signal does not carry a second, independently fallible reimplementation of that resolution logic into a hook context with no MCP access to verify it

### Requirement: Crash-recovery hook detects a session that ended without a completed save
A `SessionStart` hook piece (`crash-recovery-hook`) SHALL detect, without spawning any new process, when the most recent prior session's transcript has more unsaved real user turns than a fixed threshold since the session that last completed `save-session`'s own evaluation for this project (by session-ID identity combined with a recorded turn-count checkpoint, not transcript mtime — an earlier mtime-based design was proven unsound), and SHALL surface a catch-up instruction to the current session via hook stdout rather than performing the save itself.

#### Scenario: Prior session has no completed save
- **WHEN** a new session starts and the most recent prior session transcript's (excluding the session now starting) count of unsaved real user turns — the transcript's total real-user-turn count minus the turn-count recorded in `.claude/.last-saved-session` if that transcript's session ID matches the marker's recorded session ID, or the full total if it doesn't match (never saved at all) — exceeds the fixed threshold
- **THEN** the hook prints a catch-up instruction to stdout naming that prior transcript's path, which Claude Code injects as a system-reminder into the current, already-running session — no `claude -p` or any other new process is spawned

#### Scenario: Prior session was already saved
- **WHEN** a new session starts and the most recent prior session transcript's count of unsaved real user turns (computed the same way) is at or under the fixed threshold
- **THEN** the hook prints nothing and exits zero — this covers both a session that was fully saved and a small session (for example, one ended by `/clear` shortly after it began) that was never saved at all but has too little at stake to be worth a reminder

#### Scenario: A session that saves early and keeps going past the threshold still fires
- **WHEN** a session's most recent save recorded a turn-count checkpoint, and that same session (same session ID) continues for more than the threshold's worth of additional real user turns before ending without saving again
- **THEN** the hook still fires for that session on the next session start, even though its session ID matches the one recorded in `.claude/.last-saved-session` — session-ID identity alone is no longer sufficient to mean "fully covered"

#### Scenario: save-session marks its own completion
- **WHEN** `save-session` reaches either its "On success" step or its Step 0 no-op/skip outcome
- **THEN** it writes `$CLAUDE_CODE_SESSION_ID:$TURN_COUNT` into `.claude/.last-saved-session` (content, not just mtime), where `$TURN_COUNT` is the number of real user turns in the current transcript at that moment, so a normal completed evaluation (saved or legitimately skipped) always advances both the identity and the checkpoint the crash-recovery hook compares against

#### Scenario: An older marker with no recorded turn-count degrades to zero, not an error
- **WHEN** `.claude/.last-saved-session` contains a bare session ID with no `:turn_count` suffix (written before this behavior existed)
- **THEN** the hook treats the missing turn-count as zero rather than erroring, self-healing the next time any marker-writing spot in `save-session` runs again

#### Scenario: Currently-starting session is excluded
- **WHEN** the crash-recovery hook scans prior transcripts in the same directory as the session now starting
- **THEN** it excludes the transcript whose filename matches the current session's own `session_id`
