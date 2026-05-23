## ADDED Requirements

### Requirement: Template-Render-Time Validation of Claude Environment Configuration
The `claude-environments` partial SHALL validate the active machine's `claude_envs` and `claude_default` settings at template-render time and SHALL fail the render with a precise error when validation fails.

#### Scenario: Non-conforming claude_envs entry
- **WHEN** any entry in `claude_envs` for the active machine does not start with `~/.claude-`
- **THEN** rendering the partial SHALL fail
- **AND** the failure message SHALL identify `claude_envs` and the offending entry verbatim

#### Scenario: claude_default not in claude_envs
- **WHEN** `claude_default` for the active machine is set
- **AND** `claude_default` is not equal to `claude-<name>` for any `<name>` derived from `claude_envs`
- **THEN** rendering the partial SHALL fail
- **AND** the failure message SHALL identify `claude_default`, its current value, and the derived list of valid names

#### Scenario: claude_default unset
- **WHEN** the active machine has no `claude_default` set
- **THEN** the partial SHALL NOT validate `claude_default`
- **AND** rendering SHALL succeed regardless of `claude_envs` content

#### Scenario: Validation runs in every render path
- **WHEN** `chezmoi apply`, `chezmoi diff`, `chezmoi cat`, or `chezmoi execute-template` renders the partial
- **THEN** the same validation SHALL run
- **AND** any of those commands SHALL surface the same failure message on misconfiguration

## MODIFIED Requirements

### Requirement: Per-Environment Shell Functions
The partial SHALL define one shell function per Claude environment in the active machine's `claude_envs` list. Each function SHALL invoke `claude` with `CLAUDE_CONFIG_DIR` set to that environment's path for the duration of one invocation.

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

### Requirement: SpecStory Wrapper Aliases
The partial SHALL define `*-spec` aliases that wrap each Claude environment in `specstory run claude --no-cloud-sync`. Per-environment aliases SHALL be generated from the active machine's `claude_envs` list.

#### Scenario: Default spec alias
- **WHEN** the partial is rendered
- **THEN** it SHALL define `alias claude-spec='specstory run claude --no-cloud-sync'`
- **AND** the alias SHALL inherit any exported `CLAUDE_CONFIG_DIR` rather than re-asserting it

#### Scenario: Per-environment spec alias generated per claude_envs entry
- **WHEN** the active machine's `claude_envs` contains `~/.claude-<name>`
- **THEN** the partial SHALL define an alias `claude-<name>-spec`
- **AND** the alias SHALL inline `CLAUDE_CONFIG_DIR=$HOME/.claude-<name>` before `specstory run claude --no-cloud-sync`

#### Scenario: Per-environment spec alias omitted for environments not in claude_envs
- **WHEN** a name `<x>` is not present in the active machine's `claude_envs`
- **THEN** the partial SHALL NOT define `claude-<x>-spec`

#### Scenario: Other tool spec aliases
- **WHEN** the partial is rendered
- **THEN** it SHALL define `codex-spec` and `gemini-spec` aliases for SpecStory wrapping of other AI CLIs

### Requirement: Session Environment Switcher
The partial SHALL define a `claude-env` shell function that switches `CLAUDE_CONFIG_DIR` for the current shell session and refreshes the prompt. The function's accepted arguments SHALL be derived from the active machine's `claude_envs` list at template-render time.

#### Scenario: Switch to an environment present in claude_envs
- **WHEN** the user runs `claude-env <name>` and `~/.claude-<name>` is in the active machine's `claude_envs`
- **THEN** `CLAUDE_CONFIG_DIR` SHALL be exported as `$HOME/.claude-<name>` in the current shell
- **AND** in zsh, `p10k reload` SHALL be called so the prompt segment updates immediately

#### Scenario: Show current environment
- **WHEN** the user runs `claude-env` with no arguments
- **THEN** the function SHALL print the active environment label (e.g., `work`) to stdout
- **AND** SHALL print `(none)` if `CLAUDE_CONFIG_DIR` is unset

#### Scenario: Argument not in claude_envs
- **WHEN** the user runs `claude-env <x>` and `~/.claude-<x>` is not in the active machine's `claude_envs`
- **THEN** the function SHALL NOT modify `CLAUDE_CONFIG_DIR`
- **AND** the function SHALL print a usage message to stderr listing the names derived from `claude_envs`
- **AND** SHALL return exit code 1

#### Scenario: Empty claude_envs
- **WHEN** the active machine has the `ai` tag but `claude_envs` is empty or missing
- **THEN** the function's accepted-arguments set SHALL be empty
- **AND** any non-empty argument SHALL fall through to the usage-message branch
- **AND** the usage message SHALL list no valid names

#### Scenario: Available in both shells
- **WHEN** the partial is sourced by bash
- **THEN** `claude-env` SHALL be available and SHALL switch `CLAUDE_CONFIG_DIR`
- **AND** SHALL NOT attempt to call `p10k reload` (bash has no p10k)

## REMOVED Requirements

### Requirement: Bedrock environment function (subsumed)
**Reason:** The fixed-name scenarios for `claude-bedrock`, `claude-personal`, and `claude-work` are subsumed by the generalized "Function generated per claude_envs entry" scenario in the modified `Per-Environment Shell Functions` requirement. No bedrock-, personal-, or work-specific behavior is preserved.
**Migration:** None. The behavior is unchanged for any machine whose `claude_envs` contains the corresponding path; the same functions are generated.

### Requirement: Personal environment function (subsumed)
**Reason:** Subsumed by the generalized scenario as above.
**Migration:** None.

### Requirement: Work environment function (subsumed)
**Reason:** Subsumed by the generalized scenario as above.
**Migration:** None.

### Requirement: Per-environment spec aliases (fixed names — subsumed)
**Reason:** The fixed list `claude-bedrock-spec, claude-personal-spec, claude-work-spec` is subsumed by the generalized "Per-environment spec alias generated per claude_envs entry" scenario in the modified `SpecStory Wrapper Aliases` requirement.
**Migration:** None. Same aliases are generated for any machine whose `claude_envs` contains the corresponding paths.

### Requirement: claude-env fixed argument set (subsumed)
**Reason:** The fixed accept-list `work|personal|bedrock` and the fixed "Invalid argument" scenario are subsumed by the generalized scenarios in the modified `Session Environment Switcher` requirement, which derive the accept-list from `claude_envs` per machine.
**Migration:** None. On a machine whose `claude_envs` contains `~/.claude-bedrock`, `~/.claude-personal`, and `~/.claude-work`, the accept-list is identical.
