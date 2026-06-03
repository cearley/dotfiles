## ADDED Requirements

### Requirement: Shell scripts must not contain unreachable command typos
All shell scripts SHALL use valid shell commands in all reachable branches, including error and cancel paths. A typo that causes `command not found` in any branch is a bug, regardless of whether the happy path is unaffected.

#### Scenario: Microsoft Defender cancel path executes without error
- **WHEN** the user cancels the Defender installation dialog
- **THEN** the cancel branch SHALL execute without a `command not found` error

### Requirement: PATH entries in zshrc must use single-slash separators
The generated `.zshrc` SHALL contain PATH entries with exactly one slash between path components. Double-slash separators (`//`) are unintentional and must not appear.

#### Scenario: zshrc HOME bin path is well-formed
- **WHEN** chezmoi renders `dot_zshrc.tmpl`
- **THEN** the rendered output SHALL contain `$PATH:$HOME/bin` or `$PATH:/Users/<user>/bin` with a single slash — never `//bin`

### Requirement: Home-relative paths must use chezmoi template variables
All template files SHALL use `{{ .chezmoi.homeDir }}` (or the shell variable `$HOME`) for home-relative paths. Hardcoded absolute paths containing a specific username (`/Users/craig/`) are forbidden.

#### Scenario: zshrc fpath entry is portable
- **WHEN** chezmoi renders `dot_zshrc.tmpl` on a machine with a different username
- **THEN** the fpath entry for oh-my-zsh custom completions SHALL resolve to the correct home directory for that machine

#### Scenario: MCP server config paths are portable
- **WHEN** chezmoi renders `tools.json.tmpl` on any machine
- **THEN** the rendered MCP server `command` and path values SHALL not contain a hardcoded username

### Requirement: MCP server node command must not pin a specific nvm version
The MCP server configuration SHALL NOT hardcode a specific nvm node version path (e.g., `.nvm/versions/node/v24.7.0/bin/node`). The `node` executable SHALL be referenced in a way that picks up the active nvm version at runtime.

#### Scenario: MCP server config survives a node version upgrade
- **WHEN** the user upgrades their node version via nvm
- **THEN** the MCP server SHALL continue to function without any change to `tools.json.tmpl`
