## MODIFIED Requirements

### Requirement: basic-memory project registration
The workflow SHALL ensure the current project is registered with basic-memory at `$HOME/.local/share/basic-memory/$PROJECT` before any MCP tool call happens in the session, performed once by the `SessionStart` hook via `ensure-project-registered.sh` rather than by `save-session` on each invocation.

#### Scenario: First-time setup
- **WHEN** the `SessionStart` hook fires in a project with no existing basic-memory registration
- **THEN** `ensure-project-registered.sh` resolves `$PROJECT` via `resolve-project-name.sh`, then `basic-memory project add "$PROJECT" "$HOME/.local/share/basic-memory/$PROJECT"` creates and registers the project before the hook's reminder is emitted — this happens before Claude can call any basic-memory MCP tool

#### Scenario: Re-run on existing project
- **WHEN** the `SessionStart` hook fires in a project already registered with basic-memory
- **THEN** `basic-memory project add` exits 0 with a notice; the hook continues without error and without re-creating anything

#### Scenario: basic-memory not installed at session start
- **WHEN** the `SessionStart` hook fires and the `basic-memory` CLI is not on `PATH`
- **THEN** `ensure-project-registered.sh` exits non-zero and the hook silently no-ops, emitting no reminder — `save-session`'s own `which basic-memory` check (see the separate installation requirement) is what surfaces this to the user if they run `/save-session` later in the same session

### Requirement: Runtime project identity resolution via shared script
A single shared script, `scripts/resolve-project-name.sh`, SHALL be the sole mechanism by which any part of the plugin determines the current project's basic-memory identity, computed fresh on each invocation and free of side effects. `save-session`'s own instructions and `sync-memory.py`/`sync-memory`'s Step 0 call it directly for pure identity resolution; the `SessionStart` hook instead calls `ensure-project-registered.sh`, a wrapper that resolves identity via this script and additionally guarantees the project is registered with basic-memory (see the registration requirement above).

#### Scenario: Default resolution
- **WHEN** `resolve-project-name.sh` runs inside a git repository with no override file present
- **THEN** it prints `basename` of `git rev-parse --show-toplevel` as the project name

#### Scenario: Override file present
- **WHEN** `<project-root>/.claude/basic-memory-project.txt` exists and contains non-blank content
- **THEN** `resolve-project-name.sh` prints that content as the project name instead of the git-basename default

#### Scenario: Override file blank or whitespace-only
- **WHEN** `<project-root>/.claude/basic-memory-project.txt` exists but is empty or contains only whitespace
- **THEN** `resolve-project-name.sh` falls through to the git-basename default, treating the file as if it were absent

#### Scenario: Not inside a git repository
- **WHEN** `resolve-project-name.sh` runs outside any git repository
- **THEN** it exits non-zero with a clear error to stderr; `ensure-project-registered.sh` propagates that failure and the `SessionStart` hook treats it as a silent no-op rather than failing session start
