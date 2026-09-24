# Spec Delta

## MODIFIED Requirements

### Requirement: Automatic Session-Start Invocation Scoped to Current Persona
On Claude Code `SessionStart`, the system SHALL automatically run the drift check for the
single persona whose session is starting (derived from `$CLAUDE_CONFIG_DIR`), via a
`SessionStart` hook declared in the `claude-tooling` plugin's `hooks/hooks.json`. This
automatic invocation SHALL NOT check any other declared persona as part of the same session
start. If `check-claude-overrides` is not on `PATH`, the hook SHALL exit 0 silently.

#### Scenario: Session start checks only the starting persona
- **WHEN** a Claude Code session starts under a given `$CLAUDE_CONFIG_DIR` persona
- **THEN** the drift check SHALL run for that persona only

#### Scenario: Other declared personas are not checked
- **WHEN** a session starts for one persona
- **AND** other personas are declared in the machine's `claude_envs` list
- **THEN** those other personas SHALL NOT be checked as part of that session start

#### Scenario: Hook is declared by the plugin, not settings.json
- **WHEN** the persona's `settings.json` is inspected after `chezmoi apply`
- **THEN** it SHALL contain no `check-claude-overrides` hook command
- **AND** the `claude-tooling` plugin's `hooks/hooks.json` SHALL declare the `SessionStart`
  invocation

#### Scenario: Runs exactly once per session start
- **WHEN** a session starts after migration
- **THEN** the drift check SHALL run once, not once from the plugin and again from
  `settings.json`
