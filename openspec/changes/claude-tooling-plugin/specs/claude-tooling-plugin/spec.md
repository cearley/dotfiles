# Spec Delta

## Purpose

Owns the chezmoi-managed Claude Code hooks through a self-authored `claude-tooling` plugin,
so hook declarations live in a file only this repo writes. Defines how the plugin is kept
current in every persona without manual version bumps.

## ADDED Requirements

### Requirement: Plugin Location and Declaration
The chezmoi source SHALL provide a `claude-tooling` plugin at
`home/dot_local/share/claude-plugins/plugins/claude-tooling/`, listed in the
`chezmoi-personal` marketplace manifest with a relative `source`. `packages.yaml` SHALL
declare `claude-tooling@chezmoi-personal` in the `claude_code.plugins` list, so the plugin
install script installs it at user scope in every declared persona and the unnamed default.

#### Scenario: Installed in every persona
- **WHEN** `chezmoi apply` runs on a darwin machine tagged `ai`
- **THEN** `claude plugin list` under each of `~/.claude` and every `claude_envs` persona
  SHALL show `claude-tooling@chezmoi-personal` installed at user scope

### Requirement: Hooks Declared Only in the Plugin
Every chezmoi-managed hook SHALL be declared in the plugin's `hooks/hooks.json`, and no
chezmoi-managed template SHALL write hook entries into any persona's `settings.json`. Hook
commands that reference plugin files SHALL use a double-quoted `"${CLAUDE_PLUGIN_ROOT}"`
path or the exec form.

#### Scenario: Removing a hook from source removes it everywhere
- **WHEN** a hook entry is deleted from `hooks/hooks.json`
- **AND** `chezmoi apply` runs and a new session starts in any persona
- **THEN** that hook SHALL NOT run

#### Scenario: Plugin passes strict validation
- **WHEN** `claude plugin validate --strict` runs against the rendered plugin directory
- **THEN** it SHALL report no errors or warnings

### Requirement: Static Plugin Code with Runtime Machine Config
Apart from `.claude-plugin/plugin.json.tmpl`, files in the plugin SHALL NOT be chezmoi
templates. Machine-specific values the plugin's scripts need (the chezmoi source directory,
the repo root, and the persona list) SHALL be read at run time from
`~/.config/claude-tooling/config.env`, which chezmoi renders from machine settings. The
plugin SHALL NOT ship the tooling context. Its guard SHALL read the chezmoi-rendered
`~/.config/claude-tooling/claude-tooling.md` instead.

#### Scenario: Persona list change needs no plugin update
- **WHEN** a persona is added to the machine's `claude_envs`
- **AND** `chezmoi apply` runs
- **THEN** `config.env` SHALL list the new persona
- **AND** the plugin's version SHALL be unchanged

#### Scenario: Context edit needs no plugin update
- **WHEN** only `home/dot_config/claude-tooling/claude-tooling.md.tmpl` changes
- **AND** `chezmoi apply` runs
- **THEN** new sessions SHALL receive the new digest in the tooling notice, and the rendered
  file the notice points to SHALL contain the new content
- **AND** the plugin's version SHALL be unchanged

#### Scenario: Missing config degrades gracefully
- **WHEN** `config.env` or the rendered tooling context is absent or unreadable
- **THEN** each plugin hook SHALL exit 0 without blocking the tool call

### Requirement: Content-Derived Plugin Version
The plugin's `version` SHALL be derived from a hash of the plugin's source files, excluding
the version-bearing manifest. The same hash SHALL appear in the plugin install script's
`run_onchange` trigger, so any content change reruns that script.

#### Scenario: Content edit changes the version
- **WHEN** any file in the plugin other than `plugin.json.tmpl` changes
- **THEN** the rendered `plugin.json` `version` SHALL change

#### Scenario: Manifest-only edit keeps the version
- **WHEN** only `plugin.json.tmpl` changes and its manual version prefix is not bumped
- **THEN** the rendered `version` SHALL be unchanged

#### Scenario: No content change keeps the version
- **WHEN** `chezmoi apply` runs twice with no plugin file changes
- **THEN** the rendered `version` SHALL be identical both times

### Requirement: Automatic Per-Persona Update
When the plugin content hash changes, the plugin install script SHALL run
`claude plugin update claude-tooling@chezmoi-personal --scope user -y` in every persona
where the plugin is installed. It SHALL NOT delete other cached versions of the plugin
during that run.

#### Scenario: Edit reaches every persona's cache
- **WHEN** a plugin script is edited and `chezmoi apply` runs
- **THEN** each persona's `installed_plugins.json` SHALL record the new version
- **AND** its `installPath` SHALL contain the edited script

#### Scenario: Running sessions are not broken
- **WHEN** an update installs a new cached version while a session started on the old
  version is still running
- **THEN** the old version's cache directory SHALL still exist after the apply

### Requirement: Guard Never Auto-Approves
The write guard SHALL respond to a matched tool call only with `deny`, `ask`, additional
context, or no output. It SHALL NOT return `permissionDecision: "allow"`.

#### Scenario: Unrecognized tooling mutation is not auto-approved
- **WHEN** a Bash command modifies a persona `settings.json` in a form the guard does not
  classify
- **THEN** the guard's output SHALL NOT contain `"permissionDecision": "allow"`
- **AND** the tool call SHALL go through Claude Code's normal permission evaluation

### Requirement: Legacy settings.json Hook Removal
The persona `settings.json` modifier SHALL remove every hook command whose string exactly
equals one it wrote before this change:
- `session-topic-capture UserPromptSubmit`
- `session-topic-capture PreCompact`
- `session-topic-capture SessionEnd`
- `claude-tooling-write-guard`
- `check-claude-overrides --session-start`
- `claude-tooling-guard`

The removal SHALL happen in the same `chezmoi apply` that installs the plugin. The modifier
SHALL prune hook groups and events left empty, and SHALL leave every other hook command
unchanged.

#### Scenario: No duplicate firing after migration
- **WHEN** `chezmoi apply` completes on a machine whose personas had the legacy hooks
- **THEN** no persona's `settings.json` SHALL contain any legacy command
- **AND** the guard and the override check SHALL each run exactly once per matching event,
  from the plugin

#### Scenario: Foreign hooks survive
- **WHEN** a persona's `settings.json` contains a `bd prime` hook
- **THEN** it SHALL remain unchanged after apply

### Requirement: Session-Topic Capture Owned by claude-session-index
The `session-topic-capture` hooks SHALL be declared by the `claude-session-index` project's
own plugin, listed in the `chezmoi-personal` marketplace with a third-party source and
declared in `packages.yaml`. They SHALL NOT be declared by `claude-tooling` or by any
`settings.json` modifier.

#### Scenario: Topic capture continues after migration
- **WHEN** a session runs in any persona after migration
- **THEN** `UserPromptSubmit`, `PreCompact`, and `SessionEnd` topic capture SHALL run once
  per event, from the `claude-session-index` plugin
