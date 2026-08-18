# Claude Tooling Rule

## Purpose

Defines the user-level Claude Code rule that delivers installation-health and skill/MCP/plugin diagnostic guidance to the model automatically when relevant files are touched, replacing the previous directory-scoped auto-load with reliable path-scoped triggering.

## Requirements

### Requirement: Rule Deployed to User-Level Rules Directory
The chezmoi source SHALL provide `home/dot_claude/rules/claude-tooling.md.tmpl`, deployed by `chezmoi apply` to `~/.claude/rules/claude-tooling.md`.

#### Scenario: Deployment
- **WHEN** `chezmoi apply` runs on a machine with the `ai` tag
- **THEN** `~/.claude/rules/claude-tooling.md` SHALL exist
- **AND** its content SHALL match the rendered output of `home/dot_claude/rules/claude-tooling.md.tmpl`

### Requirement: Path-Scoped Auto-Load Trigger
The rule SHALL declare a `paths:` frontmatter field so it loads only when Claude reads or edits a file matching one of: Claude settings files (`settings.json`, `.claude.json`) under any persona directory, `packages.yaml`, deployed `skills/`, `plugins/`, or `CLAUDE.md` under any persona directory, or the chezmoi source `dot_claude/`/`dot_claude-*/` trees.

#### Scenario: Loads when a persona's settings.json is touched
- **WHEN** Claude reads or edits `~/.claude-personal/settings.json` (or the equivalent file under any other declared persona, or the unnamed default `~/.claude`)
- **THEN** Claude Code SHALL auto-load `claude-tooling.md` into context

#### Scenario: Loads when packages.yaml is touched
- **WHEN** Claude reads or edits `home/.chezmoidata/packages.yaml`
- **THEN** Claude Code SHALL auto-load `claude-tooling.md` into context

#### Scenario: Loads when the chezmoi Claude Code source tree is touched
- **WHEN** Claude reads or edits any file under `home/dot_claude/` or `home/dot_claude-<name>/` in the chezmoi source tree
- **THEN** Claude Code SHALL auto-load `claude-tooling.md` into context

#### Scenario: Does not load for unrelated files
- **WHEN** Claude reads or edits a file that matches none of the declared paths (e.g. a script under `home/.chezmoiscripts/`)
- **THEN** Claude Code SHALL NOT auto-load `claude-tooling.md` on account of that read/edit alone

### Requirement: Content Coverage
The rule's content SHALL cover: the distinction between native (repo-authored) and external (`packages.yaml`-declared) skills; where MCP servers and plugins are declared and installed; the requirement to cross-check `packages.yaml` before disabling, removing, or overriding any declared skill, MCP server, or plugin; the persona symlink-sharing model for skills, rules, and `CLAUDE.md`; and the distinction between the chezmoi-managed global skill set and the separate, not-chezmoi-managed `chezmoi-personal` plugin marketplace.

#### Scenario: Cross-check guidance present
- **WHEN** the rule is loaded
- **THEN** it SHALL instruct that a declared-but-unwanted skill, MCP server, or plugin must be removed by editing `packages.yaml`, not by a local `skillOverrides`/`disabledMcpServers` entry

#### Scenario: Persona sharing model documented
- **WHEN** the rule is loaded
- **THEN** it SHALL state which persona-level entries are shared via symlink (`skills/`, `rules/`, `CLAUDE.md`) versus which are per-persona (`settings.json`, `.claude.json`, `plugins/`, `projects/`)

### Requirement: Path References Use sourceDir Variable
Any reference to the chezmoi source directory within the rule's rendered content SHALL use `{{ .chezmoi.sourceDir }}` rather than a hardcoded path, consistent with the convention already applied in `home/dot_claude/CLAUDE.md.tmpl`.

#### Scenario: Rendered path is machine-correct
- **WHEN** `home/dot_claude/rules/claude-tooling.md.tmpl` is rendered on a machine whose chezmoi source directory is not the default location
- **THEN** any path reference to `packages.yaml` or other source-tree files in the rendered content SHALL resolve to that machine's actual source directory
