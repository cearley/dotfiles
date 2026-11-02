## MODIFIED Requirements

### Requirement: Retraction of Previously Written Settings

Before applying the current managed settings, the modifier SHALL retract everything that the
previous ledger declares and the current managed settings do not. A scalar whose key the
current managed settings lack SHALL be deleted only if its live value still equals the
previous ledger's value. An array element the current managed settings' array no longer
lists SHALL be removed from the live array if present. Entries present in both the previous
ledger and the current managed settings SHALL NOT be removed and re-added. The modifier SHALL
NOT delete an object or array that retraction leaves empty. When the previous ledger is
absent, is not a string, or does not parse as JSON, the modifier SHALL retract nothing.

#### Scenario: Key removed from source is removed from live file
- **WHEN** the previous ledger declares `skillOverrides.audit-skills = "off"`
- **AND** that key is no longer in the profile's managed settings
- **AND** the live value is still `"off"`
- **THEN** the output SHALL NOT contain `skillOverrides.audit-skills`

#### Scenario: User-changed value is not retracted
- **WHEN** the previous ledger declares `permissions.defaultMode = "auto"`
- **AND** the key is no longer in the managed settings
- **AND** the live value has since been changed to `"plan"` outside chezmoi
- **THEN** the output SHALL keep `permissions.defaultMode = "plan"`

#### Scenario: Array element removed from source is retracted
- **WHEN** the previous ledger lists element `"A"` of `permissions.allow`
- **AND** `"A"` is no longer in the managed settings' `permissions.allow`
- **THEN** the output's `permissions.allow` SHALL NOT contain `"A"`

#### Scenario: Entries still in source keep their position
- **WHEN** the live `permissions.allow` is `["A", "X"]`
- **AND** the previous ledger lists `"A"`, which is still in the managed settings
- **AND** `"X"` was added outside chezmoi
- **THEN** the output's `permissions.allow` SHALL be `["A", "X"]`

#### Scenario: Emptied container is kept
- **WHEN** retraction removes the only key of `skillOverrides`
- **THEN** the output SHALL contain `"skillOverrides": {}`

#### Scenario: First run without a ledger retracts nothing
- **WHEN** the live `settings.json` has no ledger
- **THEN** the modifier SHALL NOT delete any existing key or array element

#### Scenario: Pre-2026-09-26 array ledger retracts nothing
- **WHEN** the live `_chezmoiManaged` is an array (the earlier ledger format)
- **THEN** the modifier SHALL NOT delete any existing key or array element
- **AND** SHALL replace the array with the string ledger

### Requirement: Unmanaged Settings Preserved

Apart from JSON re-serialization, the modifier SHALL leave unchanged every key and array
element that neither the previous ledger nor the current managed settings declare, other than
the ledger itself. The modifier SHALL have no hook-specific behavior.

#### Scenario: Claude Code-managed keys survive
- **WHEN** the live `settings.json` contains keys such as `model`, `statusLine`, `hooks`
  entries, or `enabledPlugins` entries that chezmoi never wrote
- **THEN** those keys and values SHALL appear unchanged in the output

#### Scenario: Profile without hooks in source gets none
- **WHEN** a profile's managed settings contain no `hooks` key
- **AND** its previous ledger declares no hooks
- **THEN** the output's `hooks` SHALL equal the input's `hooks`

### Requirement: Hooks Managed Through the Ledger

Each profile's managed-settings source file SHALL be the only place where chezmoi declares
the hooks it writes into that profile's `settings.json`. The modifier SHALL treat each hook
group, one element of a `hooks.<Event>` array, as an array element, compared by full JSON
value with object key order ignored. Hook groups SHALL therefore follow the same retraction
and union semantics as every other managed array.

#### Scenario: Hook declared in source is written
- **WHEN** a profile's managed settings contain a `hooks.SessionStart` group running
  `check-claude-overrides --session-start`
- **AND** the live `settings.json` has no such group
- **THEN** the output's `hooks.SessionStart` SHALL contain that group exactly once

#### Scenario: Edited hook replaces the old group
- **WHEN** the previous ledger declares a `hooks.PreToolUse` group with matcher
  `Bash|Edit|Write` running `claude-tooling-write-guard`
- **AND** the managed settings now declare that command with matcher `Bash|Edit|Write|Read`
- **THEN** the output's `hooks.PreToolUse` SHALL contain the new group
- **AND** SHALL NOT contain the old group

#### Scenario: Hook removed from source is retracted
- **WHEN** the previous ledger declares a `hooks.PreCompact` group
- **AND** the managed settings no longer declare it
- **THEN** the output's `hooks.PreCompact` SHALL NOT contain that group

#### Scenario: Foreign hooks survive and keep their position
- **WHEN** the live `hooks.SessionStart` is `[G_bd, G_managed, G_iterm]`, where `G_bd` and
  `G_iterm` were added outside chezmoi and `G_managed` is in the previous ledger and still
  in source
- **THEN** the output's `hooks.SessionStart` SHALL be `[G_bd, G_managed, G_iterm]`, in that
  order

#### Scenario: Rewritten managed group is not recognized
- **WHEN** the live `hooks.SessionStart` holds a single group whose `hooks` array contains
  both a chezmoi-managed command and a foreign command (for example, groups merged outside
  chezmoi)
- **THEN** the modifier SHALL NOT remove or modify that merged group
- **AND** SHALL append the managed group from source as its own element

### Requirement: Managed Settings Source Files

Each profile's chezmoi-managed settings SHALL be declared in a `.claude-settings.json` file
in the same source directory as that profile's `modify_settings.json.tmpl`
(`home/dot_claude/` for `~/.claude`, `home/dot_claude-<name>/` for a named profile), as JSON
in the same shape as `settings.json`. Every profile's `modify_settings.json.tmpl` SHALL be
identical and SHALL declare no settings; the `claude-settings-modifier` partial SHALL locate
the sibling file from the caller's `.chezmoi.sourceFile`. Invalid JSON in a source file, or a
source file that is not a JSON object, SHALL fail template rendering.

#### Scenario: Source file mirrors settings.json
- **WHEN** a maintainer wants chezmoi to manage `permissions.defaultMode = "auto"` for the
  personal profile
- **THEN** they SHALL add `"permissions": {"defaultMode": "auto"}` to
  `home/dot_claude-personal/.claude-settings.json`, and no other file

#### Scenario: New profile needs no caller edit
- **WHEN** a maintainer adds a profile by copying `home/dot_claude-work/` to
  `home/dot_claude-new/` and editing only the copied `.claude-settings.json`
- **THEN** rendering `home/dot_claude-new/modify_settings.json.tmpl` SHALL apply that copied
  file, not `home/dot_claude-work/.claude-settings.json`

#### Scenario: Malformed source fails the render
- **WHEN** a profile's source file is not valid JSON
- **THEN** rendering that profile's `modify_settings.json.tmpl` SHALL fail
