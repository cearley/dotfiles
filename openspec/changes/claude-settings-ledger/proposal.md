# Proposal

## Why

`claude-settings-hooks-modifier` merges each persona's extra settings (`skillOverrides`,
`enabledPlugins`, `permissions`, `env`) into the live `settings.json` with jq `. * $extra`.
That merge drifts in both directions:

- **Object keys persist.** A key deleted from source (a skill override, a plugin enablement,
  an env var) stays in the live file forever. Nothing removes it, because chezmoi keeps no
  record of what it wrote.
- **Arrays are replaced wholesale.** `permissions.allow` is overwritten on every
  `chezmoi apply`, which wipes entries added outside chezmoi. The live `permissions.allow`
  lists currently match the source lists exactly.

Hooks were originally part of this change. They are out of scope here: the modifier's
existing hook stage (the `managed_hooks` upsert and the `retired_commands` strip) is left
as it is. The optional `claude-tooling-plugin` change may later move hooks out of
`settings.json`, but this change neither depends on it nor assumes it will happen.

## What Changes

- **Ownership record ("ledger").** The modifier records every leaf it writes from `$extra`
  in a `_chezmoiManaged` key inside `settings.json`. Scalar values are recorded with their
  value; array elements are recorded individually. On each apply it first retracts the
  entries in the previous record that source no longer contains. A scalar is removed only
  if its live value still equals the value chezmoi wrote. Entries still in source are left
  in place. Then the modifier applies the current `$extra` and writes a fresh record.
- **BREAKING (behavior):** arrays (e.g. `permissions.allow`) are merged as an
  order-preserving union instead of being replaced. Entries added outside chezmoi survive an
  apply. Entries chezmoi added and later dropped from source are retracted through the
  record.
- The `extra_settings='…'` line stays byte-compatible for `check-claude-overrides`.
- The modifier's hook stage runs before the extra-settings stage and is left untouched.

## Non-goals

- Anything about hooks. The hook stage keeps its current upsert and `retired_commands`
  behavior.
- Renaming `claude-settings-hooks-modifier`. The name stays accurate while the hook stage
  exists; a rename only makes sense if `claude-tooling-plugin` ever removes it.
- Managing `settings.local.json`, project settings, or `managed-settings.json`.
- Changing drift detection in `check-claude-overrides`.

## Capabilities

### New Capabilities
- `claude-settings-ledger`: ownership tracking for the extra settings chezmoi merges into
  persona `settings.json` files. Covers the ownership record, retraction of settings chezmoi
  previously wrote, union semantics for arrays, preservation of entries chezmoi didn't
  write, and compatibility with baseline extraction.

### Modified Capabilities
<!-- None: claude-override-audit baseline extraction is preserved unchanged. -->

## Impact

- **Code:** the extra-settings stage of `home/.chezmoitemplates/claude-settings-hooks-modifier`.
  The four `modify_settings.json.tmpl` callers are unchanged.
- **Tests:** a fixture-driven modifier test under `tests/`.
- **Depends on:** nothing. It can be implemented and archived on its own.
- **Related:** the optional `claude-tooling-plugin` change edits the hook stage of the same
  modifier. If it is ever implemented, it lands after this change and keeps the ledger
  stage intact.
- **Tags:** darwin machines with the `ai` tag, all four personas.
- **Live state:** the first apply seeds the record and retracts nothing. Stale keys left by
  removals made before this change need one manual cleanup (task).
- **Security:** an allow entry chezmoi wrote and later dropped from source is still
  reliably revoked. Allow entries granted outside chezmoi now persist, which matches Claude
  Code's model. No secrets are involved.
