# Spec Delta

## ADDED Requirements

### Requirement: SessionStart reminder hook includes a bounded status-note excerpt
The `SessionStart` reminder hook SHALL include a size-bounded excerpt of the current-status note's Open items directly in its injected message, derived from a cheap local file read with no MCP call and no new process spawned beyond ordinary local utilities, and SHALL fall back to today's instruction-only message whenever that excerpt cannot be produced.

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

### Requirement: drift-warn surfaces current-status note bloat, not just version drift
The `drift-warn` subcommand SHALL check the current-status note's size, using the `$PROJECT` value it already resolves on every invocation, and SHALL print a suggestion to run `/save-session-maintenance` when it is oversized — in addition to its existing save-session-skill version-drift check. It SHALL NOT invoke `/save-session-maintenance` or any repair itself under any condition.

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
