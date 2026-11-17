# Spec Delta

## ADDED Requirements

### Requirement: Status Summary entries are capped at a fixed length
Each new dated entry added to the current-status note's `## Status Summary` section SHALL be
limited to a fixed hard line count. Full narrative detail for that session SHALL be recorded
only in the session log, referenced from the capped entry via a `Detail: [[...]]` link.

#### Scenario: Routine save with a long session
- **WHEN** `/save-session`'s Step 1 writes a new Status Summary entry for a session with
  substantial narrative detail
- **THEN** the entry text added to the current-status note SHALL NOT exceed the fixed hard line
  limit, and the full narrative SHALL appear in the session log entry linked via
  `Detail: [[...]]`

### Requirement: Save-session gates further status-note growth once oversized
`/save-session`'s Step 1 SHALL check the current-status note against its existing three-signal
oversized check (at or over 8,000 characters, at or over 200 lines, or any single line at or
over 800 characters) before writing a new Status Summary entry. If any signal is already true,
Step 1 SHALL write only a short pointer entry noting the save occurred and that maintenance is
needed, and SHALL NOT add further narrative content, until `/save-session-maintenance` has run.

#### Scenario: Status note is already oversized at save time
- **WHEN** `/save-session`'s Step 1 evaluates a current-status note that already meets or
  exceeds any of the three oversized signals
- **THEN** Step 1 SHALL write only a short pointer entry instead of a full narrative entry, and
  SHALL NOT bypass the gate regardless of how many sessions have passed since the last
  maintenance run

#### Scenario: Status note is under threshold at save time
- **WHEN** `/save-session`'s Step 1 evaluates a current-status note under all three oversized
  signals
- **THEN** Step 1 SHALL write a normal capped Status Summary entry as usual

### Requirement: Save-session Preflight checks identity via authorize only
`/save-session`'s Preflight SHALL verify installed-skill version and project identity using
`check-drift.sh authorize` only. It SHALL NOT additionally run `check-drift.sh check`'s broader
installed-piece/tool-contract inspection as part of a routine save; that broader inspection
remains available through the standalone `/setup-memory-workflow` health check and through
`save-session-maintenance`'s own Step 0.

#### Scenario: Routine save Preflight
- **WHEN** `/save-session` runs its Preflight steps
- **THEN** it SHALL call `check-drift.sh authorize` to verify version/project identity and SHALL
  NOT call `check-drift.sh check`

#### Scenario: Explicit health check still available
- **WHEN** a user runs `/setup-memory-workflow` directly, or `/save-session-maintenance` runs
  its Step 0
- **THEN** the broader `check-drift.sh check` tool-contract inspection SHALL still run there,
  unaffected by Preflight's narrower scope
