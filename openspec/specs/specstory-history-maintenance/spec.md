# specstory-history-maintenance Specification

## Purpose

Keeps SpecStory's per-project `.specstory/history/` session capture complete and free of
duplicate files, across every project on the machine — the Stop hook's sync is scoped to the
session that just ended, and a standalone tool exists to find and safely remove any duplicates
that still occur.

## Requirements

### Requirement: Stop hook syncs only the session that just ended

The Claude Code `Stop` hook SHALL invoke `specstory sync` scoped to the session that just ended,
using the documented positional provider argument and `-s/--session` flag, rather than a
provider-wide sync.

#### Scenario: Session ends normally
- **WHEN** a Claude Code session's `Stop` hook fires
- **THEN** the hook script reads `session_id` from the hook's stdin JSON payload and runs
  `specstory sync claude -s "$SESSION_ID"`, not a bare provider-wide `specstory sync`

#### Scenario: Deployed identically across every persona
- **WHEN** the Stop hook is configured in any of the four `dot_claude*` persona settings
- **THEN** each persona's `Stop` hook command invokes the same session-scoped wrapper script

### Requirement: Duplicate history files are discoverable and safely removable

A standalone tool SHALL exist that finds every project's `.specstory/history/` directory on the
machine and identifies duplicate markdown files for the same session, distinguishing files that
are safe to remove (an exact byte-prefix of a larger sibling) from files that are not.

#### Scenario: Discovering history directories across the machine
- **WHEN** the tool runs with no arguments
- **THEN** it searches from `$HOME` for every directory matching `.specstory/history` and
  inspects each one, without requiring the user to `cd` into individual projects

#### Scenario: Safe duplicate identified
- **WHEN** two files in the same `.specstory/history/` (or a subdirectory of it) embed the same
  session UUID and the smaller file's full byte content is an exact prefix of the larger file's
  byte content
- **THEN** the tool reports the smaller file as a safe-to-remove duplicate of the larger one

#### Scenario: Divergent pair is never auto-resolved
- **WHEN** two files embed the same session UUID but neither is an exact byte-prefix of the other
- **THEN** the tool reports the pair as a conflict requiring manual review and never removes
  either file, with or without `--apply`

#### Scenario: Dry-run by default
- **WHEN** the tool is invoked without `--apply`
- **THEN** it prints the manifest of safe-to-remove duplicates (with bytes that would be
  reclaimed) and any flagged conflicts, and deletes nothing

#### Scenario: Explicit apply performs deletion
- **WHEN** the tool is invoked with `--apply`
- **THEN** it deletes exactly the files identified as safe-to-remove duplicates, leaves every
  flagged conflict untouched, and reports what was actually deleted
