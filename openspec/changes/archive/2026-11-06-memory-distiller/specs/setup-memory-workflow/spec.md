## MODIFIED Requirements

### Requirement: Skill is distributed as per-project rendered copies, not a shared reference
The `save-session` skill, the `save-session-maintenance` skill, and the `SessionStart` reminder hook configuration SHALL each be rendered from a canonical template into the target project's own `.claude/` directory (or `.claude/settings.local.json`, for the hook), with a version marker (`setup-memory-workflow-version:N`) embedded in each rendered piece. Components that are not per-project — notably the `memory-distiller` worker and its instruction asset — SHALL NOT be distributed this way; they are machine-level, managed directly by the dotfiles manager, and carry no per-project version marker.

#### Scenario: Missing piece is created unconditionally
- **WHEN** `check-drift.sh check` finds a piece (skill file, hook entry, or `.mcp.json` entry) missing from the current project
- **THEN** it renders the current canonical template into place directly — creating a missing piece is always safe and requires no confirmation

#### Scenario: Two projects have independent copies
- **WHEN** the workflow is installed in two different projects
- **THEN** each project has its own physically separate rendered files — editing one project's installed copy has no effect on the other

#### Scenario: Machine-level components are not rendered per project
- **WHEN** the workflow is installed in two different projects on the same machine
- **THEN** both are served by a single shared copy of the `memory-distiller` worker and its instruction asset, and neither project contains a rendered copy of either — updating the machine-level copy therefore reaches every project at once, without any per-project drift-check or repair step

#### Scenario: One canonical copy serves every enabled project
- **WHEN** considering the retired plugin-era guarantee this scenario originally described — that two projects with the plugin enabled ran the exact same shared skill/hook content, with no per-project rendered copy of any of it
- **THEN** it is deliberately inverted for the per-project pieces, not preserved: each project now has its own independently rendered copy of those (see "Two projects have independent copies" above) — this is the whole point of returning to a copy-based distribution, since a single shared copy is exactly what made runtime `$PROJECT` resolution necessary and skippable in the first place

#### Scenario: Updating the plugin updates every consumer
- **WHEN** considering the retired plugin-era guarantee this scenario originally described — that changing the canonical plugin content and updating the marketplace propagated to every enabled project automatically, with no per-project drift-check or repair step
- **THEN** it is deliberately inverted for the per-project pieces, not preserved: canonical template changes now reach an installed project only when `check-drift.sh update` (or `apply`) is explicitly run there — propagation is opt-in and per-project again, in exchange for eliminating the plugin's own weaker update story (a commit-SHA-pinned cache with no `needsUpdate` signal, confirmed stale on a real install during this change's own investigation)

## ADDED Requirements

### Requirement: Installing the workflow registers the project for unattended distillation
Installing the memory workflow into a project SHALL register that project with the
`memory-distiller` worker, and uninstalling SHALL deregister it. Registration SHALL be an explicit
recorded action, not inferred from the presence of files on disk.

#### Scenario: Install registers
- **WHEN** the memory workflow is installed into a project for the first time
- **THEN** that project and its basic-memory project name are recorded in the distiller's registry,
  so its sessions begin being distilled

#### Scenario: Uninstall deregisters
- **WHEN** the memory workflow is removed from a project
- **THEN** the corresponding registry entry is removed, and the distiller stops processing that
  project's transcripts

#### Scenario: Registration is idempotent
- **WHEN** installation runs again in a project that is already registered
- **THEN** the registry is left with exactly one entry for that project, with its basic-memory
  project name refreshed to the currently resolved value
