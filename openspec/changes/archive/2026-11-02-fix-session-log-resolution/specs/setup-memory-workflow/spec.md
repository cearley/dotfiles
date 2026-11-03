# Spec Delta

## ADDED Requirements

### Requirement: Active session-log note is resolved deterministically, not by search
`save-session`'s Step 1 SHALL resolve the active session-log note by reading the most
recent wikilink in the current status note's Status Summary section (fetched by Step 2,
which SHALL run before Step 1), rather than by issuing a `search_notes` query against the
project's basic-memory corpus. `search_notes` SHALL be used only as a fallback when no
such wikilink can be found.

#### Scenario: Status note has a recent Detail link
- **WHEN** the current status note's most recent Status Summary entry contains one or
  more wikilinks (e.g. a `Detail: [[...]]` pointer)
- **THEN** Step 1 appends to the note named by the last wikilink in that entry, and makes
  no `search_notes` call

#### Scenario: No wikilink found — cold start
- **WHEN** the current status note has no wikilink in its Status Summary section (e.g. a
  brand-new project's first-ever `/save-session` run, before any entry has been written)
- **THEN** Step 1 falls back to the prior `search_notes`-based behavior, unchanged

#### Scenario: Multiple wikilinks in the most recent entry
- **WHEN** the most recent Status Summary entry contains more than one wikilink
- **THEN** Step 1 uses the last wikilink in that entry, matching this skill's own
  established convention of placing the session-log pointer at the end of each dated
  paragraph

#### Scenario: Step ordering
- **WHEN** `save-session` runs
- **THEN** Step 2 (read the current status note) completes before Step 1 (append to the
  session log) begins, so Step 1 can use what Step 2 already fetched instead of issuing
  its own read or search
