## MODIFIED Requirements

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

#### Scenario: Skills installation reads agent-scoped list and installs once
- **WHEN** the Claude Code skills installation script (position 37) runs
- **AND** the `ai` tag is selected
- **THEN** it SHALL install every spec listed in `packages.darwin.ai.agents.claude_code.skills`
- **AND** SHALL target `~/.claude` as the single installation environment (i.e., `CLAUDE_CONFIG_DIR=~/.claude`)
- **AND** SHALL NOT loop over `claude_envs` entries to install skills per-environment
- **AND** SHALL NOT iterate over other tags looking for `skills` keys

#### Scenario: Skills are available in all environments without per-env installation
- **WHEN** npm skills are installed to `~/.claude/skills/`
- **AND** all declared Claude environment directories have `skills/` symlinked to `~/.claude/skills/`
- **THEN** every environment SHALL have access to the same installed skills
- **AND** no per-environment installation pass SHALL be required

#### Scenario: Plugin installation reads agent-scoped lists
- **WHEN** the Claude Code plugins installation script (position 39) runs
- **AND** the `ai` tag is selected
- **THEN** it SHALL register every marketplace listed in `packages.darwin.ai.agents.claude_code.plugin_marketplaces`
- **AND** SHALL install every plugin listed in `packages.darwin.ai.agents.claude_code.plugins`
- **AND** SHALL NOT iterate over other tags looking for `plugin_marketplaces` or `plugins` keys

#### Scenario: Audit reads agent-scoped lists
- **WHEN** `audit-packages` runs
- **AND** the `ai` tag is active
- **THEN** the Claude Code sections SHALL compare installed state against `packages.darwin.ai.agents.claude_code.skills`, `plugin_marketplaces`, and `plugins`
- **AND** SHALL NOT scan other tags for those keys
