# Spec Delta

## Purpose

Defines how the chezmoi `modify_` script for each Claude Code persona's `settings.json`
tracks which extra-settings entries chezmoi owns, so that removals in source reach the live
file and entries written by Claude Code, plugins, or the user are preserved.

## ADDED Requirements

### Requirement: Ledger-Tracked Extra Settings
The modifier SHALL record, in a ledger stored in the same `settings.json`, every leaf entry
it wrote from the caller's extra settings: each scalar leaf as its key path plus written
value, and each array element as the array's key path plus element value. The ledger SHALL
be rewritten on every run to reflect exactly the current extra settings.

#### Scenario: Ledger reflects current extra settings
- **WHEN** the modifier runs with extra settings containing
  `permissions.defaultMode = "auto"` and `permissions.allow = ["A", "B"]`
- **THEN** the ledger in the output SHALL list the `permissions.defaultMode` scalar with value
  `"auto"` and the `permissions.allow` elements `"A"` and `"B"`, and nothing else

#### Scenario: Ledger is valid Claude Code configuration
- **WHEN** Claude Code starts with a `settings.json` containing the ledger
- **THEN** it SHALL load the file without reporting a settings validation error

#### Scenario: Re-applying is idempotent
- **WHEN** the modifier runs twice in a row with unchanged source
- **THEN** the second output SHALL be identical to the first

### Requirement: Retraction of Previously Written Settings
Before applying the current extra settings, the modifier SHALL retract every entry listed in
the previous ledger: it SHALL delete a scalar leaf only if the live value still equals the
value recorded in the ledger, and SHALL remove a recorded array element from the live array
if present. When no previous ledger exists, the modifier SHALL retract nothing.

#### Scenario: Key removed from source is removed from live file
- **WHEN** the previous ledger records `skillOverrides.audit-skills = "off"`
- **AND** that key is no longer in the persona's extra settings
- **AND** the live value is still `"off"`
- **THEN** the output SHALL NOT contain `skillOverrides.audit-skills`

#### Scenario: User-changed value is not retracted
- **WHEN** the previous ledger records `permissions.defaultMode = "auto"`
- **AND** the key is no longer in extra settings
- **AND** the live value has since been changed to `"plan"` outside chezmoi
- **THEN** the output SHALL keep `permissions.defaultMode = "plan"`

#### Scenario: Array element removed from source is retracted
- **WHEN** the previous ledger records element `"A"` of `permissions.allow`
- **AND** `"A"` is no longer in the extra settings' `permissions.allow`
- **THEN** the output's `permissions.allow` SHALL NOT contain `"A"`

#### Scenario: First run without a ledger retracts nothing
- **WHEN** the live `settings.json` has no ledger
- **THEN** the modifier SHALL NOT delete any existing key or array element

### Requirement: Union Semantics for Managed Arrays
When applying extra settings, the modifier SHALL merge each array as an order-preserving
union with the live array (live elements first, then new elements not already present),
rather than replacing it. Scalar leaves from extra settings SHALL overwrite the live value.

#### Scenario: Externally added allow entry survives apply
- **WHEN** the live `permissions.allow` contains `"Bash(git status)"`, which is not in
  extra settings and not in the ledger
- **AND** `chezmoi apply` runs
- **THEN** the output's `permissions.allow` SHALL still contain `"Bash(git status)"`
- **AND** SHALL contain every element of the extra settings' `permissions.allow`

#### Scenario: No duplicate elements
- **WHEN** an element from extra settings is already present in the live array
- **THEN** the output array SHALL contain that element exactly once

### Requirement: Unmanaged Settings Preserved
Apart from JSON re-serialization, the modifier SHALL leave unchanged every key that is not
a leaf listed in the previous or current ledger, is not the ledger itself, and is not a
legacy hook command removed under the `claude-tooling-plugin` capability.

#### Scenario: Claude Code-managed keys survive
- **WHEN** the live `settings.json` contains keys such as `model`, `statusLine`, `hooks`
  entries, or `enabledPlugins` entries that chezmoi never wrote
- **THEN** those keys and values SHALL appear unchanged in the output

### Requirement: Baseline Extraction Compatibility
The rendered modifier SHALL continue to contain exactly one line of the form
`extra_settings='<json>'`, where `<json>` is the caller's extra-settings dict serialized as
JSON on a single line, so that `check-claude-overrides` baseline extraction keeps working
without modification.

#### Scenario: check-claude-overrides still resolves the baseline
- **WHEN** `check-claude-overrides` renders a persona's `modify_settings.json.tmpl`
- **THEN** it SHALL extract a valid JSON baseline equal to that persona's extra settings

### Requirement: Non-AI Machines Unaffected
On machines that are not darwin, or not tagged `ai`, the modifier SHALL pass `settings.json`
through unchanged.

#### Scenario: Pass-through on non-AI machine
- **WHEN** the machine lacks the `ai` tag
- **THEN** the output SHALL equal the input
