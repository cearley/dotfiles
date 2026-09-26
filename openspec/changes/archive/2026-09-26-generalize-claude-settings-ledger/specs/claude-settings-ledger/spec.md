# Spec Delta

## MODIFIED Requirements

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

## ADDED Requirements

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
