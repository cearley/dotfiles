# claude-plugin-marketplace Specification

## Purpose
Registers a local Claude Code plugin marketplace pointing at this repo's own chezmoi source tree, so plugins — whether authored inside this repo or re-pointed at content published elsewhere — become installable and enablable without deploying their content through chezmoi's `home/` apply mechanism.

## Requirements

### Requirement: Marketplace source is a plain local path, not a published repo
The marketplace SHALL be declared as `.claude-plugin/marketplace.json` at the chezmoi source root, and SHALL NOT itself require a separate published git repository — the marketplace's own registration (the chezmoi source directory's path in the user-scope marketplace registry) is always a local filesystem path. Individual plugin entries listed within the marketplace MAY use either a relative path within the repo (for plugins authored in this repo) or a third-party git/URL source (for plugins that re-point at content published elsewhere).

#### Scenario: Marketplace manifest resolves plugins by relative path
- **WHEN** `.claude-plugin/marketplace.json` lists a self-authored plugin such as `aws-local-dev`
- **THEN** its `source` is a relative path (e.g. `./plugins/aws-local-dev`) resolved against the marketplace root

#### Scenario: Re-pointed plugin resolves by third-party source
- **WHEN** `.claude-plugin/marketplace.json` lists a plugin whose content is authored and published elsewhere (e.g. `atlassian`)
- **THEN** its `source` MAY be a `git`, `git-subdir`, `url`, or `github` source object pointing at the upstream repo, matching the shape other Claude Code marketplaces use for the same plugin

### Requirement: Marketplace and plugin content are not chezmoi-templated
Files under `.claude-plugin/` and `plugins/` at the chezmoi source root SHALL be plain, non-templated repo content — chezmoi SHALL NOT apply, render, or otherwise deploy them into `$HOME`.

#### Scenario: chezmoi apply leaves plugin content untouched
- **WHEN** `chezmoi apply` runs on a machine with this repo as its source
- **THEN** `.claude-plugin/marketplace.json` and everything under `plugins/` are left exactly as they exist in the source tree — no rendering, no `executable_` handling, no copy into `$HOME`

### Requirement: Marketplace registration is chezmoi-bootstrapped and idempotent
A chezmoi `run_onchange_` script SHALL register the local marketplace with Claude Code by ensuring the chezmoi source directory's absolute path is present in the user-scope marketplace registry, without producing duplicate entries on repeated runs.

#### Scenario: First run on a machine
- **WHEN** the bootstrap script runs on a machine where the marketplace is not yet registered
- **THEN** it adds an entry for this repo's source path to the user-scope registry

#### Scenario: Re-run on an already-registered machine
- **WHEN** the bootstrap script runs again (e.g. after an unrelated `chezmoi apply`)
- **THEN** it detects the existing registration and makes no changes, producing no duplicate entry

### Requirement: Per-project plugin enablement is a separate, manual step
Registering the marketplace SHALL make the plugin installable, but SHALL NOT itself enable the plugin for any project — enabling a specific project happens independently, per the `setup-memory-workflow` capability's opt-in requirement.

#### Scenario: Marketplace registered but no project enabled
- **WHEN** the bootstrap script has registered the marketplace on a machine
- **THEN** no project's `enabledPlugins` is modified as a side effect — every project remains opted out until a human explicitly opts it in

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
