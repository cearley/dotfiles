## ADDED Requirements

### Requirement: Claude CLI Invocation per Environment
The `run_claude_in_env` function SHALL run the `claude` CLI against one Claude environment directory, passing all remaining arguments through unchanged and returning `claude`'s exit status. When the directory is `$HOME/.claude` (the unnamed default), it SHALL run `claude` with `CLAUDE_CONFIG_DIR` absent from the environment, even if the caller's environment exports it. For any other directory, it SHALL run `claude` with `CLAUDE_CONFIG_DIR` set to that directory.

#### Scenario: Named persona directory
- **WHEN** `run_claude_in_env "$HOME/.claude-work" mcp list` is called
- **THEN** `claude mcp list` SHALL run with `CLAUDE_CONFIG_DIR=$HOME/.claude-work`

#### Scenario: Unnamed default directory unsets the variable
- **WHEN** `run_claude_in_env "$HOME/.claude" mcp list` is called
- **AND** the caller's environment exports `CLAUDE_CONFIG_DIR=$HOME/.claude-personal`
- **THEN** `claude mcp list` SHALL run with `CLAUDE_CONFIG_DIR` unset

#### Scenario: Exit status and output pass through
- **WHEN** the wrapped `claude` invocation exits non-zero or writes to stdout/stderr
- **THEN** `run_claude_in_env` SHALL return the same exit status and leave the output unaltered
