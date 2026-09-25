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

Hooks were originally part of this change. They move to the `claude-tooling` plugin in the
`claude-tooling-plugin` change, which lands first, so this change covers extra settings
only.

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
- The legacy hook removal added by `claude-tooling-plugin` is left untouched. That change
  owns the list, including its eventual deletion.

## Non-goals

- Anything about hooks (owned by `claude-tooling-plugin`).
- Renaming `claude-settings-hooks-modifier` (a follow-up once both changes land).
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
- **Depends on:** `claude-tooling-plugin` (same file; that change removes the hook upsert
  first).
- **Tags:** darwin machines with the `ai` tag, all four personas.
- **Live state:** the first apply seeds the record and retracts nothing. Stale keys left by
  removals made before this change need one manual cleanup (task).
- **Security:** an allow entry chezmoi wrote and later dropped from source is still
  reliably revoked. Allow entries granted outside chezmoi now persist, which matches Claude
  Code's model. No secrets are involved.
