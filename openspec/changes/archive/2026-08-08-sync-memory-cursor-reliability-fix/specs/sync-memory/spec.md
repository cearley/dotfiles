## MODIFIED Requirements

### Requirement: Cursor-based sync state tracking
The script SHALL track the maximum modification time of SpecStory logs it has processed in a state file, and only consider logs modified after that cursor on subsequent runs. In default (non-`--standalone`) mode, the cursor SHALL NOT advance automatically at the end of a run — see the separate "Cursor commit is a separate, explicit step in default mode" requirement.

#### Scenario: First run, no state file
- **WHEN** `.specstory/.sync-memory-state.json` does not exist and `--since-days` is not passed
- **THEN** the script considers every log under `.specstory/history` as unsynced, subject only to the `--max-logs-per-run` cap — not filtered by age

#### Scenario: First run, no state file, explicit --since-days bound
- **WHEN** `.specstory/.sync-memory-state.json` does not exist and `--since-days N` is passed
- **THEN** only logs modified within the last `N` days are considered unsynced

#### Scenario: Subsequent run with existing state file
- **WHEN** `.specstory/.sync-memory-state.json` exists with a `last_synced_mtime` value
- **THEN** only logs with `mtime` strictly greater than that value are considered unsynced, and `--since-days` has no effect

#### Scenario: Cursor advances after a run
- **WHEN** `--standalone` mode successfully writes distilled content to the vault, or default mode's `--mark-synced <mtime>` is called with an `<mtime>` newer than the current cursor
- **THEN** `last_synced_mtime` in the state file is updated to that run's (or that call's) maximum `mtime`

#### Scenario: Dry run does not advance the cursor
- **WHEN** the script runs with `--dry-run`
- **THEN** it reports which logs would be processed but does not update the state file or write to the vault

#### Scenario: Default mode does not advance the cursor on its own
- **WHEN** the script runs without `--standalone` and finds one or more unsynced logs
- **THEN** it prints their content and a final line reporting the maximum `mtime` among them, but does not update the state file — only a later, explicit `--mark-synced` call does that

## ADDED Requirements

### Requirement: Cursor commit is a separate, explicit step in default mode
Because default mode has no way to know whether the invoking Claude Code session actually distilled and wrote the printed logs to the vault, the script SHALL provide a distinct `--mark-synced <mtime>` operation that is the only way the cursor advances after a default-mode run, and SHALL refuse to move the cursor backward or leave it unchanged.

#### Scenario: Explicit commit advances the cursor
- **WHEN** the script runs with `--mark-synced <mtime>` and `<mtime>` is greater than the current cursor, or no cursor exists yet
- **THEN** it updates `last_synced_mtime` in the state file to `<mtime>`

#### Scenario: Commit refuses to move the cursor backward
- **WHEN** the script runs with `--mark-synced <mtime>` and `<mtime>` is less than or equal to the current cursor
- **THEN** it exits non-zero without modifying the state file

#### Scenario: An interrupted or failed distillation leaves logs unsynced, not lost
- **WHEN** a default-mode run prints unsynced logs but `--mark-synced` is never subsequently called for that batch — for example, the session is interrupted before the vault write is confirmed
- **THEN** those logs remain unsynced and are reported again by the next default-mode run; no content is silently dropped from the sync pipeline
