# Spec Delta

## ADDED Requirements

### Requirement: Tooling Context Delivered by the Write Guard
The `claude-tooling` plugin SHALL ship the tooling guidance as `context/claude-tooling.md`.
Its write guard SHALL inject that content as `additionalContext` the first time in a session
that a tool call reads or modifies one of these:
- a Claude settings file (`settings.json`, `.claude.json`) under any persona directory
- `packages.yaml`
- deployed `skills/`, `rules/`, or `plugins/` content, session transcripts (`projects/`),
  or `CLAUDE.md`, under any persona directory
- the chezmoi source `dot_claude/` or `dot_claude-*/` trees

The hook matcher SHALL include `Read` as well as `Bash`, `Edit`, and `Write`.

#### Scenario: Injected when a persona's settings.json is read
- **WHEN** a session first uses the Read tool on `~/.claude-personal/settings.json` (or the
  equivalent file under any other persona)
- **THEN** the guard SHALL emit the tooling context as `additionalContext`

#### Scenario: Injected when packages.yaml is edited
- **WHEN** a session first edits `home/.chezmoidata/packages.yaml`
- **THEN** the guard SHALL emit the tooling context as `additionalContext`

#### Scenario: Injected when the chezmoi Claude Code source tree is touched
- **WHEN** a session first reads or edits a file under `home/dot_claude/` or
  `home/dot_claude-<name>/`
- **THEN** the guard SHALL emit the tooling context as `additionalContext`

#### Scenario: Injected when a persona transcript is read
- **WHEN** a session first reads a file under any persona's `projects/` directory
- **THEN** the guard SHALL emit the tooling context as `additionalContext`

#### Scenario: Injected at most once per session
- **WHEN** the tooling context has already been injected in the current session
- **AND** another matching tool call occurs
- **THEN** the guard SHALL NOT inject it again

#### Scenario: Re-injected after compaction or clear
- **WHEN** a session is compacted or cleared (`SessionStart` with source `compact` or
  `clear`)
- **AND** a matching tool call then occurs
- **THEN** the guard SHALL inject the tooling context again

#### Scenario: Not injected for unrelated files
- **WHEN** a tool call touches only paths outside the list above (e.g. a script under
  `home/.chezmoiscripts/`)
- **THEN** the guard SHALL NOT inject the tooling context on account of that call

### Requirement: Machine Paths Resolved at Run Time
The shipped context file SHALL NOT contain a literal machine-specific source path. The
guard SHALL substitute the chezmoi source directory, repo root, and persona list from
`~/.config/claude-tooling/config.env` into the context at injection time.

#### Scenario: Injected path is machine-correct
- **WHEN** the chezmoi source directory is not at the default location
- **THEN** every source-tree path in the injected context SHALL resolve to that machine's
  actual source directory

## MODIFIED Requirements

### Requirement: Content Coverage
The tooling context's content SHALL cover these topics:
- the distinction between native (repo-authored) and external (`packages.yaml`-declared)
  skills
- where MCP servers and plugins are declared and installed
- the requirement to cross-check `packages.yaml` before disabling, removing, or overriding
  any declared skill, MCP server, or plugin
- the persona sharing model: `skills/` and `rules/` are shared via symlink, and `CLAUDE.md`
  is per-persona
- where chezmoi-managed global preferences live (`rules/global-preferences.md`) and their
  source edit target
- the distinction between the chezmoi-managed global skill set and the `chezmoi-personal`
  plugin marketplace
- how to detect `skillOverrides`/`enabledPlugins` entries that silently diverge from a
  persona's chezmoi-managed baseline
- that chezmoi-managed hooks are declared in the `claude-tooling` plugin's `hooks.json`, not
  in any `settings.json`

#### Scenario: Cross-check guidance present
- **WHEN** the tooling context is injected
- **THEN** it SHALL instruct that a declared-but-unwanted skill, MCP server, or plugin must
  be removed by editing `packages.yaml`, not by a local `skillOverrides`/
  `disabledMcpServers` entry

#### Scenario: Persona sharing model documented
- **WHEN** the tooling context is injected
- **THEN** it SHALL state that `skills/` and `rules/` are shared via symlink
- **AND** it SHALL state that `settings.json`, `.claude.json`, `plugins/`, `projects/`, and
  `CLAUDE.md` are per-persona

#### Scenario: Global preferences edit target documented
- **WHEN** the tooling context is injected
- **AND** a diagnosis concludes the global preferences should change
- **THEN** the context SHALL direct the edit to
  `<source dir>/dot_claude/rules/global-preferences.md.tmpl`, not to any persona's
  `CLAUDE.md`

#### Scenario: Override-drift script pointer present
- **WHEN** the tooling context is injected
- **THEN** its override-drift guidance SHALL direct the reader to run
  `check-claude-overrides` to detect unexplained `skillOverrides`/`enabledPlugins` entries,
  rather than describing a fully manual per-file comparison

#### Scenario: Fix-mode pointer present for the keep resolution
- **WHEN** the tooling context is injected
- **AND** the resolve guidance covers the "keep the override" direction
- **THEN** it SHALL direct the reader to `check-claude-overrides --fix <persona> <kind>
  <key>` instead of describing a fully manual template edit
- **AND** it SHALL state that the "drop the override" direction remains a manual
  `/skill`/`/plugin` command, unchanged

#### Scenario: Hook location documented
- **WHEN** the tooling context is injected
- **THEN** it SHALL state that adding, changing, or retiring a chezmoi-managed hook means
  editing the `claude-tooling` plugin's `hooks/hooks.json`

## REMOVED Requirements

### Requirement: Rule Deployed to User-Level Rules Directory
**Reason**: The guidance is now delivered by the `claude-tooling` plugin's write guard, which
reaches subagents and is re-injected after compaction; path-scoped rules are not guaranteed
to do either.
**Migration**: Delete `home/dot_claude/rules/claude-tooling.md.tmpl`. `chezmoi apply` then
removes `~/.claude/rules/claude-tooling.md`. References to the file (in
`global-preferences.md.tmpl`, `check-claude-overrides`, and the `clean-claude-orphans`
SKILL.md) point to the plugin's `context/claude-tooling.md` instead.

### Requirement: Path-Scoped Auto-Load Trigger
**Reason**: Replaced by "Tooling Context Delivered by the Write Guard", which keeps the same
path list and adds once-per-session and post-compaction behavior.
**Migration**: The `paths:` globs move into the guard's path-matching logic.

### Requirement: Path References Use sourceDir Variable
**Reason**: The context file is static plugin content and is no longer rendered by chezmoi.
**Migration**: Replaced by "Machine Paths Resolved at Run Time", which reads the paths from
`config.env`.
