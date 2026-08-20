## Purpose

Provides an on-demand script that detects Claude Code `skillOverrides`/`enabledPlugins`
entries silently diverging from a persona's chezmoi-managed baseline — the mirror-image
direction of the installed-but-undeclared drift that `package-audit` already covers — and,
via an explicit `--fix` mode, codifies a confirmed "keep" resolution directly into the
persona's source template.

## ADDED Requirements

### Requirement: On-Demand Executable Location
The system SHALL provide the detection tool as a chezmoi-rendered executable at
`home/dot_local/bin/executable_check-claude-overrides.tmpl`, deployed directly to
`~/.local/bin/check-claude-overrides` — invoked manually by the user or an agent to discover
unexplained `skillOverrides`/`enabledPlugins` entries.

#### Scenario: Source file uses chezmoi convention
- **WHEN** the user inspects the source repository
- **THEN** a file SHALL exist at `home/dot_local/bin/executable_check-claude-overrides.tmpl`

#### Scenario: Deployed as a real executable, not a symlink
- **WHEN** `chezmoi apply` runs
- **THEN** `~/.local/bin/check-claude-overrides` SHALL be a regular, executable, rendered file
  — not a symlink into the chezmoi source tree

#### Scenario: Not run automatically by chezmoi apply
- **WHEN** the user runs `chezmoi apply`
- **THEN** `check-claude-overrides` SHALL be written to disk but SHALL NOT itself execute

#### Scenario: Short-name invocation
- **WHEN** `~/.local/bin` is on the user's PATH
- **AND** the user runs `check-claude-overrides` from any working directory
- **THEN** it SHALL execute the same as if invoked by its full path

### Requirement: Source-Directory Portability
Every chezmoi-source-tree path the tool reads or writes (`packages.yaml`,
`dot_claude/skills/`, each persona's `modify_settings.json.tmpl`) SHALL be resolved via
`{{ .chezmoi.sourceDir }}` at chezmoi-apply render time, and the source template SHALL NOT
contain a hardcoded absolute path to the chezmoi source directory anywhere in its body.

#### Scenario: Rendered output works regardless of checkout location
- **WHEN** the chezmoi source repository is checked out at a different absolute path than
  the machine's default, and `chezmoi apply` is run
- **THEN** the rendered `check-claude-overrides` SHALL still correctly locate
  `packages.yaml`, `dot_claude/skills/`, and every persona's `modify_settings.json.tmpl`

#### Scenario: Only the rendered output names an absolute path
- **WHEN** the change's source files are inspected for a hardcoded chezmoi source path
- **THEN** no `.tmpl` source file in this change SHALL contain a literal absolute chezmoi
  source path — every occurrence SHALL be the `{{ .chezmoi.sourceDir }}` template variable,
  resolved only in each machine's own untracked, rendered output

### Requirement: Persona Environment Enumeration
The persona list — the unnamed default (`~/.claude`) unconditionally, plus every persona
declared in the machine's `claude_envs` machine-config list — SHALL be resolved at
chezmoi-apply render time (via `{{ range $claudeEnvs }}`) and baked into the deployed
executable as literal values, not discovered by scanning the filesystem or re-derived at
runtime.

#### Scenario: Declared personas checked
- **WHEN** the machine's `claude_envs` list declares one or more named personas at the time
  `chezmoi apply` last ran
- **THEN** each declared persona's directory SHALL be checked, not only the current
  `$CLAUDE_CONFIG_DIR`

#### Scenario: Unnamed default always checked
- **WHEN** the tool runs
- **THEN** the unnamed default persona (`~/.claude`) SHALL always be checked, regardless of
  `claude_envs`

#### Scenario: Undeclared directory not checked
- **WHEN** a `~/.claude-<name>` directory exists on disk
- **AND** `<name>` is not present in the machine's `claude_envs` list
- **THEN** the tool SHALL NOT check that directory

### Requirement: Baseline Extraction via Template Rendering
For each persona environment, the script SHALL determine its intended `skillOverrides`/
`enabledPlugins`/`permissions` baseline by rendering that persona's
`modify_settings.json.tmpl` with `chezmoi execute-template` and extracting the JSON literal
produced by the `claude-settings-hooks-modifier` partial's `extra_settings` variable,
rather than parsing the source template's Go `dict(...)` syntax directly.

#### Scenario: Named persona baseline resolved
- **WHEN** checking a persona declared in `claude_envs` (e.g. `~/.claude-personal`)
- **THEN** the script SHALL render `home/dot_claude-personal/modify_settings.json.tmpl`
  (the matching `dot_claude-<name>/` source directory) to obtain its baseline

#### Scenario: Unnamed default persona baseline resolved
- **WHEN** checking the unnamed default persona (`~/.claude`)
- **THEN** the script SHALL render `home/dot_claude/modify_settings.json.tmpl` to obtain
  its baseline

### Requirement: Skill Override Drift Detection
The script SHALL flag any `skillOverrides.<skill>: "off"` entry in a persona's live
`settings.json` where `<skill>` is a native skill (listed under `home/dot_claude/skills/`)
and the persona's baseline does not set that same key to `"off"`.

#### Scenario: Unexplained native skill override flagged
- **WHEN** a persona's live `settings.json` has `skillOverrides.<skill>: "off"` for a
  native skill
- **AND** that persona's rendered baseline has no matching `skillOverrides.<skill>: "off"`
  entry
- **THEN** the script SHALL report that entry as drift

#### Scenario: Baseline-explained override not flagged
- **WHEN** a persona's live `settings.json` has `skillOverrides.<skill>: "off"`
- **AND** that persona's rendered baseline also sets `skillOverrides.<skill>: "off"`
- **THEN** the script SHALL NOT report that entry as drift

### Requirement: Plugin Enablement Drift Detection
The script SHALL flag any `enabledPlugins.<id>: false` entry in a persona's live
`settings.json` where `<id>` appears in `packages.yaml`'s `claude_code.plugins` list and
the persona's baseline does not set that same key to `false`.

#### Scenario: Unexplained plugin disable flagged
- **WHEN** a persona's live `settings.json` has `enabledPlugins.<id>: false` for a plugin
  declared in `packages.yaml`'s `claude_code.plugins` list
- **AND** that persona's rendered baseline has no matching `enabledPlugins.<id>: false` entry
- **THEN** the script SHALL report that entry as drift

### Requirement: Structured Output Format
The script SHALL emit a `## drift` section with one tab-separated line per flagged entry
(`persona`, `kind`, `key`, `value`), matching the sectioned-TSV convention
`list-claude-orphans.sh` already uses, and SHALL emit no lines under that section when no
drift is found.

#### Scenario: Clean machine produces empty section
- **WHEN** no unexplained `skillOverrides` or `enabledPlugins` entries exist on any checked
  persona
- **THEN** the script SHALL print the `## drift` header with no following lines

### Requirement: Default Read-Only Operation
Invoked without `--fix`, the script SHALL NOT modify any `settings.json`,
`modify_settings.json.tmpl`, or other Claude Code configuration file.

#### Scenario: No state changed without --fix
- **WHEN** the script runs without `--fix`
- **THEN** no file under any `~/.claude*` directory or the chezmoi source tree SHALL be
  modified

### Requirement: Fix Mode Invocation
The script SHALL accept `--fix <persona> <skillOverrides|enabledPlugins> <key>` to codify a
single currently-flagged drift entry as an intentional override in the target persona's
`modify_settings.json.tmpl`, without accepting the value to write as an argument.

#### Scenario: Value is read from live settings, not typed
- **WHEN** the user runs `--fix <persona> <kind> <key>`
- **THEN** the script SHALL read the value to write from that persona's live
  `settings.json` entry for `<kind>.<key>`, not from a command-line argument

#### Scenario: Refuses to fix an entry that isn't flagged
- **WHEN** `--fix <persona> <kind> <key>` is run
- **AND** `<kind>.<key>` is not currently reported as drift for `<persona>` (already resolved,
  or never was drift)
- **THEN** the script SHALL exit non-zero without modifying any file
- **AND** SHALL print a message stating the entry is not currently flagged

### Requirement: Fix Mode Requires an Existing Target Sub-Dict
`--fix` SHALL require that the target persona's `modify_settings.json.tmpl` already declares
an `$extra`/`claudeExtraSettings` dict containing the target `skillOverrides` or
`enabledPlugins` sub-dict; it SHALL NOT create either from scratch.

#### Scenario: Persona has no matching sub-dict
- **WHEN** `--fix <persona> <kind> <key>` is run
- **AND** that persona's `modify_settings.json.tmpl` has no `<kind>` sub-dict in its `$extra`
  dict (or no `$extra` dict at all)
- **THEN** the script SHALL exit non-zero without modifying any file
- **AND** SHALL print a message directing the user to add the sub-dict manually once

### Requirement: Fix Mode Verifies Before Writing the Real File
`--fix` SHALL apply its edit to a temporary copy of the target template, render that copy,
and confirm the new key/value appears in the rendered baseline before overwriting the real
source file.

#### Scenario: Verified edit is committed to the real file
- **WHEN** `--fix` inserts the new entry into a temporary copy
- **AND** rendering that copy via the same baseline-extraction mechanism used for detection
  produces the expected key/value
- **THEN** the script SHALL overwrite the real `modify_settings.json.tmpl` with the verified
  copy's content

#### Scenario: Failed verification leaves the real file untouched
- **WHEN** rendering the temporary copy fails, or the expected key/value is absent from the
  rendered result
- **THEN** the script SHALL exit non-zero
- **AND** the real `modify_settings.json.tmpl` SHALL remain byte-for-byte unchanged

### Requirement: Missing-Baseline Graceful Skip
The script SHALL skip — not error out entirely — a persona declared in `claude_envs` (or the
unnamed default) whose corresponding `modify_settings.json.tmpl` cannot be found or rendered,
and SHALL continue checking remaining personas.

#### Scenario: Declared persona without a matching template
- **WHEN** `claude_envs` declares a persona with no corresponding
  `home/dot_claude-<name>/modify_settings.json.tmpl` in the chezmoi source
- **THEN** the script SHALL emit a skip notice for that persona to stderr
- **AND** SHALL continue checking any remaining personas
