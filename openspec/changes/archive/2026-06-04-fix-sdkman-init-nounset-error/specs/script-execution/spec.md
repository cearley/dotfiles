## ADDED Requirements

### Requirement: Third-party tools may suspend nounset mode
When a `run_onchange_` script must source or invoke a third-party tool whose internals are not nounset-safe, the script SHALL bracket the entire third-party section with `set +u` before the first interaction and `set -u` after the last. The suspension SHALL cover all invocations of the tool in that section (source, function calls, CLI calls). The `-e` and `-o pipefail` flags SHALL remain active throughout. The `set +u` line SHALL be preceded by an inline comment naming the tool and explaining why it is not nounset-safe.

#### Scenario: Third-party tool section references unset variables
- **WHEN** a `run_onchange_` script sources or calls a third-party tool (e.g., SDKMAN) that references variables not set in bash (e.g., `$ZSH_VERSION`, `$2`)
- **THEN** the script SHALL place `set +u` before the first interaction with the tool and `set -u` after the last
- **AND** SHALL include a comment before `set +u` naming the tool and the unguarded variables
- **AND** SHALL NOT suppress `-e` or `-o pipefail` during this window

#### Scenario: Suspension is not used for our own code
- **WHEN** code written in the script itself references a variable that might be unset
- **THEN** the script SHALL NOT use `set +u` as a workaround
- **AND** SHALL instead assign a default value or guard the reference explicitly
