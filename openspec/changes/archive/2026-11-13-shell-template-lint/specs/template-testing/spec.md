# Spec Delta

## ADDED Requirements

### Requirement: Mock answers whole-entry show requests
When `show` is invoked without `--attributes`/`-a`, the mock `keepassxc-cli` SHALL print the standard fields `Title`, `UserName`, `Password`, `URL`, and `Notes` as `Key: value` lines, so the chezmoi `keepassxc` template function returns a usable map. Each value SHALL come from the fixture file when present, otherwise `mock:<entry>:<field>`.

#### Scenario: Template reads a standard field
- **WHEN** a template evaluates `(keepassxc "atuin").UserName` under `tests/run-template`
- **THEN** it renders `mock:atuin:UserName` instead of failing with "map has no entry for key"

#### Scenario: Fixture overrides a standard field
- **WHEN** `tests/fixtures/keepassxc.json` defines `"Password"` for an entry
- **THEN** whole-entry `show` prints that fixture value on the `Password:` line

#### Scenario: Attribute requests are unchanged
- **WHEN** `show` is invoked with `--attributes <attr>`
- **THEN** the mock prints only that attribute's value, as before
