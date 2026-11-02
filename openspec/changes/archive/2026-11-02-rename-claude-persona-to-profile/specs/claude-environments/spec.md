## MODIFIED Requirements

### Requirement: Shared Rules Directory via Symlink

Every declared Claude environment directory SHALL contain a `rules/` entry that is a symbolic link pointing to `~/.claude/rules/`, ensuring all locally-managed rules are available regardless of the active `CLAUDE_CONFIG_DIR`.

#### Scenario: Rules symlink present in every env dir
- **WHEN** `chezmoi apply` completes on a machine with the `ai` tag and a non-empty `claude_envs`
- **THEN** for each entry `~/.claude-<name>` in `claude_envs`, the path `~/.claude-<name>/rules` SHALL be a symbolic link
- **AND** the symlink SHALL resolve to `~/.claude/rules`

#### Scenario: Rules accessible in a non-default environment
- **WHEN** Claude Code is launched with `CLAUDE_CONFIG_DIR=~/.claude-personal`
- **THEN** it SHALL read rules from `~/.claude-personal/rules/`
- **AND** because `~/.claude-personal/rules` is a symlink to `~/.claude/rules`, all locally-managed rules SHALL be available

#### Scenario: Rules added to the shared location land in every environment
- **WHEN** a rule file is added to `~/.claude/rules/`
- **THEN** it SHALL become immediately visible in every profile's `rules/` symlink without any additional action

#### Scenario: Symlink source managed by chezmoi
- **WHEN** the chezmoi source state for an env dir contains `symlink_rules.tmpl`
- **THEN** the template SHALL render to the absolute path `<home>/.claude/rules`
- **AND** chezmoi SHALL manage the symlink lifecycle (creation and updates)

### Requirement: Global Preferences Delivered as a Shared User-Level Rule

On machines with the `ai` tag, chezmoi SHALL deploy the global preferences as the user-level rule file `~/.claude/rules/global-preferences.md`. The rule SHALL NOT declare `paths:` frontmatter, so Claude Code loads it unconditionally at session start. Every declared profile SHALL receive it through its existing `rules/` symlink.

#### Scenario: Rule deployed on an ai machine
- **WHEN** `chezmoi apply` completes on a machine with the `ai` tag
- **THEN** `~/.claude/rules/global-preferences.md` SHALL exist as a regular file
- **AND** it SHALL contain the global preferences (git permission gates, profile/`$CLAUDE_CONFIG_DIR` notes, Basic Memory guidance)
- **AND** it SHALL NOT contain a `paths:` frontmatter field

#### Scenario: Preferences load in a named profile
- **WHEN** Claude Code starts with `CLAUDE_CONFIG_DIR=~/.claude-<name>` for any `<name>` in `claude_envs`
- **THEN** `global-preferences.md` SHALL be loaded through `~/.claude-<name>/rules/`

#### Scenario: Preferences survive a third-party rewrite of CLAUDE.md
- **WHEN** a third-party tool (for example `omc setup`) rewrites or deletes a profile's `CLAUDE.md`
- **THEN** `~/.claude/rules/global-preferences.md` SHALL be unaffected
- **AND** the preferences SHALL still load in that profile

### Requirement: User-Level CLAUDE.md Is Not Managed by Chezmoi

Chezmoi SHALL NOT manage `CLAUDE.md` in the unnamed default config directory (`~/.claude`) or in any declared profile directory (`~/.claude-<name>`). The file SHALL NOT be managed as a template, a regular file, or a symlink. Each profile's `CLAUDE.md` is owned by whatever third-party tool writes it, or is absent.

#### Scenario: No CLAUDE.md in the managed set
- **WHEN** `chezmoi managed` runs on a machine with the `ai` tag
- **THEN** the output SHALL NOT include `.claude/CLAUDE.md` or `.claude-<name>/CLAUDE.md` for any `<name>`

#### Scenario: Tool-written CLAUDE.md is left alone
- **WHEN** a profile's `CLAUDE.md` is a regular file written by a third-party tool
- **AND** `chezmoi apply` runs
- **THEN** chezmoi SHALL NOT modify, replace, or delete that file
- **AND** `chezmoi status` SHALL NOT report it

### Requirement: Legacy CLAUDE.md Symlinks Removed Safely

On darwin machines with the `ai` tag, `chezmoi apply` SHALL remove any `~/.claude-<name>/CLAUDE.md` for a declared profile if that path is a symbolic link whose target is `~/.claude/CLAUDE.md`. It SHALL NOT remove a regular file, a symlink with any other target, or any path outside the declared profiles.

#### Scenario: Legacy symlink removed
- **WHEN** `~/.claude-<name>/CLAUDE.md` is a symlink to `~/.claude/CLAUDE.md` for a `<name>` in `claude_envs`
- **AND** `chezmoi apply` runs
- **THEN** that symlink SHALL no longer exist afterwards

#### Scenario: Real file preserved
- **WHEN** `~/.claude-<name>/CLAUDE.md` is a regular file
- **AND** `chezmoi apply` runs
- **THEN** the file and its content SHALL be unchanged

#### Scenario: Foreign symlink preserved
- **WHEN** `~/.claude-<name>/CLAUDE.md` is a symlink to any target other than `~/.claude/CLAUDE.md`
- **AND** `chezmoi apply` runs
- **THEN** the symlink SHALL be unchanged

#### Scenario: Idempotent re-run
- **WHEN** no legacy symlink remains
- **AND** the removal step runs again
- **THEN** it SHALL succeed and change nothing
