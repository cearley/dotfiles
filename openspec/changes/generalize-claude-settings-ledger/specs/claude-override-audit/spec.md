# Spec Delta

## MODIFIED Requirements

### Requirement: Baseline Extraction via Template Rendering
For each persona environment, the script SHALL determine its intended managed-settings
baseline by rendering that persona's `modify_settings.json.tmpl` with
`chezmoi execute-template` and extracting the JSON literal produced by the
`claude-settings-modifier` partial's `extra_settings` variable, rather than parsing the
source template's Go `dict(...)` syntax directly. Keys in the baseline that the drift
checks do not read, such as `hooks`, `env`, and `permissions`, SHALL NOT change drift
detection results.

#### Scenario: Named persona baseline resolved
- **WHEN** checking a persona declared in `claude_envs` (e.g. `~/.claude-personal`)
- **THEN** the script SHALL render `home/dot_claude-personal/modify_settings.json.tmpl`
  (the matching `dot_claude-<name>/` source directory) to obtain its baseline

#### Scenario: Unnamed default persona baseline resolved
- **WHEN** checking the unnamed default persona (`~/.claude`)
- **THEN** the script SHALL render `home/dot_claude/modify_settings.json.tmpl` to obtain
  its baseline

#### Scenario: Hooks in the baseline do not affect drift
- **WHEN** a persona's baseline contains a `hooks` key
- **THEN** the drift output for that persona SHALL be the same as for an otherwise identical
  baseline without `hooks`

### Requirement: Automatic Session-Start Invocation Scoped to Current Persona
On Claude Code `SessionStart`, the system SHALL automatically run the drift check for the
single persona whose session is starting (derived from `$CLAUDE_CONFIG_DIR`), via a
`SessionStart` hook entry declared in that persona's `modify_settings.json.tmpl` and written
by the `claude-settings-modifier` partial. This automatic invocation SHALL NOT check any
other declared persona as part of the same session start.

#### Scenario: Session start checks only the starting persona
- **WHEN** a Claude Code session starts under a given `$CLAUDE_CONFIG_DIR` persona
- **THEN** the drift check SHALL run for that persona only

#### Scenario: Other declared personas are not checked
- **WHEN** a session starts for one persona
- **AND** other personas are declared in the machine's `claude_envs` list
- **THEN** those other personas SHALL NOT be checked as part of that session start
