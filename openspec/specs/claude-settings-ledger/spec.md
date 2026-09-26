# Claude Settings Ledger

## Purpose

Defines how the chezmoi `modify_` script for each Claude Code persona's `settings.json`
tracks every setting chezmoi manages there, hooks included, so that removals in source
reach the live file and entries written by Claude Code, plugins, or the user are preserved.

## Requirements

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
the previous ledger that the current extra settings no longer contain. A scalar leaf whose
key path is absent from the current extra settings SHALL be deleted only if its live value
still equals the value recorded in the ledger. An array element absent from the current
extra settings' array SHALL be removed from the live array if present. Entries present in
both the previous ledger and the current extra settings SHALL NOT be removed and re-added.
The modifier SHALL NOT delete an object or array that retraction leaves empty. When no
previous ledger exists, the modifier SHALL retract nothing.

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

#### Scenario: Entries still in source keep their position
- **WHEN** the live `permissions.allow` is `["A", "X"]`
- **AND** the previous ledger records `"A"`, which is still in the extra settings
- **AND** `"X"` was added outside chezmoi
- **THEN** the output's `permissions.allow` SHALL be `["A", "X"]`

#### Scenario: Emptied container is kept
- **WHEN** retraction removes the only key of `skillOverrides`
- **THEN** the output SHALL contain `"skillOverrides": {}`

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
Apart from JSON re-serialization, the modifier SHALL leave unchanged every key and array
element that is not a leaf listed in the previous or current ledger and is not the ledger
itself. The only exception is the one-time removal of legacy chezmoi hook groups defined in
"One-Time Migration of Legacy Hooks". The modifier SHALL have no other hook-specific
behavior: hooks are managed only through the persona's extra settings and the ledger.

#### Scenario: Claude Code-managed keys survive
- **WHEN** the live `settings.json` contains keys such as `model`, `statusLine`, `hooks`
  entries, or `enabledPlugins` entries that chezmoi never wrote
- **THEN** those keys and values SHALL appear unchanged in the output

#### Scenario: Persona without hooks in source gets none
- **WHEN** a persona's extra settings contain no `hooks` key
- **AND** its live `settings.json` has no ledger-recorded hooks and no legacy chezmoi hooks
- **THEN** the output's `hooks` SHALL equal the input's `hooks`

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

### Requirement: Hooks Managed Through the Ledger
Each persona's extra settings SHALL be the only place where chezmoi declares the hooks it
writes into that persona's `settings.json`. The modifier SHALL treat each hook group, one
element of a `hooks.<Event>` array, as a ledger array element, compared by full JSON value
with object key order ignored. Hook groups SHALL therefore follow the same retraction and
union semantics as every other managed array.

#### Scenario: Hook declared in source is written
- **WHEN** a persona's extra settings contain a `hooks.SessionStart` group running
  `check-claude-overrides --session-start`
- **AND** the live `settings.json` has no such group
- **THEN** the output's `hooks.SessionStart` SHALL contain that group exactly once
- **AND** the ledger SHALL record it as an element of `hooks.SessionStart`

#### Scenario: Edited hook replaces the old group
- **WHEN** the previous ledger records a `hooks.PreToolUse` group with matcher
  `Bash|Edit|Write` running `claude-tooling-write-guard`
- **AND** the extra settings now declare that command with matcher `Bash|Edit|Write|Read`
- **THEN** the output's `hooks.PreToolUse` SHALL contain the new group
- **AND** SHALL NOT contain the old group

#### Scenario: Hook removed from source is retracted
- **WHEN** the previous ledger records a `hooks.PreCompact` group
- **AND** the extra settings no longer declare it
- **THEN** the output's `hooks.PreCompact` SHALL NOT contain that group

#### Scenario: Foreign hooks survive and keep their position
- **WHEN** the live `hooks.SessionStart` is `[G_bd, G_managed, G_iterm]`, where `G_bd` and
  `G_iterm` were added outside chezmoi and `G_managed` is recorded in the ledger and still
  in source
- **THEN** the output's `hooks.SessionStart` SHALL be `[G_bd, G_managed, G_iterm]`, in that
  order

#### Scenario: Rewritten managed group is not recognized
- **WHEN** the live `hooks.SessionStart` holds a single group whose `hooks` array contains
  both a chezmoi-managed command and a foreign command (for example, groups merged outside
  chezmoi)
- **THEN** the modifier SHALL NOT remove or modify that merged group
- **AND** SHALL append the managed group from source as its own element

### Requirement: One-Time Migration of Legacy Hooks
While the previous ledger records no element under any `hooks.<Event>` path, the modifier
SHALL, before applying extra settings, remove every individual hook (an entry of a group's
`hooks` array) whose `command` is one of the frozen legacy commands, and then remove any
group whose `hooks` array that removal left empty. Event arrays SHALL be kept even when
left empty. The frozen legacy commands are:

- `session-topic-capture UserPromptSubmit`
- `session-topic-capture PreCompact`
- `session-topic-capture SessionEnd`
- `claude-tooling-write-guard`
- `check-claude-overrides --session-start`
- `claude-tooling-guard`

Once the ledger records at least one hook element, the modifier SHALL NOT perform this
removal. The legacy list SHALL NOT be extended by later changes.

#### Scenario: Legacy hooks are replaced on first run
- **WHEN** the live `settings.json` has a ledger without hook entries, or no ledger
- **AND** its `hooks.PreToolUse` contains a group with matcher `Bash|Edit` running
  `claude-tooling-write-guard`, which differs from source
- **AND** the extra settings declare `claude-tooling-write-guard` with matcher
  `Bash|Edit|Write`
- **THEN** the output's `hooks.PreToolUse` SHALL contain only the source group for that
  command
- **AND** the ledger SHALL record the source group

#### Scenario: Retired legacy hook is removed
- **WHEN** the live `settings.json` has no hook entries in its ledger
- **AND** a hook group running `claude-tooling-guard` is present
- **THEN** the output SHALL NOT contain that group

#### Scenario: Foreign hooks survive migration
- **WHEN** the migration runs
- **AND** the live `hooks` contain groups running `bd prime` and
  `/Users/craig/.config/iterm2/cc-status`
- **THEN** those groups SHALL appear unchanged in the output

#### Scenario: Foreign command in a merged group survives migration
- **WHEN** the migration runs
- **AND** a `hooks.SessionStart` group's `hooks` array holds `check-claude-overrides
  --session-start` followed by `bd prime`
- **THEN** the output SHALL keep that group with only the `bd prime` hook

#### Scenario: Migration does not repeat
- **WHEN** the previous ledger records at least one hook element
- **AND** the live `settings.json` contains a group running `claude-tooling-write-guard`
  that is not in the ledger (for example, one the user added by hand)
- **THEN** the output SHALL keep that group

#### Scenario: Migration is idempotent
- **WHEN** the modifier runs on legacy input and then runs again on its own output
- **THEN** the second output SHALL be identical to the first
