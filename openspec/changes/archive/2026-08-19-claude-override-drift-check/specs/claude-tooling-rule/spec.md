## MODIFIED Requirements

### Requirement: Content Coverage
The rule's content SHALL cover: the distinction between native (repo-authored) and external (`packages.yaml`-declared) skills; where MCP servers and plugins are declared and installed; the requirement to cross-check `packages.yaml` before disabling, removing, or overriding any declared skill, MCP server, or plugin; the persona symlink-sharing model for skills, rules, and `CLAUDE.md`; the distinction between the chezmoi-managed global skill set and the separate, not-chezmoi-managed `chezmoi-personal` plugin marketplace; and how to detect `skillOverrides`/`enabledPlugins` entries that silently diverge from a persona's chezmoi-managed baseline.

#### Scenario: Cross-check guidance present
- **WHEN** the rule is loaded
- **THEN** it SHALL instruct that a declared-but-unwanted skill, MCP server, or plugin must be removed by editing `packages.yaml`, not by a local `skillOverrides`/`disabledMcpServers` entry

#### Scenario: Persona sharing model documented
- **WHEN** the rule is loaded
- **THEN** it SHALL state which persona-level entries are shared via symlink (`skills/`, `rules/`, `CLAUDE.md`) versus which are per-persona (`settings.json`, `.claude.json`, `plugins/`, `projects/`)

#### Scenario: Override-drift script pointer present
- **WHEN** the rule is loaded
- **THEN** its override-drift guidance SHALL direct the reader to run `check-claude-overrides` to detect unexplained `skillOverrides`/`enabledPlugins` entries, rather than describing a fully manual per-file comparison

#### Scenario: Fix-mode pointer present for the keep resolution
- **WHEN** the rule is loaded
- **AND** the resolve guidance covers the "keep the override" direction
- **THEN** it SHALL direct the reader to `check-claude-overrides --fix <persona> <kind> <key>` instead of describing a fully manual template edit
- **AND** it SHALL state that the "drop the override" direction remains a manual `/skill`/`/plugin` command, unchanged
