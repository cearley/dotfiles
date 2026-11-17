# Spec Delta

## ADDED Requirements

### Requirement: Complexity check
A fourth layer SHALL run `tests/bin/shellmetrics --csv` against the same rendered bytes the other layers check (plain file content for `*.sh`, the `tests/run-template` output for a template), and SHALL fail the file if any reported function's CCN (cyclomatic complexity number) exceeds 10. This layer SHALL run independently of the lint and format layers: a file that fails shellcheck or shfmt still runs the complexity layer and reports its own result.

#### Scenario: Function under threshold passes
- **WHEN** every function in a checked file has CCN of 10 or less
- **THEN** the complexity layer reports no failure for that file

#### Scenario: Function over threshold fails
- **WHEN** a checked file has a function with CCN greater than 10
- **THEN** the complexity layer fails, printing the function name and its CCN, labelled with its layer, and the run exits non-zero

#### Scenario: Complexity layer runs independently of lint and format
- **WHEN** a checked file has both a shellcheck finding and a function over the CCN threshold
- **THEN** both the lint failure and the complexity failure are reported, each labelled with its own layer

## MODIFIED Requirements

### Requirement: Layered checks
Each file SHALL be checked in order: syntax, then lint, format, and complexity. A syntax failure SHALL skip the later layers for that file. The lint, format, and complexity layers SHALL each run and report independently of one another once syntax passes. Every failure line SHALL name its layer.

#### Scenario: Syntax error stops later layers
- **WHEN** a file contains `if then`
- **THEN** a syntax failure is reported, and the lint, format, and complexity layers don't run on it, and the run exits non-zero

#### Scenario: Lint and format both run on valid syntax
- **WHEN** a file parses but has both a shellcheck finding and a format difference
- **THEN** both are reported, each labelled with its layer

#### Scenario: Complexity runs alongside lint and format
- **WHEN** a file parses but has a shellcheck finding, a format difference, and a function over the complexity threshold
- **THEN** all three are reported, each labelled with its layer
