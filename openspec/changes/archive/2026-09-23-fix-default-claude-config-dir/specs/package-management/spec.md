## ADDED Requirements

### Requirement: Claude Registrations Reach the Unnamed Default Config
When a machine declares no `claude_envs`, the MCP-server and plugin install scripts SHALL register into the configuration that a Claude Code session with `CLAUDE_CONFIG_DIR` unset reads. Both scripts SHALL invoke `claude` only through `run_claude_in_env`.

#### Scenario: User-scope MCP server visible to a default session
- **WHEN** the MCP-server install script runs on a machine with no `claude_envs`
- **THEN** each declared user-scope MCP server SHALL appear in `~/.claude.json`
- **AND** `claude mcp list` run with `CLAUDE_CONFIG_DIR` unset SHALL list it

#### Scenario: No stray config file created
- **WHEN** either script runs on a machine with no `claude_envs`
- **THEN** it SHALL NOT create `~/.claude/.claude.json`

#### Scenario: Persona machines unchanged
- **WHEN** either script runs on a machine that declares `claude_envs`
- **THEN** each registration SHALL land in `~/.claude-<name>/` for each declared persona, exactly as before
