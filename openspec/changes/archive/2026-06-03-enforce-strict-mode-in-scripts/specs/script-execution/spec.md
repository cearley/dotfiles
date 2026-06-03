## ADDED Requirements

### Requirement: Strict Error Mode in run_onchange Scripts
All `run_onchange_` scripts SHALL begin with `set -euo pipefail` immediately after the shebang line. Scripts SHALL NOT use partial error modes such as `set -e` alone or `set -uo pipefail` alone.

#### Scenario: Script fails fast on unexpected error
- **WHEN** any command in a `run_onchange_` script exits with a non-zero status and is not guarded by `if`, `||`, `&&`, or `while`
- **THEN** the script SHALL exit immediately with a non-zero status
- **AND** shall NOT continue executing subsequent commands

#### Scenario: Unset variable is caught
- **WHEN** a shell variable is referenced that has not been assigned a value
- **THEN** the script SHALL exit immediately with an error
- **AND** SHALL NOT silently expand to an empty string

#### Scenario: Pipeline failure is caught
- **WHEN** any command in a pipeline (e.g., `cmd1 | cmd2`) exits with a non-zero status
- **THEN** the pipeline's exit status SHALL reflect that failure
- **AND** if the pipeline result is used as a simple command, the script SHALL exit

#### Scenario: Intentional failure is explicitly handled
- **WHEN** a command is expected to sometimes fail (e.g., checking if a resource already exists)
- **THEN** the script SHALL use an explicit guard: `if !`, `|| true`, `|| { … }`, or capture via `cmd || exit_code=$?`
- **AND** SHALL NOT rely on silent continuation under no-strict-mode behavior
