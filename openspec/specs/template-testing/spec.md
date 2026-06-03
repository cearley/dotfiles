# template-testing Specification

## Purpose
TBD - created by archiving change keepassxc-mock-test-harness. Update Purpose after archive.
## Requirements
### Requirement: Mock keepassxc-cli binary
The test harness SHALL provide an executable `tests/bin/keepassxc-cli` that implements the chezmoi keepassxc `open`-mode interactive protocol without requiring a real database or credentials.

#### Scenario: Open session returns initial prompt
- **WHEN** chezmoi invokes `keepassxc-cli open <database>`
- **THEN** the mock emits `> ` immediately without prompting for a password

#### Scenario: Show command returns fixture value
- **WHEN** chezmoi sends `show "<entry>" --attributes <attr> --quiet --show-protected`
- **THEN** the mock returns the value from `tests/fixtures/keepassxc.json` for that entry/attribute pair

#### Scenario: Show command auto-generates for unknown entries
- **WHEN** chezmoi sends a show command for an entry/attribute not present in the fixture file
- **THEN** the mock returns `mock:<entry>:<attr>`

#### Scenario: Exit command terminates session
- **WHEN** chezmoi sends `exit`
- **THEN** the mock exits with code 0

#### Scenario: Direct show mode supported
- **WHEN** chezmoi invokes `keepassxc-cli show [-q] [-a <attr>] <database> <entry>`
- **THEN** the mock returns the same fixture or auto-generated value as open mode

#### Scenario: ls output excludes metadata keys
- **WHEN** `keepassxc-cli ls` is invoked and the fixture file contains keys prefixed with `_`
- **THEN** those keys are excluded from the output

### Requirement: Optional fixture file for format-sensitive values
The harness SHALL support a JSON fixture file at `tests/fixtures/keepassxc.json` that pins specific entry/attribute values. The fixture file SHALL be optional — the mock MUST operate correctly when the file is absent.

#### Scenario: Fixture value takes precedence
- **WHEN** an entry/attribute pair exists in `tests/fixtures/keepassxc.json`
- **THEN** the mock returns that value instead of auto-generating

#### Scenario: Missing fixture file falls back to auto-generation
- **WHEN** the default fixture path (`tests/fixtures/keepassxc.json`) does not exist
- **THEN** every lookup returns `mock:<entry>:<attr>` without error

#### Scenario: Explicit fixture path must exist
- **WHEN** `KEEPASSXC_MOCK_FIXTURES` or `--fixtures` is set to a path that does not exist
- **THEN** the runner exits with an error before invoking chezmoi

#### Scenario: Fixture path overridable via environment
- **WHEN** `KEEPASSXC_MOCK_FIXTURES` is set to an alternate path
- **THEN** the mock reads fixtures from that path

### Requirement: Template test runner
The harness SHALL provide `tests/run-template` that renders any chezmoi template using the mock without touching the real KeePassXC database.

#### Scenario: Render a template file
- **WHEN** `tests/run-template <path/to/template.tmpl>` is invoked
- **THEN** the template renders to stdout with all `keepassxcAttribute` calls returning mock values

#### Scenario: Render an inline template string
- **WHEN** `tests/run-template --inline '<{{ keepassxcAttribute "Entry" "Attr" }}>'` is invoked
- **THEN** the inline template renders to stdout

#### Scenario: Works for templates without keepassxc calls
- **WHEN** a template contains no `keepassxcAttribute` calls
- **THEN** `tests/run-template` renders it correctly using real config data

#### Scenario: Custom fixtures path
- **WHEN** `tests/run-template --fixtures <path>` is invoked
- **THEN** the mock uses the specified fixture file for that run

#### Scenario: Missing template file produces clear error
- **WHEN** `tests/run-template` is invoked with a path that does not exist
- **THEN** the runner exits with a clear error naming the missing file before invoking chezmoi

