## ADDED Requirements

### Requirement: Centralized Claude Environment Definitions
The Claude Code multi-environment shell wiring SHALL be defined in exactly one place: a chezmoi template partial at `home/.chezmoitemplates/claude-environments`.

#### Scenario: Single source of truth
- **WHEN** the user wants to modify Claude Code environment functions or aliases
- **THEN** the change SHALL be made only in `home/.chezmoitemplates/claude-environments`
- **AND** SHALL be inherited automatically by both `home/dot_zshrc.tmpl` and `home/dot_bashrc.tmpl`

#### Scenario: Tag-gated activation
- **WHEN** the partial is included by an rc template
- **THEN** the partial SHALL emit no shell code unless `"ai"` is in the user's `tags`

#### Scenario: Self-contained partial
- **WHEN** an rc template calls `{{ includeTemplate "claude-environments" . }}`
- **THEN** the call site SHALL NOT need to add a separate `if has "ai" .tags` guard
- **AND** the partial SHALL handle internal gating

### Requirement: Per-Environment Shell Functions
The partial SHALL define shell functions that invoke `claude` with a specific `CLAUDE_CONFIG_DIR` for the duration of one invocation.

#### Scenario: Bedrock environment function
- **WHEN** the user runs `claude-bedrock <args>`
- **THEN** the shell SHALL invoke `command claude <args>` with `CLAUDE_CONFIG_DIR=$HOME/.claude-bedrock`
- **AND** the assignment SHALL apply only to that invocation

#### Scenario: Personal environment function
- **WHEN** the user runs `claude-personal <args>`
- **THEN** the shell SHALL invoke `command claude <args>` with `CLAUDE_CONFIG_DIR=$HOME/.claude-personal`

#### Scenario: Work environment function
- **WHEN** the user runs `claude-work <args>`
- **THEN** the shell SHALL invoke `command claude <args>` with `CLAUDE_CONFIG_DIR=$HOME/.claude-work`

#### Scenario: Override exported default
- **WHEN** `CLAUDE_CONFIG_DIR` is exported to one path and the user runs an environment function for a different env
- **THEN** the function's inline assignment SHALL shadow the exported value for that one process
- **AND** the parent shell's exported value SHALL remain unchanged

### Requirement: Default Environment via Exported Variable
When the active machine declares a `claude_default` in `home/.chezmoidata/config.yaml`, the partial SHALL export `CLAUDE_CONFIG_DIR` to the corresponding path.

#### Scenario: Machine with claude_default set
- **WHEN** the active machine's pattern in `config.yaml` has `claude_default: claude-work`
- **THEN** the partial SHALL emit `export CLAUDE_CONFIG_DIR="$HOME/.claude-work"`

#### Scenario: Machine without claude_default
- **WHEN** the active machine's pattern in `config.yaml` has no `claude_default` key (e.g., Mac mini)
- **THEN** the partial SHALL NOT emit an export statement
- **AND** the default behavior of `claude` SHALL be the binary's built-in fallback (`~/.claude`)

#### Scenario: No alias for bare claude
- **WHEN** the partial is rendered for a machine with `claude_default` set
- **THEN** the partial SHALL NOT define an alias for `claude`
- **AND** the bare `claude` command SHALL invoke the binary directly with the inherited environment

### Requirement: SpecStory Wrapper Aliases
The partial SHALL define `*-spec` aliases that wrap each Claude environment in `specstory run claude --no-cloud-sync`.

#### Scenario: Default spec alias
- **WHEN** the partial is rendered
- **THEN** it SHALL define `alias claude-spec='specstory run claude --no-cloud-sync'`
- **AND** the alias SHALL inherit any exported `CLAUDE_CONFIG_DIR` rather than re-asserting it

#### Scenario: Per-environment spec aliases
- **WHEN** the partial is rendered
- **THEN** it SHALL define `claude-bedrock-spec`, `claude-personal-spec`, and `claude-work-spec` aliases
- **AND** each SHALL inline a `CLAUDE_CONFIG_DIR=...` prefix that targets its specific environment

#### Scenario: Other tool spec aliases
- **WHEN** the partial is rendered
- **THEN** it SHALL define `codex-spec` and `gemini-spec` aliases for SpecStory wrapping of other AI CLIs

## ADDED Requirements

### Requirement: GUI Session Inheritance via LaunchAgent
On macOS, when the active machine declares a `claude_default`, a user LaunchAgent SHALL inject `CLAUDE_CONFIG_DIR` into the GUI session managed by `launchd` so apps launched from Spotlight, Dock, and Finder inherit the same value as terminal-launched processes.

#### Scenario: LaunchAgent installation
- **WHEN** `chezmoi apply` runs on a macOS machine with `claude_default` set
- **THEN** the file `~/Library/LaunchAgents/<reverse_dns>.claude-config-dir.plist` SHALL exist
- **AND** SHALL have permission mode 644

#### Scenario: LaunchAgent contents
- **WHEN** the LaunchAgent plist is rendered
- **THEN** it SHALL define a label of `<reverse_dns>.claude-config-dir`
- **AND** SHALL declare `ProgramArguments` of `["/bin/launchctl", "setenv", "CLAUDE_CONFIG_DIR", "<home>/.<claude_default>"]`
- **AND** SHALL set `RunAtLoad` to `true`

#### Scenario: Live GUI session update
- **WHEN** the activation script runs
- **THEN** it SHALL call `launchctl setenv CLAUDE_CONFIG_DIR <path>` directly
- **AND** the running GUI session SHALL immediately reflect the new value
- **AND** the user SHALL NOT need to log out

#### Scenario: Already-running GUI app warning
- **WHEN** the activation script completes
- **THEN** it SHALL print a tip via `print_message tip` reminding the user to restart already-running GUI apps to inherit the new value

#### Scenario: Mac mini exclusion
- **WHEN** `chezmoi apply` runs on a machine without `claude_default`
- **THEN** the LaunchAgent plist SHALL NOT be installed
- **AND** the activation script SHALL exit early without invoking `launchctl`

#### Scenario: Idempotent re-bootstrap
- **WHEN** the activation script runs and the LaunchAgent is already loaded
- **THEN** the script SHALL `bootout` the existing agent (tolerating "not loaded" errors)
- **AND** SHALL `bootstrap` the agent fresh
- **AND** SHALL succeed without manual intervention

#### Scenario: Reverse-DNS-derived filename and label
- **WHEN** the LaunchAgent plist is rendered
- **THEN** the filename SHALL be `<reverse_dns>.claude-config-dir.plist`
- **AND** the label SHALL match the filename without the `.plist` suffix
- **AND** both values SHALL be sourced from `{{ .reverse_dns }}` in chezmoi data

### Requirement: Conditional Plist Inclusion
The chezmoi ignore mechanism SHALL exclude the LaunchAgent plist on machines that do not declare `claude_default`.

#### Scenario: Empty claude_default
- **WHEN** the active machine has no `claude_default` in `config.yaml`
- **THEN** `home/.chezmoiignore.tmpl` SHALL list the plist path under an ignore stanza
- **AND** chezmoi SHALL NOT render or install the plist

#### Scenario: Non-empty claude_default
- **WHEN** the active machine has `claude_default` set
- **THEN** the ignore stanza SHALL NOT match
- **AND** the plist SHALL be rendered and installed normally

### Requirement: rc File Integration
Both `home/dot_zshrc.tmpl` and `home/dot_bashrc.tmpl` SHALL include the partial via a single `includeTemplate` call.

#### Scenario: zsh integration
- **WHEN** `home/dot_zshrc.tmpl` is rendered
- **THEN** it SHALL contain exactly one call: `{{ includeTemplate "claude-environments" . }}`
- **AND** the previous duplicated Claude block SHALL be removed

#### Scenario: bash integration
- **WHEN** `home/dot_bashrc.tmpl` is rendered
- **THEN** it SHALL contain exactly one call: `{{ includeTemplate "claude-environments" . }}`
- **AND** the previous duplicated Claude block SHALL be removed

#### Scenario: Identical Claude wiring across shells
- **WHEN** both rc files are rendered for the same machine
- **THEN** the Claude environment functions, exports, and aliases SHALL be byte-identical between them
