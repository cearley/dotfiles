## MODIFIED Requirements

### Requirement: SpecStory Wrappers
The partial SHALL define `*-spec` shell functions (not aliases) that wrap each Claude environment, and other AI CLIs, in `specstory run <cli> --no-cloud-sync`. Per-environment functions SHALL be generated from the active machine's `claude_envs` list. All `*-spec` functions SHALL forward extra arguments via `"$@"`.

#### Scenario: Default spec function
- **WHEN** the partial is rendered
- **THEN** it SHALL define a shell function `claude-spec` whose body invokes `specstory run claude --no-cloud-sync "$@"`
- **AND** the function SHALL inherit any exported `CLAUDE_CONFIG_DIR` rather than re-asserting it
- **AND** `type claude-spec` SHALL report it as a function

#### Scenario: Per-environment spec function generated per claude_envs entry
- **WHEN** the active machine's `claude_envs` contains `~/.claude-<name>`
- **THEN** the partial SHALL define a shell function `claude-<name>-spec` whose body invokes `specstory run claude --no-cloud-sync "$@"` with `CLAUDE_CONFIG_DIR=$HOME/.claude-<name>` set as a single-command assignment
- **AND** the parent shell's `CLAUDE_CONFIG_DIR` SHALL NOT be modified
- **AND** `type claude-<name>-spec` SHALL report it as a function

#### Scenario: Per-environment spec function omitted for environments not in claude_envs
- **WHEN** a name `<x>` is not present in the active machine's `claude_envs`
- **THEN** the partial SHALL NOT define `claude-<x>-spec`

#### Scenario: Other tool spec functions
- **WHEN** the partial is rendered
- **THEN** it SHALL define shell functions `codex-spec` and `gemini-spec`
- **AND** each function body SHALL invoke `specstory run <cli> --no-cloud-sync "$@"` with `<cli>` being `codex` or `gemini` respectively

#### Scenario: Argument forwarding
- **WHEN** the user runs `claude-spec <arg1> <arg2>` (or any `*-spec` function with extra arguments)
- **THEN** the resulting command line SHALL be `specstory run <cli> --no-cloud-sync <arg1> <arg2>`
- **AND** quoting and word-splitting SHALL be preserved as if the function were called by a normal shell function with `"$@"`

#### Scenario: Available in non-interactive shells
- **WHEN** the partial has been sourced (e.g., via `~/.bashrc` or `~/.zshrc`) in a shell where alias expansion is disabled (such as bash without `expand_aliases` set)
- **THEN** `*-spec` invocations SHALL still resolve and execute correctly
- **AND** SHALL produce the same command line as in an interactive shell
