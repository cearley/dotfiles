# Design

## D1. Source files live in `home/.claude-settings/`

One `<persona>.json` per persona. The names match `check-claude-overrides`' persona names
(`default` plus each `claude_envs` suffix), so the path follows from the name. chezmoi
ignores dot-prefixed source paths, so these files are neither deployed nor parsed as
templates: a `{{` in a hook command is safe. `include` reads them raw. Keeping the four files
side by side makes `diff personal.json work.json` easy.

**Rejected alternatives:**
- `.chezmoitemplates/claude-settings/`, which was tried first. chezmoi parses every file
  there as a named template, so a single `{{` in any source file would break every render.
- A JSON file next to each `modify_settings.json.tmpl`. It would need `.chezmoiignore`
  entries.
- `.chezmoidata/`. It would load the files into global template data, and it keeps only one
  file per key.
- A shared base plus per-persona overlays. That reintroduces merge rules at the source level.
  The earlier decision was that the five hooks are repeated on purpose, so each file is
  self-contained, and it still holds.

The caller passes the file text with `include`. The partial parses it with `fromJson` and
re-serializes it with `toJson`, so invalid JSON fails `chezmoi apply` at render time instead
of producing a broken script. The re-serialization also sorts keys. Only newly created keys
see that order; existing keys keep their live position, because `jq` updates in place.

## D2. The ledger is the last-applied managed JSON, stored as a string

`_chezmoiManaged = (managed | tojson)`. The previous copy is parsed back, and retraction
compares it with the current source structurally:

- An object key that the previous copy declares and the current source lacks is retracted.
  A scalar is removed only while its live value still equals what was written. An object or
  array is recursed into, and the container is kept.
- An array element that the previous copy lists and the current source no longer lists is
  removed. Elements that stay in source are never removed and re-added, so they keep their
  position.

The ledger stays a string because Claude Code reports hook-shaped objects outside `hooks`
(the reason for the earlier `elemJson`). The whole copy is one string, not one string per
hook group.

A ledger that is not a string, or does not parse, counts as "no previous copy", so nothing
is retracted. That covers the pre-change array ledger: the first apply after this change
retracts nothing and writes the string form. The managed content is unchanged in this change,
so nothing needs retracting.

## D3. Apply

`apply($m)` merges objects key by key (a non-object live value is replaced by an object),
merges arrays as an order-preserving union (a non-array live value is replaced by an array),
and overwrites everything else. This is the old leaf-by-leaf behavior, written recursively
instead of through flattened paths.
One visible difference: an empty `{}` or `[]` in source now creates that empty container in
`settings.json`, where the leaf-based code wrote nothing. None of the source files contain
one.

The source files must be JSON objects; the partial calls `fail` otherwise.

## D4. The legacy-hook migration is dropped

The migration existed for live files whose hooks came from the pre-ledger upsert. The
machines are in two states:

- **MacBook Pro** already ran the migration; all four ledgers record the hooks.
- **Mac Studio and Mac mini** still run `origin/main` (`c36f2df`), because none of the
  ledger commits have been pushed. That upsert rewrites every managed hook group to exactly
  the source value, and already removed `claude-tooling-guard`. Its output therefore contains
  the source groups unchanged, and the new union dedups against them.

A simulation confirmed this. A legacy file (a stale `Bash|Edit` matcher, a retired guard,
and a foreign `bd prime`) was run through the `origin/main` partial and then the new one. The
result had no duplicate groups, and the new step left the hooks unchanged. This also closes
the "delete the legacy-hook migration" follow-up.

**Residual risk:** a machine whose live file was last written by a modifier older than the
`origin/main` upsert. Such a file could keep a stale hook group next to the source one. That
is visible in `settings.json` and fixed by deleting the group once.

## D5. `check-claude-overrides` reads JSON directly

The baseline is `jq -c . <persona>.json`. The render step, the `extra_settings` grep, the
`chezmoi` runtime dependency, and `--fix`'s `awk` insertion and re-render verification all
go away. `--fix` writes `.[kind][key] = <live value>` to a temp copy, checks the value
there, and then copies it over the source file. The source files use `jq`'s own formatting,
so a `--fix` diff is just the inserted line.
