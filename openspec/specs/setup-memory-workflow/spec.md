# setup-memory-workflow Specification

## Purpose
Bootstraps and runs the basic-memory session workflow in any project via the `basic-memory-workflow` Claude Code plugin (save-session, sync-memory, and a SessionStart reminder hook, bundled as one canonical copy referenced from a local plugin marketplace — see the `claude-plugin-marketplace` capability). A project opts in explicitly via `enabledPlugins`; project identity resolves at runtime rather than being baked in at install time.
## Requirements
### Requirement: basic-memory project registration
The workflow SHALL ensure the current project is registered with basic-memory at `$HOME/.local/share/basic-memory/$PROJECT` before any MCP tool call happens in the session. The `SessionStart` hook performs this via `ensure-project-registered.sh` as the normal, first-to-run path; `save-session` and `sync-memory`'s own Step 0/Step 1 also call `ensure-project-registered.sh` directly (idempotently) rather than assuming the hook already ran, since a plugin enabled after session start (e.g. via `/reload-plugins`) never gets a `SessionStart` firing for that session.

#### Scenario: First-time setup
- **WHEN** the `SessionStart` hook fires in a project with no existing basic-memory registration
- **THEN** `ensure-project-registered.sh` resolves `$PROJECT` via `resolve-project-name.sh`, then `basic-memory project add "$PROJECT" "$HOME/.local/share/basic-memory/$PROJECT"` creates and registers the project before the hook's reminder is emitted — this happens before Claude can call any basic-memory MCP tool

#### Scenario: Re-run on existing project
- **WHEN** the `SessionStart` hook fires in a project already registered with basic-memory
- **THEN** `basic-memory project add` exits 0 with a notice; the hook continues without error and without re-creating anything

#### Scenario: basic-memory not installed at session start
- **WHEN** the `SessionStart` hook fires and the `basic-memory` CLI is not on `PATH`
- **THEN** `ensure-project-registered.sh` exits non-zero and the hook silently no-ops, emitting no reminder — `save-session`'s own `which basic-memory` check (see the separate installation requirement) is what surfaces this to the user if they run `/save-session` later in the same session

#### Scenario: Plugin enabled mid-session, SessionStart never fires
- **WHEN** `basic-memory-workflow` becomes active in a project after session start (e.g. via `/reload-plugins`), so the `SessionStart` hook never runs during that session
- **THEN** the first invocation of `save-session` or `sync-memory` still registers the project, because their own Step 0/Step 1 calls `ensure-project-registered.sh` directly rather than relying solely on the hook having already run

### Requirement: basic-memory installed via uv tool install
The workflow SHALL check for a working `basic-memory` installation on each `save-session` invocation (not once at install time) and instruct the user to install it with `uv tool install basic-memory`, not `uvx` or `pip`, if missing.

#### Scenario: basic-memory not found
- **WHEN** `save-session` runs and `which basic-memory` returns no result
- **THEN** it tells the user to run `uv tool install basic-memory` and stops before attempting project registration or any note write

### Requirement: Plugin bundles the full basic-memory session workflow
The `save-session` skill, the `sync-memory` skill and script, and the `SessionStart` reminder hook SHALL be distributed as a single Claude Code plugin, `basic-memory-workflow`, referenced from one shared install location rather than copied into each project.

#### Scenario: One canonical copy serves every enabled project
- **WHEN** the `basic-memory-workflow` plugin is enabled in two different projects
- **THEN** both projects run the exact same `save-session`/`sync-memory` skill content and hook definition — there is no per-project rendered copy of any of the three

#### Scenario: Updating the plugin updates every consumer
- **WHEN** the canonical plugin content changes and the marketplace is updated
- **THEN** every project with the plugin enabled sees the new content on its next load (or after `/reload-plugins`), with no per-project drift-check or repair step involved

### Requirement: Runtime project identity resolution via shared script
A single shared script, `scripts/resolve-project-name.sh`, SHALL be the sole mechanism by which any part of the plugin determines the current project's basic-memory identity, computed fresh on each invocation and free of side effects. `sync-memory.py`'s own internal identity lookups (used by `--standalone` mode and default vault-dir resolution) call it directly for pure resolution with no registration side effect. Every consumer that goes on to make basic-memory MCP tool calls in a session — the `SessionStart` hook, and `save-session`'s and `sync-memory`'s own Step 0/Step 1 — instead calls `ensure-project-registered.sh`, a wrapper that resolves identity via this script and additionally guarantees the project is registered with basic-memory (see the registration requirement above).

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
- **THEN** it exits non-zero with a clear error to stderr; every `ensure-project-registered.sh` caller propagates that failure — the `SessionStart` hook treats it as a silent no-op rather than failing session start, while `save-session` and `sync-memory` instead stop and report it, since their own Step 0/Step 1 call `ensure-project-registered.sh` directly

### Requirement: Per-project explicit opt-in
Enabling the `basic-memory-workflow` plugin for a given project SHALL always be an explicit, individual decision — the plugin SHALL NOT become active in a project merely because the marketplace is registered or the plugin is enabled elsewhere.

#### Scenario: Plugin enabled in one project only
- **WHEN** a user enables `basic-memory-workflow` for Project A via that project's `.claude/settings.json` or `.claude/settings.local.json`
- **THEN** Project B, where no such entry exists, sees no `SessionStart` hook and no `save-session`/`sync-memory` skills from this plugin

### Requirement: One-time migration script for pre-plugin installs
`scripts/migrate-to-plugin.sh`, bundled in the plugin, SHALL detect and — only on explicit confirmation — clean up artifacts left behind by the prior copy-based installer, using the same check-before-apply, never-silently-overwrite discipline as the retired `check-drift.sh`.

#### Scenario: Check mode reports without modifying anything
- **WHEN** `migrate-to-plugin.sh check` runs in a project with old `.claude/skills/save-session/`, old `.claude/skills/sync-memory/`, a legacy hook entry in `.claude/settings.local.json`, and stale `.git/info/exclude` entries for those paths
- **THEN** it reports each of these as found, without modifying any file

#### Scenario: Apply mode removes legacy artifacts and enables the plugin
- **WHEN** `migrate-to-plugin.sh apply` runs after the user confirms, in a project with the legacy artifacts described above
- **THEN** it deletes the old skill directories, removes the legacy hook entry from `.claude/settings.local.json`, removes the now-pointless `.git/info/exclude` entries, and adds `"basic-memory-workflow@<marketplace-name>": true` under `enabledPlugins` in `.claude/settings.local.json`

#### Scenario: Already-migrated project is a no-op
- **WHEN** `migrate-to-plugin.sh check` runs in a project with no legacy artifacts and the plugin already enabled
- **THEN** it reports nothing to migrate and makes no changes on a subsequent `apply`

#### Scenario: Not hardcoded to any specific project
- **WHEN** `migrate-to-plugin.sh` runs in any git repository, known or not previously encountered
- **THEN** it operates purely on what it finds in that project's own `.claude/` state — it maintains no built-in list of target projects

