## ADDED Requirements

### Requirement: Global Preferences Delivered as a Shared User-Level Rule
On machines with the `ai` tag, chezmoi SHALL deploy the global preferences as the user-level rule file `~/.claude/rules/global-preferences.md`. The rule SHALL NOT declare `paths:` frontmatter, so Claude Code loads it unconditionally at session start. Every declared persona SHALL receive it through its existing `rules/` symlink.

#### Scenario: Rule deployed on an ai machine
- **WHEN** `chezmoi apply` completes on a machine with the `ai` tag
- **THEN** `~/.claude/rules/global-preferences.md` SHALL exist as a regular file
- **AND** it SHALL contain the global preferences (git permission gates, persona/`$CLAUDE_CONFIG_DIR` notes, Basic Memory guidance)
- **AND** it SHALL NOT contain a `paths:` frontmatter field

#### Scenario: Preferences load in a named persona
- **WHEN** Claude Code starts with `CLAUDE_CONFIG_DIR=~/.claude-<name>` for any `<name>` in `claude_envs`
- **THEN** `global-preferences.md` SHALL be loaded through `~/.claude-<name>/rules/`

#### Scenario: Preferences survive a third-party rewrite of CLAUDE.md
- **WHEN** a third-party tool (for example `omc setup`) rewrites or deletes a persona's `CLAUDE.md`
- **THEN** `~/.claude/rules/global-preferences.md` SHALL be unaffected
- **AND** the preferences SHALL still load in that persona

### Requirement: User-Level CLAUDE.md Is Not Managed by Chezmoi
Chezmoi SHALL NOT manage `CLAUDE.md` in the unnamed default config directory (`~/.claude`) or in any declared persona directory (`~/.claude-<name>`). The file SHALL NOT be managed as a template, a regular file, or a symlink. Each persona's `CLAUDE.md` is owned by whatever third-party tool writes it, or is absent.

#### Scenario: No CLAUDE.md in the managed set
- **WHEN** `chezmoi managed` runs on a machine with the `ai` tag
- **THEN** the output SHALL NOT include `.claude/CLAUDE.md` or `.claude-<name>/CLAUDE.md` for any `<name>`

#### Scenario: Tool-written CLAUDE.md is left alone
- **WHEN** a persona's `CLAUDE.md` is a regular file written by a third-party tool
- **AND** `chezmoi apply` runs
- **THEN** chezmoi SHALL NOT modify, replace, or delete that file
- **AND** `chezmoi status` SHALL NOT report it

### Requirement: Legacy CLAUDE.md Symlinks Removed Safely
On darwin machines with the `ai` tag, `chezmoi apply` SHALL remove any `~/.claude-<name>/CLAUDE.md` for a declared persona if that path is a symbolic link whose target is `~/.claude/CLAUDE.md`. It SHALL NOT remove a regular file, a symlink with any other target, or any path outside the declared personas.

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
