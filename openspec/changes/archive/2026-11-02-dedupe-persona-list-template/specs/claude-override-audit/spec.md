## MODIFIED Requirements

### Requirement: Persona Environment Enumeration
The persona list — the unnamed default (`~/.claude`) unconditionally, plus every persona declared in the machine's `claude_envs` machine-config list — SHALL be resolved at chezmoi-apply render time via the shared `home/.chezmoitemplates/persona-list` template and baked into the deployed executable as literal values, not discovered by scanning the filesystem or re-derived at runtime.

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
