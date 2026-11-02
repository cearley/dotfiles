# Claude Override Audit

## Purpose

Provides an on-demand script that detects Claude Code `skillOverrides`/`enabledPlugins`
entries silently diverging from a profile's chezmoi-managed baseline — the mirror-image
direction of the installed-but-undeclared drift that `package-audit` already covers — and,
via an explicit `--fix` mode, codifies a confirmed "keep" resolution directly into the
profile's managed-settings source file (`dot_claude*/.claude-settings.json`).
## Requirements
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

Every chezmoi-source-tree path the tool reads or writes (`packages.yaml`, `dot_claude/skills/`, each profile's `dot_claude*/.claude-settings.json`) SHALL be resolved via `{{ .chezmoi.sourceDir }}` at chezmoi-apply render time, and the source template SHALL NOT contain a hardcoded absolute path to the chezmoi source directory anywhere in its body.

#### Scenario: Rendered output works regardless of checkout location
- **WHEN** the chezmoi source repository is checked out at a different absolute path than
  the machine's default, and `chezmoi apply` is run
- **THEN** the rendered `check-claude-overrides` SHALL still correctly locate
  `packages.yaml`, `dot_claude/skills/`, and every profile's managed-settings file

#### Scenario: Only the rendered output names an absolute path
- **WHEN** the change's source files are inspected for a hardcoded chezmoi source path
- **THEN** no `.tmpl` source file in this change SHALL contain a literal absolute chezmoi
  source path — every occurrence SHALL be the `{{ .chezmoi.sourceDir }}` template variable,
  resolved only in each machine's own untracked, rendered output

### Requirement: Baseline Read from the Managed Settings File

For each profile environment, the script SHALL use that profile's managed-settings source
file, the `.claude-settings.json` in its `dot_claude*/` source directory, read directly as JSON, as its
intended baseline. It SHALL NOT render any template to obtain it. Keys in the baseline that
the drift checks do not read, such as `hooks`, `env`, and `permissions`, SHALL NOT change
drift detection results.

#### Scenario: Named profile baseline resolved
- **WHEN** checking a profile declared in `claude_envs` (e.g. `~/.claude-personal`)
- **THEN** the script SHALL read `home/dot_claude-personal/.claude-settings.json` as
  its baseline

#### Scenario: Unnamed default profile baseline resolved
- **WHEN** checking the unnamed default profile (`~/.claude`)
- **THEN** the script SHALL read `home/dot_claude/.claude-settings.json` as
  its baseline

#### Scenario: Hooks in the baseline do not affect drift
- **WHEN** a profile's baseline contains a `hooks` key
- **THEN** the drift output for that profile SHALL be the same as for an otherwise identical
  baseline without `hooks`

### Requirement: Skill Override Drift Detection

The script SHALL flag any `skillOverrides.<skill>: "off"` entry in a profile's live
`settings.json` where `<skill>` is a native skill (listed under `home/dot_claude/skills/`)
and the profile's baseline does not set that same key to `"off"`.

#### Scenario: Unexplained native skill override flagged
- **WHEN** a profile's live `settings.json` has `skillOverrides.<skill>: "off"` for a
  native skill
- **AND** that profile's rendered baseline has no matching `skillOverrides.<skill>: "off"`
  entry
- **THEN** the script SHALL report that entry as drift

#### Scenario: Baseline-explained override not flagged
- **WHEN** a profile's live `settings.json` has `skillOverrides.<skill>: "off"`
- **AND** that profile's rendered baseline also sets `skillOverrides.<skill>: "off"`
- **THEN** the script SHALL NOT report that entry as drift

### Requirement: Plugin Enablement Drift Detection

The script SHALL flag any `enabledPlugins.<id>: false` entry in a profile's live
`settings.json` where `<id>` appears in `packages.yaml`'s `claude_code.plugins` list and
the profile's baseline does not set that same key to `false`.

#### Scenario: Unexplained plugin disable flagged
- **WHEN** a profile's live `settings.json` has `enabledPlugins.<id>: false` for a plugin
  declared in `packages.yaml`'s `claude_code.plugins` list
- **AND** that profile's rendered baseline has no matching `enabledPlugins.<id>: false` entry
- **THEN** the script SHALL report that entry as drift

### Requirement: Structured Output Format

The script SHALL emit a `## drift` section with one tab-separated line per flagged entry
(`profile`, `kind`, `key`, `value`), matching the sectioned-TSV convention
`list-claude-orphans.sh` already uses, and SHALL emit no lines under that section when no
drift is found.

#### Scenario: Clean machine produces empty section
- **WHEN** no unexplained `skillOverrides` or `enabledPlugins` entries exist on any checked
  profile
- **THEN** the script SHALL print the `## drift` header with no following lines

### Requirement: Default Read-Only Operation
Invoked without `--fix`, the script SHALL NOT modify any `settings.json`, managed-settings
source file, or other Claude Code configuration file.

#### Scenario: No state changed without --fix
- **WHEN** the script runs without `--fix`
- **THEN** no file under any `~/.claude*` directory or the chezmoi source tree SHALL be
  modified

### Requirement: Fix Mode Invocation

The script SHALL accept `--fix <profile> <skillOverrides|enabledPlugins|permissions|env> <key>`
to codify a
single currently-flagged drift entry as an intentional override in the target profile's
managed-settings source file, without accepting the value to write as an argument. If the
file has no `<kind>` object yet, the script SHALL create it.

#### Scenario: Value is read from live settings, not typed
- **WHEN** the user runs `--fix <profile> <kind> <key>`
- **THEN** the script SHALL read the value to write from that profile's live
  `settings.json` entry for `<kind>.<key>`, not from a command-line argument

#### Scenario: Refuses to fix an entry that isn't flagged
- **WHEN** `--fix <profile> <kind> <key>` is run
- **AND** `<kind>.<key>` is not currently reported as drift for `<profile>` (already resolved,
  or never was drift)
- **THEN** the script SHALL exit non-zero without modifying any file
- **AND** SHALL print a message stating the entry is not currently flagged

#### Scenario: Missing kind object is created
- **WHEN** `--fix <profile> <kind> <key>` is run for a flagged entry
- **AND** the profile's managed-settings file has no `<kind>` key
- **THEN** the file SHALL gain a `<kind>` object holding `<key>` with the live value

### Requirement: Fix Mode Verifies Before Writing the Real File
`--fix` SHALL write its edit to a temporary copy of the target managed-settings file, confirm
that the copy is valid JSON holding the new key/value, and only then overwrite the real
source file.

#### Scenario: Verified edit is committed to the real file
- **WHEN** `--fix` writes the new entry into a temporary copy
- **AND** the copy holds the expected key/value
- **THEN** the script SHALL overwrite the real managed-settings file with the copy

#### Scenario: Failed verification leaves the real file untouched
- **WHEN** writing the temporary copy fails, or the expected key/value is absent from it
- **THEN** the script SHALL exit non-zero
- **AND** the real managed-settings file SHALL remain byte-for-byte unchanged

### Requirement: Missing-Baseline Graceful Skip

The script SHALL skip — not error out entirely — a profile declared in `claude_envs` (or the
unnamed default) whose managed-settings file is missing or is not valid JSON, and SHALL
continue checking remaining profiles.

#### Scenario: Declared profile without a matching template
- **WHEN** `claude_envs` declares a profile with no corresponding
  `home/dot_claude-<name>/.claude-settings.json` in the chezmoi source
- **THEN** the script SHALL emit a skip notice for that profile to stderr
- **AND** SHALL continue checking any remaining profiles

### Requirement: Terse Report-Only Session-Start Output

When automatic invocation finds drift, the system SHALL emit a short `additionalContext`/
`systemMessage` pointer directing the user to run `check-claude-overrides` for full detail,
rather than the full sectioned-TSV `## drift` report the on-demand invocation produces. The
automatic invocation SHALL NOT modify any `settings.json`, managed-settings file, or other
Claude Code configuration file.

#### Scenario: Drift found emits a short pointer, not the full report
- **WHEN** automatic invocation finds one or more flagged entries for the current profile
- **THEN** it SHALL emit a short message pointing to `check-claude-overrides` for detail
- **AND** SHALL NOT emit the full sectioned-TSV `## drift` report inline

#### Scenario: No drift produces no message
- **WHEN** automatic invocation finds no flagged entries for the current profile
- **THEN** it SHALL emit no session-start message

#### Scenario: Automatic invocation never writes state
- **WHEN** automatic invocation runs, regardless of whether drift is found
- **THEN** no file under any `~/.claude*` directory or the chezmoi source tree SHALL be
  modified, other than the profile's own dedup state described below

### Requirement: Managed Scalar Drift Detection

The script SHALL flag any key under `permissions` or `env` whose value in the profile's
baseline is a scalar and whose value in the profile's live `settings.json` is present and
different, reporting the live value. Such a runtime change would be reverted by the next
`chezmoi apply`. Keys the baseline does not declare SHALL NOT be flagged.

#### Scenario: Runtime change to a managed scalar flagged
- **WHEN** a profile's baseline sets `permissions.defaultMode` to `"auto"`
- **AND** its live `settings.json` has `permissions.defaultMode` set to `"plan"`
- **THEN** the script SHALL report `permissions`, `defaultMode`, `plan` as drift for that
  profile

#### Scenario: Unmanaged env key not flagged
- **WHEN** a profile's live `settings.json` has `env.MY_VAR`
- **AND** its baseline declares no `env.MY_VAR`
- **THEN** the script SHALL NOT report that key

### Requirement: Profile Environment Enumeration

The profile list — the unnamed default (`~/.claude`) unconditionally, plus every profile declared in the machine's `claude_envs` machine-config list — SHALL be resolved at chezmoi-apply render time via the shared `home/.chezmoitemplates/profile-list` template and baked into the deployed executable as literal values, not discovered by scanning the filesystem or re-derived at runtime.

#### Scenario: Declared profiles checked
- **WHEN** the machine's `claude_envs` list declares one or more named profiles at the time
  `chezmoi apply` last ran
- **THEN** each declared profile's directory SHALL be checked, not only the current
  `$CLAUDE_CONFIG_DIR`

#### Scenario: Unnamed default always checked
- **WHEN** the tool runs
- **THEN** the unnamed default profile (`~/.claude`) SHALL always be checked, regardless of
  `claude_envs`

#### Scenario: Undeclared directory not checked
- **WHEN** a `~/.claude-<name>` directory exists on disk
- **AND** `<name>` is not present in the machine's `claude_envs` list
- **THEN** the tool SHALL NOT check that directory

### Requirement: Automatic Session-Start Invocation Scoped to Current Profile

On Claude Code `SessionStart`, the system SHALL automatically run the drift check for the
single profile whose session is starting (derived from `$CLAUDE_CONFIG_DIR`), via a
`SessionStart` hook entry declared in that profile's managed-settings file and written by the
`claude-settings-modifier` partial. This automatic invocation SHALL NOT check any other
declared profile as part of the same session start.

#### Scenario: Session start checks only the starting profile
- **WHEN** a Claude Code session starts under a given `$CLAUDE_CONFIG_DIR` profile
- **THEN** the drift check SHALL run for that profile only

#### Scenario: Other declared profiles are not checked
- **WHEN** a session starts for one profile
- **AND** other profiles are declared in the machine's `claude_envs` list
- **THEN** those other profiles SHALL NOT be checked as part of that session start

### Requirement: Per-Profile Once-Per-Drift-State Dedup

The system SHALL fingerprint the currently-flagged profile/kind/key/value tuples for the
current profile and compare that fingerprint against the last one recorded for that same
profile. It SHALL emit a session-start message only when the current fingerprint is
non-empty and differs from the last recorded fingerprint for that profile, and SHALL record
the current fingerprint after each automatic invocation.

#### Scenario: Unchanged drift is not re-reported
- **WHEN** the current profile's drift fingerprint is non-empty
- **AND** it matches the fingerprint recorded from that profile's last automatic invocation
- **THEN** the system SHALL NOT emit a session-start message

#### Scenario: New or changed drift is reported
- **WHEN** the current profile's drift fingerprint is non-empty
- **AND** it differs from the fingerprint recorded from that profile's last automatic
  invocation (including no prior recorded fingerprint at all)
- **THEN** the system SHALL emit a session-start message
- **AND** SHALL record the new fingerprint for that profile

#### Scenario: Resolved drift updates recorded state silently
- **WHEN** the current profile's drift fingerprint is empty
- **AND** a prior non-empty fingerprint was recorded for that profile
- **THEN** the system SHALL record the empty fingerprint for that profile
- **AND** SHALL NOT emit a session-start message

#### Scenario: Dedup state is tracked independently per profile
- **WHEN** two different profiles each have their own drift fingerprint history
- **THEN** a fingerprint change on one profile SHALL NOT affect whether a message is emitted
  for another profile's session start

