## ADDED Requirements

### Requirement: Managed Scalar Drift Detection
The script SHALL flag any key under `permissions` or `env` whose value in the persona's
baseline is a scalar and whose value in the persona's live `settings.json` is present and
different, reporting the live value. Such a runtime change would be reverted by the next
`chezmoi apply`. Keys the baseline does not declare SHALL NOT be flagged.

#### Scenario: Runtime change to a managed scalar flagged
- **WHEN** a persona's baseline sets `permissions.defaultMode` to `"auto"`
- **AND** its live `settings.json` has `permissions.defaultMode` set to `"plan"`
- **THEN** the script SHALL report `permissions`, `defaultMode`, `plan` as drift for that
  persona

#### Scenario: Unmanaged env key not flagged
- **WHEN** a persona's live `settings.json` has `env.MY_VAR`
- **AND** its baseline declares no `env.MY_VAR`
- **THEN** the script SHALL NOT report that key

## RENAMED Requirements

- FROM: `### Requirement: Baseline Extraction via Template Rendering`
- TO: `### Requirement: Baseline Read from the Managed Settings File`

## MODIFIED Requirements

### Requirement: Source-Directory Portability
Every chezmoi-source-tree path the tool reads or writes (`packages.yaml`,
`dot_claude/skills/`, each persona's `.claude-settings/<persona>.json`) SHALL
be resolved via `{{ .chezmoi.sourceDir }}` at chezmoi-apply render time, and the source
template SHALL NOT contain a hardcoded absolute path to the chezmoi source directory anywhere
in its body.

#### Scenario: Rendered output works regardless of checkout location
- **WHEN** the chezmoi source repository is checked out at a different absolute path than
  the machine's default, and `chezmoi apply` is run
- **THEN** the rendered `check-claude-overrides` SHALL still correctly locate
  `packages.yaml`, `dot_claude/skills/`, and every persona's managed-settings file

#### Scenario: Only the rendered output names an absolute path
- **WHEN** the change's source files are inspected for a hardcoded chezmoi source path
- **THEN** no `.tmpl` source file in this change SHALL contain a literal absolute chezmoi
  source path — every occurrence SHALL be the `{{ .chezmoi.sourceDir }}` template variable,
  resolved only in each machine's own untracked, rendered output

### Requirement: Baseline Read from the Managed Settings File
For each persona environment, the script SHALL use that persona's managed-settings source
file, `.claude-settings/<persona>.json`, read directly as JSON, as its
intended baseline. It SHALL NOT render any template to obtain it. Keys in the baseline that
the drift checks do not read, such as `hooks`, `env`, and `permissions`, SHALL NOT change
drift detection results.

#### Scenario: Named persona baseline resolved
- **WHEN** checking a persona declared in `claude_envs` (e.g. `~/.claude-personal`)
- **THEN** the script SHALL read `home/.claude-settings/personal.json` as
  its baseline

#### Scenario: Unnamed default persona baseline resolved
- **WHEN** checking the unnamed default persona (`~/.claude`)
- **THEN** the script SHALL read `home/.claude-settings/default.json` as
  its baseline

#### Scenario: Hooks in the baseline do not affect drift
- **WHEN** a persona's baseline contains a `hooks` key
- **THEN** the drift output for that persona SHALL be the same as for an otherwise identical
  baseline without `hooks`

### Requirement: Default Read-Only Operation
Invoked without `--fix`, the script SHALL NOT modify any `settings.json`, managed-settings
source file, or other Claude Code configuration file.

#### Scenario: No state changed without --fix
- **WHEN** the script runs without `--fix`
- **THEN** no file under any `~/.claude*` directory or the chezmoi source tree SHALL be
  modified

### Requirement: Fix Mode Invocation
The script SHALL accept `--fix <persona> <skillOverrides|enabledPlugins|permissions|env> <key>`
to codify a
single currently-flagged drift entry as an intentional override in the target persona's
managed-settings source file, without accepting the value to write as an argument. If the
file has no `<kind>` object yet, the script SHALL create it.

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

#### Scenario: Missing kind object is created
- **WHEN** `--fix <persona> <kind> <key>` is run for a flagged entry
- **AND** the persona's managed-settings file has no `<kind>` key
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
The script SHALL skip — not error out entirely — a persona declared in `claude_envs` (or the
unnamed default) whose managed-settings file is missing or is not valid JSON, and SHALL
continue checking remaining personas.

#### Scenario: Declared persona without a matching template
- **WHEN** `claude_envs` declares a persona with no corresponding
  `home/.claude-settings/<name>.json` in the chezmoi source
- **THEN** the script SHALL emit a skip notice for that persona to stderr
- **AND** SHALL continue checking any remaining personas

### Requirement: Automatic Session-Start Invocation Scoped to Current Persona
On Claude Code `SessionStart`, the system SHALL automatically run the drift check for the
single persona whose session is starting (derived from `$CLAUDE_CONFIG_DIR`), via a
`SessionStart` hook entry declared in that persona's managed-settings file and written by the
`claude-settings-modifier` partial. This automatic invocation SHALL NOT check any other
declared persona as part of the same session start.

#### Scenario: Session start checks only the starting persona
- **WHEN** a Claude Code session starts under a given `$CLAUDE_CONFIG_DIR` persona
- **THEN** the drift check SHALL run for that persona only

#### Scenario: Other declared personas are not checked
- **WHEN** a session starts for one persona
- **AND** other personas are declared in the machine's `claude_envs` list
- **THEN** those other personas SHALL NOT be checked as part of that session start

### Requirement: Terse Report-Only Session-Start Output
When automatic invocation finds drift, the system SHALL emit a short `additionalContext`/
`systemMessage` pointer directing the user to run `check-claude-overrides` for full detail,
rather than the full sectioned-TSV `## drift` report the on-demand invocation produces. The
automatic invocation SHALL NOT modify any `settings.json`, managed-settings file, or other
Claude Code configuration file.

#### Scenario: Drift found emits a short pointer, not the full report
- **WHEN** automatic invocation finds one or more flagged entries for the current persona
- **THEN** it SHALL emit a short message pointing to `check-claude-overrides` for detail
- **AND** SHALL NOT emit the full sectioned-TSV `## drift` report inline

#### Scenario: No drift produces no message
- **WHEN** automatic invocation finds no flagged entries for the current persona
- **THEN** it SHALL emit no session-start message

#### Scenario: Automatic invocation never writes state
- **WHEN** automatic invocation runs, regardless of whether drift is found
- **THEN** no file under any `~/.claude*` directory or the chezmoi source tree SHALL be
  modified, other than the persona's own dedup state described below

## REMOVED Requirements

### Requirement: Fix Mode Requires an Existing Target Sub-Dict
**Reason**: `--fix` now writes JSON with `jq`, which creates a missing object safely. The
sub-dict was only needed as an `awk` insertion anchor in Go template syntax.
**Migration**: None. `--fix` creates the `<kind>` object when it is absent.
