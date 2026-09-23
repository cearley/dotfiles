## MODIFIED Requirements

### Requirement: Path-Scoped Auto-Load Trigger
The rule SHALL declare a `paths:` frontmatter field so it loads only when Claude reads or edits a file matching one of these:
- a Claude settings file (`settings.json`, `.claude.json`) under any persona directory
- `packages.yaml`
- deployed `skills/`, `rules/`, or `plugins/` content, or `CLAUDE.md`, under any persona directory
- the chezmoi source `dot_claude/` or `dot_claude-*/` trees

The frontmatter SHALL contain a glob that actually matches each of these locations.

#### Scenario: Loads when a persona's settings.json is touched
- **WHEN** Claude reads or edits `~/.claude-personal/settings.json` (or the equivalent file under any other declared persona, or the unnamed default `~/.claude`)
- **THEN** Claude Code SHALL auto-load `claude-tooling.md` into context

#### Scenario: Loads when packages.yaml is touched
- **WHEN** Claude reads or edits `home/.chezmoidata/packages.yaml`
- **THEN** Claude Code SHALL auto-load `claude-tooling.md` into context

#### Scenario: Loads when the chezmoi Claude Code source tree is touched
- **WHEN** Claude reads or edits any file under `home/dot_claude/` or `home/dot_claude-<name>/` in the chezmoi source tree
- **THEN** Claude Code SHALL auto-load `claude-tooling.md` into context
- **AND** the rule's `paths:` frontmatter SHALL contain a glob matching those source paths (a `.claude*` glob does not match `dot_claude`)

#### Scenario: Loads when a deployed rule is touched
- **WHEN** Claude reads or edits `~/.claude/rules/global-preferences.md` or any other file under a persona's `rules/`
- **THEN** Claude Code SHALL auto-load `claude-tooling.md` into context

#### Scenario: Does not load for unrelated files
- **WHEN** Claude reads or edits a file that matches none of the declared paths (e.g. a script under `home/.chezmoiscripts/`)
- **THEN** Claude Code SHALL NOT auto-load `claude-tooling.md` on account of that read/edit alone

### Requirement: Content Coverage
The rule's content SHALL cover these topics:
- the distinction between native (repo-authored) and external (`packages.yaml`-declared) skills
- where MCP servers and plugins are declared and installed
- the requirement to cross-check `packages.yaml` before disabling, removing, or overriding any declared skill, MCP server, or plugin
- the persona sharing model: `skills/` and `rules/` are shared via symlink, and `CLAUDE.md` is per-persona
- where chezmoi-managed global preferences live (`rules/global-preferences.md`) and their source edit target
- the distinction between the chezmoi-managed global skill set and the separate, not-chezmoi-managed `chezmoi-personal` plugin marketplace
- how to detect `skillOverrides`/`enabledPlugins` entries that silently diverge from a persona's chezmoi-managed baseline

#### Scenario: Cross-check guidance present
- **WHEN** the rule is loaded
- **THEN** it SHALL instruct that a declared-but-unwanted skill, MCP server, or plugin must be removed by editing `packages.yaml`, not by a local `skillOverrides`/`disabledMcpServers` entry

#### Scenario: Persona sharing model documented
- **WHEN** the rule is loaded
- **THEN** it SHALL state that `skills/` and `rules/` are shared via symlink
- **AND** it SHALL state that `settings.json`, `.claude.json`, `plugins/`, `projects/`, and `CLAUDE.md` are per-persona

#### Scenario: Global preferences edit target documented
- **WHEN** the rule is loaded
- **AND** a diagnosis concludes the global preferences should change
- **THEN** the rule SHALL direct the edit to `{{ .chezmoi.sourceDir }}/dot_claude/rules/global-preferences.md.tmpl`, not to any persona's `CLAUDE.md`

#### Scenario: Override-drift script pointer present
- **WHEN** the rule is loaded
- **THEN** its override-drift guidance SHALL direct the reader to run `check-claude-overrides` to detect unexplained `skillOverrides`/`enabledPlugins` entries, rather than describing a fully manual per-file comparison

#### Scenario: Fix-mode pointer present for the keep resolution
- **WHEN** the rule is loaded
- **AND** the resolve guidance covers the "keep the override" direction
- **THEN** it SHALL direct the reader to `check-claude-overrides --fix <persona> <kind> <key>` instead of describing a fully manual template edit
- **AND** it SHALL state that the "drop the override" direction remains a manual `/skill`/`/plugin` command, unchanged

### Requirement: Path References Use sourceDir Variable
Any reference to the chezmoi source directory within the rule's rendered content SHALL use `{{ .chezmoi.sourceDir }}` rather than a hardcoded path. This matches the convention applied in `home/dot_claude/rules/global-preferences.md.tmpl`.

#### Scenario: Rendered path is machine-correct
- **WHEN** `home/dot_claude/rules/claude-tooling.md.tmpl` is rendered on a machine whose chezmoi source directory is not the default location
- **THEN** any path reference to `packages.yaml` or other source-tree files in the rendered content SHALL resolve to that machine's actual source directory
