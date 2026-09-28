# Spec Delta

## ADDED Requirements

### Requirement: Shell-safe interpolation of secrets in shell-execution contexts
A secret rendered into a shell-variable-assignment or shell-command-argument context (a `.sh.tmpl` script body, or a dotfile sourced by a shell such as `.zsh_secrets`) SHALL be escaped with shell-safe quoting that neutralizes command substitution and variable expansion within the value, not JSON-style quoting that leaves `$(...)`, backticks, and `$VAR` live.

#### Scenario: Secret value containing command substitution syntax
- **WHEN** a KeePassXC-sourced secret value contains `$(...)` or a backtick-delimited command substitution
- **THEN** the rendered shell script or shell-sourced file SHALL contain that value as an inert, single-quoted (or equivalently escaped) literal
- **AND** sourcing or executing the rendered file SHALL NOT execute the embedded command

#### Scenario: JSON/TOML rendering contexts are unaffected
- **WHEN** a secret or other value is rendered into a JSON or TOML data context (not a shell-execution context)
- **THEN** this requirement does not apply, and JSON-style quoting remains correct for that context
