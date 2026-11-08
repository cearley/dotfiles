# Spec Delta

## MODIFIED Requirements

### Requirement: Project identity is resolved once, at apply-time
`check-drift.sh` SHALL resolve the current project's basic-memory identity once per invocation, at the top of the script, and use that single resolved value for every piece it renders or checks in that invocation. No per-project-templated installed piece SHALL contain a runtime identity-resolution script or instruction. The `SessionStart` reminder hook's own script is a deliberate exception — see its scenario below — because its whole purpose is reading live content that cannot be pre-rendered.

#### Scenario: Default resolution
- **WHEN** `check-drift.sh` runs inside a git repository with no override file present
- **THEN** it resolves `$PROJECT` as the `basename` of `git rev-parse --show-toplevel`

#### Scenario: Override file present
- **WHEN** `<project-root>/.claude/basic-memory-project.txt` exists and contains non-blank content
- **THEN** `check-drift.sh` resolves `$PROJECT` as that file's content instead of the git-basename default

#### Scenario: Override file blank or whitespace-only
- **WHEN** `<project-root>/.claude/basic-memory-project.txt` exists but is empty or contains only whitespace
- **THEN** `check-drift.sh` falls through to the git-basename default, treating the file as if it were absent

#### Scenario: Not inside a git repository
- **WHEN** `check-drift.sh` runs outside any git repository
- **THEN** it resolves `$PROJECT_ROOT` as the current working directory rather than exiting — this matches `git rev-parse --show-toplevel`'s own fallback behavior in the script, so the workflow degrades to treating the current directory as the project root rather than failing outright

#### Scenario: SessionStart reminder script resolves identity at runtime, by design
- **WHEN** the `SessionStart` reminder hook's script runs at session start
- **THEN** it resolves `$PROJECT` itself, at that moment, using the same override-file-then-git-basename logic — this is a deliberate exception to the apply-time-only rule, required because the script reads live note content that no apply-time rendering step could have produced

### Requirement: Skill is distributed as per-project rendered copies, not a shared reference
The `save-session` skill and the `SessionStart` write-guard and crash-recovery hook *entries* SHALL each be rendered from a canonical template into the target project's own `.claude/` directory (or `.claude/settings.local.json`, for hook entries), with a version marker (`setup-memory-workflow-version:N`) embedded in each rendered piece. The `crash-recovery-hook`, `PreToolUse` write-guard hook, and `SessionStart` reminder hook are deliberate exceptions to the version-marker part of this guarantee — see their own scenarios below.

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
- **THEN** it does not apply to that piece — the guard script itself is a single, static file deployed machine-wide (not rendered per project) and carries no `setup-memory-workflow-version:N` marker; only the fixed hook *entry* pointing at it is managed per project, and its drift is detected by literal command-string comparison instead (see the dedicated "PreToolUse write-guard hook" requirement)

#### Scenario: Crash-recovery hook is a deliberate exception
- **WHEN** this requirement's version-marker guarantee is considered against the `crash-recovery-hook` `SessionStart` entry
- **THEN** it does not apply to that piece either, for the same reason as the `PreToolUse` write-guard hook: the script itself is static and deployed machine-wide, with no project-specific substitution needed, and only the fixed hook *entry* pointing at it is tracked per project

#### Scenario: SessionStart reminder hook is a deliberate exception
- **WHEN** this requirement's version-marker guarantee is considered against the `SessionStart` reminder hook entry
- **THEN** it does not apply to that piece either: the reminder hook's script is a single, static, non-templated file deployed machine-wide, resolving `$PROJECT` and the status note path itself at runtime (see the "Project identity" requirement's exception above) — only the fixed hook entry pointing at it is tracked per project, by literal command-string comparison, the same as the write-guard and crash-recovery-hook entries

#### Scenario: Upgrading from a prior version replaces the legacy reminder hook without duplicating it
- **WHEN** a project's installed `SessionStart` hooks include a legacy reminder entry from before this version (a per-project-rendered `echo` command containing baked note content) and `check-drift.sh update` runs
- **THEN** the legacy entry is removed and the new canonical static reminder-hook entry is present exactly once — never both, and never a second copy of the canonical entry

## REMOVED Requirements

### Requirement: SessionStart reminder hook includes a bounded status-note excerpt
**Reason**: This requirement specified baking a status-note excerpt into the hook's command string at `check-drift.sh update` time. In practice this produced unbounded config-file bloat (a real installed hook command measured at 6344 bytes, versus 894 with no excerpt) and a frozen, stale snapshot rather than live content, with quote-escaping further inflating size on every apostrophe in the note.
**Migration**: Replaced by "SessionStart reminder hook reads the status-note excerpt live" below, which preserves the same user-visible outcome (the reminder includes an Open-items excerpt) through a mechanically different, safer path: the excerpt is read from disk at session start, never baked into `.claude/settings.local.json`. The `STALE-EXCERPT` check-drift state this requirement introduced no longer exists — there is nothing left that can go stale in that way.

### Requirement: drift-warn surfaces current-status note bloat, not just version drift
**Reason**: `check-drift.sh` (including its `drift-warn` subcommand) is scoped to drift detection for the skill's own versioned files, templates, and hook wiring only — current-status-note and session-log bloat are memory-content concerns, not skill-file concerns, and belong with the script that already owns reading that content.
**Migration**: The same two bloat signals, with the same thresholds, are now produced by the `SessionStart` reminder hook's own script every time a session starts (see "SessionStart reminder hook surfaces current-status note bloat" and "SessionStart reminder hook surfaces session-log note bloat" below), rather than only when `check-drift.sh drift-warn` happened to run as part of the reminder hook's old combined command.

## ADDED Requirements

### Requirement: SessionStart reminder hook reads the status-note excerpt live
The `SessionStart` reminder hook SHALL produce its status-note Open-items excerpt by reading the note's file directly when the session starts, never from a value stored in `.claude/settings.local.json`, and SHALL fall back to an instruction-only message when no excerpt can be produced.

#### Scenario: Status note readable and under the excerpt size cap
- **WHEN** a session starts and the resolved status note's Open-items excerpt is at or under the fixed size cap
- **THEN** the injected reminder includes that excerpt, captured as of the current session's start

#### Scenario: Excerpt exceeds the size cap
- **WHEN** the Open-items section is larger than the fixed excerpt size cap
- **THEN** the hook truncates the excerpt to the cap with a visible truncation indicator

#### Scenario: Status note missing or unreadable
- **WHEN** no status note can be resolved, or the resolved file cannot be read
- **THEN** the hook emits an instruction-only reminder message, with no error surfaced beyond that

#### Scenario: Excerpt is never read from settings.local.json or an MCP call
- **WHEN** the excerpt is produced
- **THEN** it comes from a direct read of the note's file on disk, not from any value written into `.claude/settings.local.json` and not from any MCP tool call

#### Scenario: The hook command itself never varies with note content
- **WHEN** `check-drift.sh check` or `update` compares the installed reminder hook entry against canonical
- **THEN** it compares a single fixed command string, unaffected by the current-status note's size or content

### Requirement: SessionStart reminder hook frames itself as deferential background context
The `SessionStart` reminder, including any excerpt, SHALL be framed as background context the user's current input takes precedence over, and SHALL condition a `search_notes`/`recent_activity` call on the excerpt being insufficient rather than commanding it unconditionally.

#### Scenario: Reminder defers to current user input
- **WHEN** the reminder would otherwise conflict with the user's current request or the model's in-progress task
- **THEN** its wording explicitly defers to that current input rather than commanding an action that must complete first

#### Scenario: Direct resume or status-request phrasing overrides the default
- **WHEN** the user's message uses direct resume or status-request language (for example, "what's the current status," "where did we leave off," "let's resume/continue")
- **THEN** the reminder's own wording names this phrasing as overriding the "only if insufficient" default for calling `search_notes`/`recent_activity`

### Requirement: SessionStart reminder hook surfaces current-status note bloat
The `SessionStart` reminder hook SHALL print a suggestion to run `/save-session-maintenance` when the resolved current-status note is at or over `save-session-maintenance`'s own size thresholds, and SHALL NOT perform any repair itself.

#### Scenario: Current-status note is bloated
- **WHEN** the resolved current-status note's total size or any single entry is at or over its threshold
- **THEN** the hook prints a line suggesting `/save-session-maintenance`, in addition to the Open-items excerpt

#### Scenario: Current-status note is not bloated
- **WHEN** the threshold is not crossed
- **THEN** the hook prints nothing for this signal

#### Scenario: Hook never performs the maintenance itself
- **WHEN** the hook detects the note is bloated
- **THEN** it only prints a suggestion — it never invokes `/save-session-maintenance` or any other remediation on its own

### Requirement: SessionStart reminder hook surfaces session-log note bloat
The `SessionStart` reminder hook SHALL print a suggestion to run `/save-session-maintenance` when the active session-log note (the most recently modified note under the project's `sessions/` directory) is at or over `save-session-maintenance`'s rollover threshold, independent of the current-status-note-bloat signal.

#### Scenario: Active session-log note is bloated
- **WHEN** the active session-log note is at or over the rollover threshold
- **THEN** the hook prints a line suggesting `/save-session-maintenance`, independent of whatever the current-status-note-bloat signal prints

#### Scenario: Active session-log note is not bloated
- **WHEN** the active session-log note is under the threshold
- **THEN** the hook prints nothing for this signal

#### Scenario: No session-log note exists yet
- **WHEN** the project's `sessions/` directory is missing or contains no notes
- **THEN** the hook prints nothing for this signal and does not error

### Requirement: Status note canonical path is pinned, not freely chosen
The status note's location SHALL resolve first by an exact path, `status/<project>-current-status.md`, rather than whatever title or location a model chose when the note was first created. A broader fallback glob SHALL be used only when the canonical path does not exist, and a note found only via fallback SHALL be flagged as non-canonical. The workflow SHALL NOT automatically move, rename, or merge any existing note.

#### Scenario: Note already at the canonical path
- **WHEN** a status note exists at `status/<project>-current-status.md`
- **THEN** the reminder hook reads it directly, with no fallback glob and no non-canonical notice

#### Scenario: Note found only via fallback
- **WHEN** no note exists at the canonical path, but one is found via the broader fallback glob under `status/`
- **THEN** the reminder hook reads that note and appends a one-line notice naming the canonical path it could be moved to

#### Scenario: Note not found by either method
- **WHEN** neither the canonical path nor the fallback glob matches anything
- **THEN** the reminder hook prints no excerpt and no non-canonical notice

#### Scenario: Existing note is never auto-moved
- **WHEN** a non-canonical note is detected
- **THEN** no file is moved, renamed, merged, or otherwise mutated by the workflow

### Requirement: SessionStart reminder hook never writes to the basic-memory notes tree
The `SessionStart` reminder hook's script SHALL only read files under the basic-memory notes tree, never create, write, or modify any file there, under any condition, and SHALL exit 0 regardless of what it finds.

#### Scenario: No status note exists anywhere
- **WHEN** the reminder hook finds no status note at the canonical path or via fallback
- **THEN** it does not create one — it degrades to printing no excerpt

#### Scenario: Hook exits zero regardless of what it finds
- **WHEN** the reminder hook runs under any outcome — note found canonically, found via fallback, or not found at all
- **THEN** it exits 0 in every case
