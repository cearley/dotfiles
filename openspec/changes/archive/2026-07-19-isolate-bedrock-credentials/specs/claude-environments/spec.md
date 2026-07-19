## MODIFIED Requirements

### Requirement: Per-Environment Shell Functions
The partial SHALL define one shell function per Claude environment in the active machine's `claude_envs` list. Each function SHALL invoke `claude` with `CLAUDE_CONFIG_DIR` set to that environment's path for the duration of one invocation. Before invoking `claude`, each function SHALL also, if present, source a local per-environment env file (`~/.config/claude-env/<name>.env`) with its effect scoped to that one invocation only.

#### Scenario: Function generated per claude_envs entry
- **WHEN** the active machine's `claude_envs` contains `~/.claude-<name>`
- **THEN** the partial SHALL define a shell function `claude-<name>`
- **AND** the function SHALL invoke `command claude "$@"` with `CLAUDE_CONFIG_DIR=$HOME/.claude-<name>`
- **AND** the assignment SHALL apply only to that invocation

#### Scenario: Function omitted for environments not in claude_envs
- **WHEN** a name `<x>` is not present in the active machine's `claude_envs`
- **THEN** the partial SHALL NOT define `claude-<x>`
- **AND** typing `claude-<x>` SHALL produce a `command not found` error from the shell

#### Scenario: Override exported default
- **WHEN** `CLAUDE_CONFIG_DIR` is exported to one path and the user runs an environment function for a different env
- **THEN** the function's inline assignment SHALL shadow the exported value for that one process
- **AND** the parent shell's exported value SHALL remain unchanged

#### Scenario: Empty claude_envs
- **WHEN** the active machine has the `ai` tag but `claude_envs` is empty or missing
- **THEN** the partial SHALL define no per-environment functions
- **AND** the partial SHALL render successfully

#### Scenario: Local env file sourced before invocation
- **WHEN** `~/.config/claude-env/<name>.env` exists at the time `claude-<name>` is invoked
- **THEN** the function SHALL source that file before invoking `claude`
- **AND** every variable the file exports SHALL be present in the `claude` process's environment

#### Scenario: Missing env file is a no-op
- **WHEN** `~/.config/claude-env/<name>.env` does not exist
- **THEN** the function SHALL invoke `claude` without attempting to source any file
- **AND** SHALL NOT error or print a warning

#### Scenario: Sourced variables do not leak into the calling shell
- **WHEN** `claude-<name>` sources `~/.config/claude-env/<name>.env` and the resulting `claude` process later exits
- **THEN** none of the variables exported by that file SHALL be present in the parent interactive shell's environment
- **AND** any `CLAUDE_CONFIG_DIR` exported in the parent shell SHALL also remain unchanged

#### Scenario: Env file location is derived from the environment name
- **WHEN** `claude_envs` contains `~/.claude-<name>`
- **THEN** the function SHALL look for its local env file at exactly `~/.config/claude-env/<name>.env`
- **AND** SHALL NOT read env files belonging to other environments

#### Scenario: Env file is untracked and machine-local
- **WHEN** the `claude-environments` partial is rendered by `chezmoi apply`, `chezmoi diff`, or `chezmoi execute-template`
- **THEN** no content of any `~/.config/claude-env/<name>.env` file SHALL be read from or written to chezmoi source state
- **AND** the file SHALL be created and maintained directly by the user on each machine, outside chezmoi's management
