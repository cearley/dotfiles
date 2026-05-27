## ADDED Requirements

### Requirement: AI Coding Agent Configuration Namespace
The `packages.darwin.ai` section SHALL provide an `agents` sub-namespace for per-coding-agent configuration. Each direct child of `agents` SHALL be a coding-agent identifier (e.g. `claude_code`, `codex`, `gemini`), and its value SHALL be a mapping of agent-specific configuration keys to lists.

#### Scenario: Agents namespace exists under ai tag
- **WHEN** `packages.yaml` is parsed
- **THEN** the path `packages.darwin.ai.agents` SHALL exist
- **AND** SHALL contain at least one agent entry

#### Scenario: Agent identifier shape
- **WHEN** an agent is added under `agents`
- **THEN** the key SHALL be a lowercase snake_case identifier matching the agent's canonical name (e.g. `claude_code`, `codex`, `gemini`)
- **AND** the value SHALL be a mapping (not a list or scalar)

### Requirement: Claude Code Agent Configuration Keys
The `packages.darwin.ai.agents.claude_code` mapping SHALL accept the following keys, each containing a list:

- `mcp_servers` — Model Context Protocol server registrations, each item formatted as `"<name> <command...>"` (e.g. `"playwright npx @playwright/mcp@latest"`).
- `skills` — Skill collection specs consumed by `npx skills add` (e.g. `"specstoryai/agent-skills -all"`).
- `plugin_marketplaces` — Marketplace sources consumed by `claude plugins marketplace add` (GitHub `org/repo` references or full git URLs).
- `plugins` — Plugin identifiers consumed by `claude plugins install`, in `<plugin>@<marketplace>` form.

#### Scenario: Claude Code keys live under agents.claude_code
- **WHEN** Claude-Code-specific items are declared in `packages.yaml`
- **THEN** they SHALL appear under `packages.darwin.ai.agents.claude_code.<key>`
- **AND** SHALL NOT appear under `packages.darwin.dev.*` or directly under `packages.darwin.ai.*`

#### Scenario: Skills installation reads agent-scoped list
- **WHEN** the Claude Code skills installation script (position 37) runs
- **AND** the `ai` tag is selected
- **THEN** it SHALL install every spec listed in `packages.darwin.ai.agents.claude_code.skills`
- **AND** SHALL NOT iterate over other tags looking for `skills` keys

#### Scenario: Plugin installation reads agent-scoped lists
- **WHEN** the Claude Code plugins installation script (position 38) runs
- **AND** the `ai` tag is selected
- **THEN** it SHALL register every marketplace listed in `packages.darwin.ai.agents.claude_code.plugin_marketplaces`
- **AND** SHALL install every plugin listed in `packages.darwin.ai.agents.claude_code.plugins`
- **AND** SHALL NOT iterate over other tags looking for `plugin_marketplaces` or `plugins` keys

#### Scenario: Audit reads agent-scoped lists
- **WHEN** `audit-packages` runs
- **AND** the `ai` tag is active
- **THEN** the Claude Code sections SHALL compare installed state against `packages.darwin.ai.agents.claude_code.skills`, `plugin_marketplaces`, and `plugins`
- **AND** SHALL NOT scan other tags for those keys

### Requirement: Coding Agent Configuration Tag Gating
Per-agent configuration under `ai.agents.<agent>` SHALL be gated on the `ai` tag, regardless of whether `dev` is also selected.

#### Scenario: ai tag absent
- **WHEN** the `ai` tag is NOT selected
- **THEN** no script SHALL install any item declared under `packages.darwin.ai.agents.*`
- **AND** `audit-packages` SHALL skip the agent-specific audit sections

#### Scenario: ai tag selected without dev
- **WHEN** the `ai` tag is selected and the `dev` tag is NOT
- **THEN** every item declared under `packages.darwin.ai.agents.claude_code.*` SHALL be installable
- **AND** SHALL NOT require the `dev` tag

### Requirement: MCP Servers Key Naming
The Claude Code MCP server list SHALL use the key name `mcp_servers` (not `mcp`).

#### Scenario: Key name is mcp_servers
- **WHEN** MCP servers are declared
- **THEN** the key SHALL be `packages.darwin.ai.agents.claude_code.mcp_servers`
- **AND** the key `mcp` SHALL NOT appear anywhere in `packages.darwin.*`

### Requirement: Claude Code MCP Server Installation Script
The system SHALL install declared Claude Code MCP servers via a dedicated `run_onchange_after` script at position 38.

#### Scenario: Script exists and is gated
- **WHEN** chezmoi applies configuration on darwin
- **AND** the `ai` tag is selected
- **THEN** `run_onchange_after_darwin-38-install-claude-mcp-servers.sh.tmpl` SHALL execute
- **AND** SHALL skip cleanly when the `ai` tag is not selected

#### Scenario: Server registration command
- **WHEN** the script processes a server entry
- **AND** the entry has the form `"<name> <command...>"`
- **THEN** the script SHALL invoke `claude mcp add --scope user <name> -- <command...>` for each declared Claude environment

#### Scenario: Per-environment registration
- **WHEN** the user has multiple Claude environments configured via `claude_envs`
- **THEN** the script SHALL register every declared MCP server in every existing environment
- **AND** SHALL skip environments whose directory does not yet exist (with a `skip` message)

#### Scenario: Idempotent re-run
- **WHEN** the script runs again with the same server list
- **THEN** `claude mcp add` SHALL report an "already registered" condition
- **AND** the script SHALL log a warning but continue with remaining entries
- **AND** SHALL NOT abort the overall apply

#### Scenario: Position relative to other Claude scripts
- **WHEN** chezmoi orders `run_onchange_after` scripts
- **THEN** Claude MCP install (position 38) SHALL run after Claude skills (37)
- **AND** SHALL run before Claude plugins (renamed to 39)
- **AND** Claude LaunchAgent (renamed to 40) SHALL run last

### Requirement: Claude Code MCP Audit
The `audit-packages` script SHALL audit registered MCP servers against the declared list.

#### Scenario: MCP audit section present
- **WHEN** `audit-packages` runs with the `ai` tag active and `claude` available
- **THEN** it SHALL emit a section labeled "Claude Code MCP Servers"
- **AND** SHALL list any server registered in Claude config but not declared in `packages.darwin.ai.agents.claude_code.mcp_servers`

#### Scenario: Comparison is by name
- **WHEN** comparing installed and declared MCP entries
- **THEN** only the server name (first whitespace-delimited token of each declared entry) SHALL be used
- **AND** the launch command portion SHALL be ignored

### Requirement: Coding Agent Schema Documentation
The `ai.agents` namespace SHALL document the schema for not-yet-active coding agents via commented YAML stubs.

#### Scenario: Stubs for unimplemented agents
- **WHEN** an additional coding agent (e.g. `codex`, `gemini`) is anticipated but not yet wired up
- **THEN** `packages.yaml` SHALL include a commented placeholder block under `ai.agents` showing the expected keys for that agent
- **AND** the placeholder SHALL NOT contain live YAML keys (no empty `codex: {}`)

#### Scenario: Activating a stubbed agent
- **WHEN** the user starts using a previously-stubbed agent
- **THEN** uncommenting the placeholder block and populating its lists SHALL be the entire opt-in action at the data layer
