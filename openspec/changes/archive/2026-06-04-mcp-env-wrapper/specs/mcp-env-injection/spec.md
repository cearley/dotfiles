## ADDED Requirements

### Requirement: Wrapper sources per-server env file before exec
The wrapper script SHALL source `~/.config/mcp-env/<server-name>.env` when the file exists, then exec the given command with all remaining arguments. The server name MUST be passed as the first argument to the wrapper. This applies to both GUI clients (where env injection is necessary) and terminal clients (where it provides launch-context-independent consistency).

#### Scenario: Env file exists with exported variables
- **WHEN** `~/.config/mcp-env/aws-mcp.env` exists and contains `export AWS_PROFILE=di-prod`
- **THEN** the MCP server process SHALL have `AWS_PROFILE=di-prod` in its environment

#### Scenario: Env file does not exist
- **WHEN** no file exists at `~/.config/mcp-env/<server-name>.env`
- **THEN** the wrapper SHALL exec the command without error and without modifying the environment

#### Scenario: Multiple variables in env file
- **WHEN** the env file contains two or more `export KEY=VALUE` lines
- **THEN** all variables SHALL be present in the MCP server's environment

### Requirement: Wrapper passes all args to the target command unchanged
After sourcing the env file, the wrapper SHALL exec the remainder of its argument list (`$@` after shift) as the command and its arguments, preserving order and values exactly.

#### Scenario: Args with spaces or special characters
- **WHEN** an argument contains spaces or special shell characters
- **THEN** the argument SHALL be passed to the target command without modification or splitting

#### Scenario: Command is an absolute path
- **WHEN** the command argument is an absolute path (e.g. `/Users/craig/.local/bin/uvx`)
- **THEN** the wrapper SHALL exec that exact binary

#### Scenario: Command is a bare name resolved via PATH
- **WHEN** the command argument is a bare name (e.g. `npx`, `mcp-env-wrapper`)
- **THEN** the wrapper SHALL exec the first match found in `$PATH`

### Requirement: Wrapper replaces shell process via exec
The wrapper SHALL use `exec` to replace itself with the target process, leaving no intermediate shell in the process tree.

#### Scenario: Process tree after launch
- **WHEN** any client spawns the wrapper as an MCP server
- **THEN** the resulting process SHALL be the target command, not a shell with a child process

### Requirement: Env file location follows XDG convention
Env files SHALL reside at `~/.config/mcp-env/<server-name>.env`. The `<server-name>` MUST match the first argument passed to the wrapper and MUST correspond to the server's key in the client's MCP config (e.g. `claude_desktop_config.json` or Claude Code's user config).

#### Scenario: Correct file path for aws-mcp server
- **WHEN** the wrapper is invoked with server name `aws-mcp`
- **THEN** it SHALL look for an env file at `~/.config/mcp-env/aws-mcp.env`

#### Scenario: Correct file path for localstack-mcp-server
- **WHEN** the wrapper is invoked with server name `localstack-mcp-server`
- **THEN** it SHALL look for an env file at `~/.config/mcp-env/localstack-mcp-server.env`

### Requirement: Env file management follows a hybrid model
Env files containing values sourced from KeePassXC SHALL be chezmoi-managed templates, placed at `home/private_dot_config/mcp-env/private_<server-name>.env.tmpl` with the `private_` prefix. Env files containing personal or local values (e.g. `AWS_PROFILE`) SHALL be user-managed, untracked by chezmoi, and created directly at `~/.config/mcp-env/<server-name>.env`.

#### Scenario: KeePassXC-sourced secret deployed by chezmoi
- **WHEN** a server's env file value is available from KeePassXC
- **THEN** the file SHALL exist at `home/private_dot_config/mcp-env/private_<server-name>.env.tmpl` and be deployed by `chezmoi apply`

#### Scenario: Personal value left as user-managed file
- **WHEN** a server's env file contains a personal or machine-specific value (e.g. `AWS_PROFILE`)
- **THEN** no corresponding file SHALL exist in the chezmoi source tree; the user creates and edits the file directly

### Requirement: Registration script supports bare -- separator
The Claude Code MCP registration script SHALL support entries of the form `<name> -- <command> [args...]` (bare `--` with no preceding `-e` flags) in addition to the existing `<name> [-e VAR]... -- <command> [args...]` form. Both formats MUST register the server correctly.

#### Scenario: Bare -- separator entry
- **WHEN** `packages.yaml` contains `localstack-mcp-server -- mcp-env-wrapper localstack-mcp-server npx -y @localstack/localstack-mcp-server`
- **THEN** the script SHALL register `mcp-env-wrapper` as the command with the remaining tokens as args

#### Scenario: Existing -e flag format still works
- **WHEN** `packages.yaml` contains `basic-memory -s user -- uvx --python 3.12 basic-memory mcp`
- **THEN** the script SHALL register `uvx` as the command with remaining tokens as args, with no `-e` flags
