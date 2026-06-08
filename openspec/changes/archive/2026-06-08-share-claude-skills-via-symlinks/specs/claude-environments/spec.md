## ADDED Requirements

### Requirement: Shared Skills Directory via Symlink
Every declared Claude environment directory SHALL contain a `skills/` entry that is a symbolic link pointing to `~/.claude/skills/`, ensuring all locally-managed and npm-installed skills are available regardless of the active `CLAUDE_CONFIG_DIR`.

#### Scenario: Skills symlink present in every env dir
- **WHEN** `chezmoi apply` completes on a machine with `ai` tag and a non-empty `claude_envs`
- **THEN** for each entry `~/.claude-<name>` in `claude_envs`, the path `~/.claude-<name>/skills` SHALL be a symbolic link
- **AND** the symlink SHALL resolve to `~/.claude/skills`

#### Scenario: Skills accessible in a non-default environment
- **WHEN** Claude Code is launched with `CLAUDE_CONFIG_DIR=~/.claude-personal`
- **THEN** it SHALL read skills from `~/.claude-personal/skills/`
- **AND** because `~/.claude-personal/skills` is a symlink to `~/.claude/skills`, all locally-managed skills SHALL be available

#### Scenario: Skills installed to any environment land in the shared location
- **WHEN** a skill is written to `~/.claude-<name>/skills/<skill-name>` (e.g., by `npx skills add` with that env's `CLAUDE_CONFIG_DIR`)
- **THEN** the write SHALL resolve through the symlink and create `~/.claude/skills/<skill-name>`
- **AND** the skill SHALL become immediately visible in every other environment without any additional action

#### Scenario: Symlink source managed by chezmoi
- **WHEN** the chezmoi source state for an env dir contains `symlink_skills.tmpl`
- **THEN** the template SHALL render to the absolute path `<home>/.claude/skills`
- **AND** chezmoi SHALL manage the symlink lifecycle (creation and updates)

### Requirement: Transition from Real Directory to Symlink
On machines where Claude Code has previously auto-created a real `skills/` directory inside an environment directory, chezmoi apply SHALL replace that directory with the managed symlink without manual intervention.

#### Scenario: Automated removal of real skills directory before symlink placement
- **WHEN** `chezmoi apply` runs and `~/.claude-<name>/skills` exists as a non-symlink directory
- **THEN** a `run_onchange_before` script SHALL remove that directory before chezmoi attempts to place the symlink
- **AND** the script SHALL log a message identifying the directory being removed

#### Scenario: Transition is idempotent
- **WHEN** the transition script runs and `~/.claude-<name>/skills` is already a symlink (from a prior apply)
- **THEN** the script SHALL skip that entry without error
- **AND** `chezmoi apply` SHALL complete successfully

#### Scenario: Missing environment directory is skipped
- **WHEN** the transition script runs and `~/.claude-<name>` does not yet exist on disk
- **THEN** the script SHALL skip that environment without error
