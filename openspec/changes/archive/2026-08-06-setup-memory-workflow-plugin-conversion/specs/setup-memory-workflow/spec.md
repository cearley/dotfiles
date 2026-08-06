## REMOVED Requirements

### Requirement: Install-time project name detection
**Reason**: There is no longer an install step to detect a project name once and bake it into generated artifacts — the skill/script bundle is no longer copied per project at all.
**Migration**: Project identity is now resolved at runtime by the shared `resolve-project-name.sh` script (see the new "Runtime project identity resolution via shared script" requirement below), called fresh on every invocation rather than once at install time.

### Requirement: Global MCP registration check
**Reason**: basic-memory MCP server registration is handled entirely by this machine's pre-existing global `claude-extend` tools.json mechanism, independent of this capability. This capability no longer touches MCP server config at all.
**Migration**: None needed — this check has had nothing left to do since basic-memory is registered globally on every machine this workflow targets.

### Requirement: MCP server written to .mcp.json
**Reason**: Same as above — MCP server registration is entirely out of this capability's scope now.
**Migration**: A project relying on a previously-written per-project `.mcp.json` basic-memory entry can leave that file as-is; nothing in this capability manages it going forward.

### Requirement: MCP server command uses uvx with Python 3.12
**Reason**: This capability no longer writes any MCP server entry, so the entry's shape is no longer this capability's concern.
**Migration**: None.

### Requirement: User decides .mcp.json gitignore status
**Reason**: This capability no longer creates or modifies `.mcp.json`.
**Migration**: None.

### Requirement: Idempotent, drift-checked hook installation via version marker
**Reason**: The `SessionStart` hook is now declared once inside the plugin's own `hooks/hooks.json` and referenced, not copied into each project's `settings.local.json` — there is nothing left to drift-check.
**Migration**: `scripts/migrate-to-plugin.sh` removes any pre-existing per-project hook entry as part of its one-time cleanup (see the new "One-time migration script for pre-plugin installs" requirement below).

### Requirement: Legacy artifacts are cleaned up by unconditional migrations
**Reason**: The permanent, unconditionally-run-on-every-invocation `migrations.sh` mechanism existed to clean up prior-version artifacts left behind by the old copy-based installer. With no more recurring "run the skill to install/repair" invocation, there is nothing for a permanent migration layer to run before.
**Migration**: A single, explicitly-run `scripts/migrate-to-plugin.sh` (bundled in the plugin) performs the equivalent one-time cleanup for any project still carrying old artifacts, using the same check/apply, never-silently-overwrite discipline.

### Requirement: Hook command built via jq --arg
**Reason**: This capability no longer constructs or writes a hook command string into any project's settings file — the hook command lives statically inside the plugin's `hooks/hooks.json`.
**Migration**: None.

### Requirement: Settings file post-write verification
**Reason**: This combined `.mcp.json` + hook verification step no longer applies — `.mcp.json` is out of scope entirely, and the hook is never written per-project. The narrower verification that's still meaningful (did `enabledPlugins` actually get set, were old artifacts actually removed) is covered by the new migration-script requirement's own scenarios instead of a separate generic verification requirement.
**Migration**: None — see "One-time migration script for pre-plugin installs" below.

### Requirement: Idempotent, drift-checked sync-memory skill installation via version marker
**Reason**: `sync-memory` ships as a single canonical skill bundled directly in the plugin. Nothing is copied into any project, so nothing can drift from canonical.
**Migration**: `scripts/migrate-to-plugin.sh` removes any pre-existing per-project copy of this skill.

### Requirement: Idempotent, drift-checked sync-memory script installation via version marker
**Reason**: Same as above — `sync-memory.py` is a single canonical file bundled in the plugin, not copied per project.
**Migration**: `scripts/migrate-to-plugin.sh` removes any pre-existing per-project copy of this script.

### Requirement: sync-memory script uses the same install-time templating as the other canonical assets
**Reason**: Superseded by the `sync-memory` capability's own requirement change: the script now resolves project identity at runtime via the shared `resolve-project-name.sh`, not via install-time template rendering.
**Migration**: None — see the `sync-memory` capability's modified requirements.

### Requirement: SMW_VERSION bump surfaces new pieces on existing installs
**Reason**: The `SMW_VERSION` marker system is retired in full. Claude Code's own plugin versioning (declared `version`, or git-commit-SHA fallback) governs when a project sees updated plugin content — there is no longer a hand-rolled marker to bump.
**Migration**: None — see the "Plugin bundles the full basic-memory session workflow" requirement below.

## MODIFIED Requirements

### Requirement: basic-memory project registration
The workflow SHALL ensure the current project is registered with basic-memory at `$HOME/.local/share/basic-memory/$PROJECT` before any note is written, performed idempotently on every `save-session` invocation rather than once during a dedicated install step.

#### Scenario: First-time setup
- **WHEN** `save-session` runs in a project with no existing basic-memory registration
- **THEN** it resolves `$PROJECT` via `resolve-project-name.sh`, then `basic-memory project add "$PROJECT" "$HOME/.local/share/basic-memory/$PROJECT"` creates and registers the project before any note is written

#### Scenario: Re-run on existing project
- **WHEN** `save-session` runs in a project already registered with basic-memory
- **THEN** `basic-memory project add` exits 0 with a notice; the invocation continues without error and without re-creating anything

### Requirement: basic-memory installed via uv tool install
The workflow SHALL check for a working `basic-memory` installation on each `save-session` invocation (not once at install time) and instruct the user to install it with `uv tool install basic-memory`, not `uvx` or `pip`, if missing.

#### Scenario: basic-memory not found
- **WHEN** `save-session` runs and `which basic-memory` returns no result
- **THEN** it tells the user to run `uv tool install basic-memory` and stops before attempting project registration or any note write

## ADDED Requirements

### Requirement: Plugin bundles the full basic-memory session workflow
The `save-session` skill, the `sync-memory` skill and script, and the `SessionStart` reminder hook SHALL be distributed as a single Claude Code plugin, `basic-memory-workflow`, referenced from one shared install location rather than copied into each project.

#### Scenario: One canonical copy serves every enabled project
- **WHEN** the `basic-memory-workflow` plugin is enabled in two different projects
- **THEN** both projects run the exact same `save-session`/`sync-memory` skill content and hook definition — there is no per-project rendered copy of any of the three

#### Scenario: Updating the plugin updates every consumer
- **WHEN** the canonical plugin content changes and the marketplace is updated
- **THEN** every project with the plugin enabled sees the new content on its next load (or after `/reload-plugins`), with no per-project drift-check or repair step involved

### Requirement: Runtime project identity resolution via shared script
A single shared script, `scripts/resolve-project-name.sh`, SHALL be the sole mechanism by which any part of the plugin (the hook, `sync-memory.py`, or `save-session`'s own instructions) determines the current project's basic-memory identity, computed fresh on each invocation.

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
- **THEN** it exits non-zero with a clear error to stderr; the `SessionStart` hook treats this as a silent no-op rather than failing session start

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
