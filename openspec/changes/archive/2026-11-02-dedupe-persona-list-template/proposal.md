## Why

Five chezmoi-templated files independently re-derive the same persona-directory list from
`$claudeEnvs` (sourced from `includeTemplate "machine-settings" .` → `.claude_envs`), each
hand-writing the same `$HOME/.claude-{{ trimPrefix "~/.claude-" . }}` transform in its own
template syntax instead of going through one shared seam:

- `home/dot_local/bin/executable_check-claude-overrides.tmpl:29-31` — three near-identical
  `range $claudeEnvs` expressions building `PERSONA_NAMES`/`PERSONA_DIRS`/`PERSONA_BASELINES`
  bash arrays (the same `trimPrefix "~/.claude-" .` transform repeated three times in this one
  file alone).
- `home/dot_local/bin/executable_uninstall-claude-plugin-everywhere.tmpl:25` — the identical
  `PERSONA_DIRS=("$HOME/.claude"{{ range $claudeEnvs }} "$HOME/.claude-{{ trimPrefix "~/.claude-" . }}"{{ end }})`
  literal, byte-for-byte match to the line above.
- `home/dot_local/lib/audit-claude-code.sh.tmpl:41` — same literal again, as
  `CLAUDE_PERSONA_DIRS`.
- `home/.chezmoiscripts/run_onchange_after_darwin-44-migrate-claude-md-symlinks.sh.tmpl:28` —
  same pattern a fourth time.
- `home/dot_local/bin/executable_claude-tooling-write-guard.tmpl` (currently lines 39-41,
  moved since this proposal was first drafted — the persona-mismatch hardening in `b2f80bb`
  added helper functions earlier in the file) — a fifth, string-joined variant of the same
  derivation (builds a comma-joined `$personaList` string instead of a bash array).

Five places that must all be kept in sync by hand if the persona-directory naming convention
(`~/.claude-<name>`) ever changes, or if a new piece of derived persona data (a baseline path,
which file 1 already separately derives) is needed at a sixth call site. This repo already has
the right precedent for fixing this: `home/.chezmoitemplates/package-layer-items` resolves
`packages.yaml` category/tag eligibility into a single JSON array exactly so category/tag logic
has one source of truth instead of being re-derived per caller.

## What Changes

- Add a new reusable template, `home/.chezmoitemplates/persona-list`, that takes only `.` (no
  special params) and returns a JSON array of `{name, dir, baseline}` objects — one entry per
  persona, unnamed default first, named `claude_envs` personas following in their declared
  order — so every consumer gets exactly the fields it currently hand-derives, from one place.
- Document it in `home/.chezmoitemplates/CLAUDE.md`'s template catalog, following the existing
  `package-layer-items` entry's format (one-paragraph description plus a usage snippet).
- Migrate each of the five call sites to `includeTemplate "persona-list" . | fromJson` plus a
  trivial `jq`/range extraction of the field(s) it needs, in place of its own inline derivation.
- Update the `claude-override-audit` spec's "Persona Environment Enumeration" requirement,
  whose text currently names the implementation detail `(via {{ range $claudeEnvs }})` — that
  parenthetical becomes inaccurate once the range lives inside the shared template instead of
  inline in the consuming script. The requirement's behavioral guarantees (resolved at
  chezmoi-apply render time, baked in as literal values, never filesystem-scanned or
  runtime-derived) do not change.

Non-goals:
- No change to persona *behavior* at any of the five call sites — rendered output (the actual
  array/string values baked into each deployed script) must be identical before and after.
- No change to the `~/.claude-<name>` naming convention itself.
- No new personas, and no change to how `claude_envs` is declared in machine config.
- No change to `claude-settings-ledger` or `claude-tooling-write-guard` behavior — those specs
  aren't touched because neither documents the persona-enumeration mechanism at the
  implementation-detail level that `claude-override-audit` does.

## Capabilities

### New Capabilities
(none)

### Modified Capabilities
- `claude-override-audit`: "Persona Environment Enumeration" requirement's implementation
  note updated to describe resolution via the shared `persona-list` template instead of an
  inline `{{ range $claudeEnvs }}` in the consuming script. No scenario's SHALL/THEN behavior
  changes.

## Impact

- **Affected files**: new `home/.chezmoitemplates/persona-list`; edits to
  `home/.chezmoitemplates/CLAUDE.md`,
  `home/dot_local/bin/executable_check-claude-overrides.tmpl`,
  `home/dot_local/bin/executable_uninstall-claude-plugin-everywhere.tmpl`,
  `home/dot_local/lib/audit-claude-code.sh.tmpl`,
  `home/.chezmoiscripts/run_onchange_after_darwin-44-migrate-claude-md-symlinks.sh.tmpl`,
  `home/dot_local/bin/executable_claude-tooling-write-guard.tmpl`.
- **Affected specs**: `claude-override-audit` (wording-only delta, no behavior change).
- **Risk**: low — each migrated call site is a pure substitution; rendered output must be
  verified byte-identical to before (`tests/run-template` per file, plus
  `tests/test-claude-settings-ledger.sh` for anything touching the settings-ledger scripts)
  before this is considered done.
