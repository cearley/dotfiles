# Proposal

## Why

The `_chezmoiManaged` ledger does its job: an entry removed from source is retracted from the
live `settings.json`, and entries written outside chezmoi survive. It is hard to maintain for
two reasons:

- **The source is not JSON.** Each persona's managed settings are written as a Go
  `dict`/`list` expression in `modify_settings.json.tmpl`. Every edit means translating the
  JSON you want (usually copied from a live `settings.json`) into template syntax.
  `check-claude-overrides` then has to render the template and grep the result back out of an
  `extra_settings='…'` line, and its `--fix` edits the Go syntax with `awk`.
- **The merge is hard to follow.** The modifier flattens settings into path/leaf entries,
  keeps them in an array ledger (hook groups as `elemJson` strings), validates each entry by
  hand, and carries a one-time legacy-hook migration. It is about 60 lines of `jq`.

## What Changes

- **Managed settings are plain JSON in `settings.json`'s own shape.** They live in
  `home/.claude-settings/<persona>.json`, one file per persona (`default`,
  `personal`, `work`, `bedrock`). Each file can be copied to or from a live `settings.json`
  as it is. Each `modify_settings.json.tmpl` becomes a one-line caller.
- **The ledger is a copy of the managed JSON.** `_chezmoiManaged` becomes the managed JSON
  stored as one JSON string. It is a string so that Claude Code never sees hook-shaped objects
  outside `hooks`. On the next run, whatever that copy declares and the source no longer
  does is retracted. The merge is two short recursive `jq` functions: `apply`, which merges
  objects by key and unions arrays, and `retract`.
- **Behavior is unchanged:** order-preserving array union, hook groups compared by full value,
  scalars retracted only while they are still unchanged, emptied containers kept,
  idempotent output, and pass-through on non-ai machines.
- **Removed:** the one-time legacy-hook migration (see design D4 for why no machine needs
  it), the `extra_settings='…'` line contract, and the empty `(dict)` placeholders.
  `check-claude-overrides --fix` no longer needed them as anchors.
- **`check-claude-overrides`** reads each persona's JSON file directly as its baseline, and
  no longer needs `chezmoi` at runtime. `--fix` writes the live value with `jq`. It now
  creates a missing `skillOverrides`/`enabledPlugins` object instead of refusing.

## Impact

- `home/.chezmoitemplates/claude-settings-modifier` (rewritten),
  `home/.claude-settings/*.json` (new), and the four
  `home/dot_claude*/modify_settings.json.tmpl` files (now one line each).
- `home/dot_local/bin/executable_check-claude-overrides.tmpl`.
- Docs: `home/.chezmoitemplates/CLAUDE.md` and `home/dot_claude/rules/claude-tooling.md.tmpl`.
- Tests: `tests/test-claude-settings-ledger.sh` and its fixtures (ported). Migration fixtures
  26–30 are deleted, and a per-persona source check is added.
- Specs: `claude-settings-ledger` and `claude-override-audit`.
- Live files: the first apply replaces each persona's array ledger with the string form. It
  changes no settings, as checked on copies of all four live files.
