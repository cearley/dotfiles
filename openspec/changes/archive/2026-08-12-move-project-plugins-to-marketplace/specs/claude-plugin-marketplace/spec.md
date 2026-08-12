## MODIFIED Requirements

### Requirement: Marketplace source is a plain local path, not a published repo
The marketplace SHALL be declared as `.claude-plugin/marketplace.json` at the chezmoi source root, and SHALL NOT itself require a separate published git repository — the marketplace's own registration (the chezmoi source directory's path in the user-scope marketplace registry) is always a local filesystem path. Individual plugin entries listed within the marketplace MAY use either a relative path within the repo (for plugins authored in this repo) or a third-party git/URL source (for plugins that re-point at content published elsewhere).

#### Scenario: Marketplace manifest resolves plugins by relative path
- **WHEN** `.claude-plugin/marketplace.json` lists a self-authored plugin such as `basic-memory-workflow`
- **THEN** its `source` is a relative path (e.g. `./plugins/basic-memory-workflow`) resolved against the marketplace root

#### Scenario: Re-pointed plugin resolves by third-party source
- **WHEN** `.claude-plugin/marketplace.json` lists a plugin whose content is authored and published elsewhere (e.g. `atlassian`)
- **THEN** its `source` MAY be a `git`, `git-subdir`, `url`, or `github` source object pointing at the upstream repo, matching the shape other Claude Code marketplaces use for the same plugin
- **AND** installing that plugin from `chezmoi-personal` SHALL NOT require the upstream marketplace (e.g. `claude-plugins-official`) to also be registered

## ADDED Requirements

### Requirement: Plugins may bundle MCP server definitions via .mcp.json
The marketplace SHALL support plugins whose sole purpose is registering one or more MCP servers, declared via a `.mcp.json` file at the plugin root, using the same command/env shape (including routing through `mcp-env-wrapper` for runtime-injected environment variables) as `packages.yaml`-declared MCP servers.

#### Scenario: MCP-only plugin has no additional structure
- **WHEN** a plugin such as `browser-tools` bundles only MCP server definitions
- **THEN** `.mcp.json` at the plugin root SHALL be sufficient — no `commands/`, `agents/`, or `hooks/` directories are required

#### Scenario: Enabling the plugin registers its servers for that project
- **WHEN** a project enables an MCP-bundling plugin
- **THEN** the MCP servers declared in that plugin's `.mcp.json` SHALL become available in that project without any `packages.yaml` change or `chezmoi apply`

### Requirement: Plugins may wrap external skills via a source and skills array, without a plugin.json
The marketplace SHALL support plugin entries that consist solely of a `source` (pointing at a third-party repo containing one or more Claude Code skills) and a `skills` array (listing the subpaths of that repo to expose as this plugin's content), with no `.claude-plugin/plugin.json` required in this repo.

#### Scenario: Skill bundle wraps a subset of an external repo
- **WHEN** a plugin such as `code-quality` declares `skills: ["clean-code", "refactoring-patterns", ...]` against a `source` pointing at the `wondelai/skills` repo
- **THEN** installing that plugin SHALL make exactly those skills available, without vendoring their content into this repo
