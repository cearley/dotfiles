# Proposal

## Why

`claude-settings-hooks-modifier` currently has two ways of managing `settings.json`:

- **Hooks** are upserted by command name. A hook is removed only if it is listed in a
  hand-maintained `retired_commands` list.
- **Everything else** goes through the `_chezmoiManaged` ledger, which retracts what source
  drops and needs no list.

The ledger already handles arrays of objects, and `hooks.<Event>` is exactly that. Moving
hooks onto the ledger gives one mechanism for everything, deletes the retirement list, and
puts all of a persona's managed settings in its own `modify_settings.json.tmpl`.

## What Changes

- **All managed settings, hooks included, are declared per persona.** Each persona's
  `modify_settings.json.tmpl` `$extra` dict lists everything chezmoi manages in that
  persona's `settings.json`: `hooks`, `permissions`, `env`, `skillOverrides`,
  `enabledPlugins`, the `sync*` flags, and anything else. The five hook entries are repeated
  in all four persona templates. That choice was made deliberately, so every persona file
  is self-contained, at the cost of changing four files for a hook edit.
- **Hooks are ledger-tracked.** Each hook group in `hooks.<Event>` is one ledger array
  element. Editing a hook (for example, its matcher) retracts the old group and adds the
  new one. Removing a hook from source retracts it. Hooks added outside chezmoi (iTerm
  `cc-status`, `bd prime`) are untouched.
- **Removed:** the modifier's hook stage (`managed_hooks`), its command-name upsert, and
  `retired_commands`.
- **One-time hook migration.** Live files that predate this change have chezmoi hooks the
  ledger doesn't record. While the ledger records no `hooks` entry, the modifier first
  strips every hook group whose command is on a frozen list of the six commands chezmoi has
  ever written (the five current ones plus `claude-tooling-guard`), and then applies source.
  Once the ledger records hooks, the migration stops acting for that persona. The code can
  be deleted after every machine has applied. Unlike `retired_commands`, the list never
  grows.
- **Rename:** `claude-settings-hooks-modifier` → `claude-settings-modifier`. The
  `extra_settings='…'` line keeps its format, so `check-claude-overrides` baseline
  extraction is unaffected.
- **Side effect:** managed hooks keep their position. Today every apply moves them behind
  hooks added by other tools.

## Non-goals

- A shared base dict or partial for the settings common to all personas. Duplication per
  persona is intentional.
- Changing the ledger's semantics: scalars still overwrite, arrays merge as a union, and
  retraction compares values before removing a scalar.
- Tolerating Claude Code rewriting a managed hook group (for example, merging two groups
  with the same matcher). The expected behavior is documented by a fixture, but matching
  stays exact equality.
- Managing `settings.local.json`, project settings, or `managed-settings.json`.
- Changing `check-claude-overrides` drift detection, or `--fix`, beyond reference updates.
- Deciding the fate of the optional `claude-tooling-plugin` change. It is affected (see
  Impact), but it is not revised here.

## Capabilities

### New Capabilities
<!-- None -->

### Modified Capabilities
- `claude-settings-ledger`: the ledger covers every managed setting including hooks. The
  hook-stage carve-out is dropped from "Unmanaged Settings Preserved". New requirements
  cover hook edits, removal, and position, plus the one-time migration of legacy hooks.
- `claude-override-audit`: two requirements name `claude-settings-hooks-modifier`
  (baseline extraction and the session-start hook). They are reworded for the renamed
  partial and for the hook now being declared in each persona's template.

## Impact

- **Code:**
  - `home/.chezmoitemplates/claude-settings-hooks-modifier`, renamed to
    `claude-settings-modifier` (hook stage removed, migration added)
  - the four `home/dot_claude*/modify_settings.json.tmpl` files (hooks added to `$extra`,
    new partial name)
- **Tests:** `tests/test-claude-settings-ledger.sh` and its fixtures. The partial name
  changes, and fixture 09's hook expectations are now driven by `extra.json`. New fixtures
  cover hook edit, removal, foreign hooks, migration, and a merged-group input.
- **Docs:** `home/.chezmoitemplates/CLAUDE.md`, `home/dot_claude/rules/claude-tooling.md.tmpl`,
  and the comment in `home/dot_local/bin/executable_check-claude-overrides.tmpl`.
- **Related change:** `claude-tooling-plugin` (optional, 0/18) plans to remove hooks from
  `settings.json` using a fixed legacy removal list (its tasks 4.1 and 4.5). With this
  change, that step becomes "delete the hooks from each persona's `$extra`", and the ledger
  retracts them. Its tasks 4.1 and 4.5 and design D6 would need revising before it is ever
  implemented.
- **Tags:** darwin machines with the `ai` tag, all four personas. On other machines the
  modifier still passes `settings.json` through unchanged.
- **Live state:** on this machine, live hooks already equal source, so the first apply
  after migration adds hook entries to the ledger and changes nothing else. Machines that
  haven't applied since 2026-08-21 lose the stale `claude-tooling-guard` hook through the
  migration.
- **Security:** the `PreToolUse` write guard hook is now removed only when source drops it,
  as before. The migration and the ledger never remove a hook chezmoi didn't write. The
  risk to watch: if the guard hook entry were lost (for example, deleted by a bad
  migration), writes to tooling files would go unguarded. The migration fixture and the
  rollout diff (tasks) check for exactly that. No secrets are involved.
