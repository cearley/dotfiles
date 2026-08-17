## RENAMED Requirements

- FROM: `### Requirement: Plugin bundles the full basic-memory session workflow`
- TO: `### Requirement: Skill is distributed as per-project rendered copies, not a shared reference`
- FROM: `### Requirement: Runtime project identity resolution via shared script`
- TO: `### Requirement: Project identity is resolved once, at apply-time`

## MODIFIED Requirements

### Requirement: basic-memory project registration
The workflow SHALL ensure the current project is registered with basic-memory at `$HOME/.local/share/basic-memory/$PROJECT` as part of `check-drift.sh check`, before any per-project piece is created or repaired.

#### Scenario: First-time setup
- **WHEN** `check-drift.sh check` runs in a project with no existing basic-memory registration
- **THEN** it resolves `$PROJECT` (see the project identity requirement below), then `basic-memory project add "$PROJECT" "$HOME/.local/share/basic-memory/$PROJECT"` creates and registers the project before any piece is checked or created

#### Scenario: Re-run on existing project
- **WHEN** `check-drift.sh check` runs in a project already registered with basic-memory
- **THEN** `basic-memory project add` exits 0 with a notice; the check continues without error and without re-creating anything

#### Scenario: basic-memory not installed at session start
- **WHEN** `check-drift.sh check` runs and the `basic-memory` CLI is not on `PATH`
- **THEN** it reports `MISSING` and exits non-zero immediately, before attempting registration or creating any piece — `save-session`'s own `which basic-memory` check (see the separate installation requirement) independently surfaces the same problem if the user runs `/save-session` without ever having run `check-drift.sh`

#### Scenario: Plugin enabled mid-session, SessionStart never fires
- **WHEN** considering the retired plugin-era failure mode this scenario originally described — a plugin enabled mid-session via `/reload-plugins` never getting its `SessionStart` hook to fire that session, so a second, redundant per-invocation registration check inside `save-session`/`sync-memory` was needed as a fallback
- **THEN** it no longer applies: the workflow only ever runs when `check-drift.sh` is explicitly invoked in a project (see the "Per-project explicit opt-in" requirement) — there is no "plugin becomes active" event to race against, so registration happening once, at `check-drift.sh check` time, is sufficient with no fallback needed

### Requirement: Skill is distributed as per-project rendered copies, not a shared reference
The `save-session` skill, the `sync-memory` skill and script, and the `SessionStart` hook configuration SHALL each be rendered from a canonical template into the target project's own `.claude/` directory (or `.claude/settings.local.json`, for the hook), with a version marker (`setup-memory-workflow-version:N`) embedded in each rendered piece.

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

### Requirement: Project identity is resolved once, at apply-time
`check-drift.sh` SHALL resolve the current project's basic-memory identity once per invocation, at the top of the script, and use that single resolved value for every piece it renders or checks in that invocation. No installed piece SHALL contain a runtime identity-resolution script or instruction.

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

### Requirement: Per-project explicit opt-in
Installing this workflow into a given project SHALL always be an explicit, individual action — running `check-drift.sh check` (or `update`/`apply`) directly in that project. The workflow SHALL NOT become active in a project merely because it is active elsewhere.

#### Scenario: Installed in one project only
- **WHEN** `check-drift.sh check` has been run in Project A, creating its `.claude/skills/save-session/` etc.
- **THEN** Project B, where the script has never been run, has no `save-session`/`sync-memory` skills and no `SessionStart` hook from this workflow

#### Scenario: Plugin enabled in one project only
- **WHEN** considering the retired plugin-era mechanism this scenario originally described — enabling `basic-memory-workflow` for Project A via `enabledPlugins` in that project's `.claude/settings.json` or `.claude/settings.local.json`, leaving Project B (no such entry) with no hook or skills from the plugin
- **THEN** the same opt-in guarantee holds under the new mechanism, just via a different action — see "Installed in one project only" above, where running `check-drift.sh check` in a project is what opts it in, instead of an `enabledPlugins` entry

## ADDED Requirements

### Requirement: Version drift is unconditionally repairable via `update`
`check-drift.sh update` SHALL unconditionally re-render and overwrite every installed piece whose version marker is stale, with no per-piece confirmation, as long as that piece's project identity still matches current resolution.

#### Scenario: Stale version, correct identity
- **WHEN** an installed piece's version marker is older than the skill's current `SMW_VERSION` and its embedded project name still matches current resolution
- **THEN** `check-drift.sh check` reports it as `DRIFT`, and `check-drift.sh update` overwrites it with current canonical content without asking for confirmation

#### Scenario: `update` never touches an unrelated piece
- **WHEN** `check-drift.sh update` runs and a piece is already `UP-TO-DATE`
- **THEN** that piece is left untouched and not reported

### Requirement: Identity mismatch always takes precedence over version drift and is never auto-repaired
If an installed piece's embedded project name does not match the project's current identity resolution, the workflow SHALL report and treat it as `NAME-MISMATCH` — regardless of whether its version marker is also stale — and SHALL NOT repair it via `update`. Only an explicit `check-drift.sh apply <piece>`, invoked after the user has confirmed the identity change is intentional, may overwrite a `NAME-MISMATCH` piece.

#### Scenario: Identity mismatch alone
- **WHEN** an installed piece's version marker is current but its embedded project name does not match current resolution
- **THEN** `check-drift.sh check` reports `NAME-MISMATCH`, and `check-drift.sh update` skips it, reporting that it was skipped and why

#### Scenario: Simultaneous version drift and identity mismatch
- **WHEN** an installed piece is both version-stale and identity-mismatched
- **THEN** it is still reported and treated as `NAME-MISMATCH`, not `DRIFT` — `update` MUST NOT repair it, since doing so would silently change the piece's identity while appearing to only fix its version

#### Scenario: Confirmed repair via `apply`
- **WHEN** the user confirms a reported `NAME-MISMATCH` is an intentional identity change
- **THEN** `check-drift.sh apply <piece>` overwrites that piece with canonical content rendered against current identity resolution

## REMOVED Requirements

### Requirement: One-time migration script for pre-plugin installs
**Reason**: `scripts/migrate-to-plugin.sh` was deleted along with the rest of `plugins/basic-memory-workflow/` when the plugin was retired — there is no plugin to migrate *to* anymore.
**Migration**: Moving a project off the plugin is now two plain, separately-run actions with no dedicated script: `check-drift.sh check` (creates the copy-based install) and `claude plugin uninstall basic-memory-workflow@chezmoi-personal --scope <scope>` (removes the old plugin entry).
