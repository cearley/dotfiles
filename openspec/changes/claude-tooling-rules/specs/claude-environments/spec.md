## ADDED Requirements

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
- **THEN** it SHALL become immediately visible in every persona's `rules/` symlink without any additional action

#### Scenario: Symlink source managed by chezmoi
- **WHEN** the chezmoi source state for an env dir contains `symlink_rules.tmpl`
- **THEN** the template SHALL render to the absolute path `<home>/.claude/rules`
- **AND** chezmoi SHALL manage the symlink lifecycle (creation and updates)
