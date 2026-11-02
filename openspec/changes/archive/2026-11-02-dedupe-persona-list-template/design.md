## Context

Found via an architecture survey of this repo's busiest commit areas: the Claude Code
settings-ledger/persona-tooling scripts. Five independent call sites re-derive the same
persona-directory list from `$claudeEnvs`, each in slightly different template syntax
(bash array literal, a second bash array literal with a different variable name, a
comma-joined string, and a three-array "parallel arrays" variant). None of the five is wrong
today — they all currently agree — but nothing enforces that agreement, and a sixth consumer
needing the same data would be the fourth or fifth copy-paste of the identical
`trimPrefix "~/.claude-" .` expression.

## Goals / Non-Goals

**Goals:**
- One template owns the `claude_envs` → persona-directory-list derivation.
- Every existing call site's rendered output is unchanged after migration.
- The new template's output shape covers every field any current consumer needs today
  (`name`, `dir`, `baseline`), so no consumer needs to keep any local derivation alongside it.

**Non-Goals:**
- Not introducing a general "persona" abstraction beyond what's needed to replace the five
  existing derivations — no new metadata fields speculatively added for hypothetical future
  consumers.
- Not changing `check-claude-overrides`, `uninstall-claude-plugin-everywhere`,
  `audit-claude-code.sh`, the darwin-44 migration script, or `claude-tooling-write-guard`'s
  actual *behavior* — this is a derivation-source change only.

## Decisions

### Template output shape: JSON array of `{name, dir, baseline}` objects
Chosen over three parallel arrays (mirroring `check-claude-overrides`'s current
`PERSONA_NAMES`/`PERSONA_DIRS`/`PERSONA_BASELINES`) because `package-layer-items` already
established the "one JSON array of objects" convention for this kind of lookup in this repo,
and an array-of-objects lets a caller that only wants `dir` do a one-line
`jq -r '.[].dir'`-style extraction without also having to unpack a second or third array it
doesn't need. `name` always excludes the `~/.claude-` prefix (e.g. `"default"`, `"work"`),
matching `check-claude-overrides`'s existing `PERSONA_NAMES` convention — the only place today
that needs a bare name.

### Default/unnamed persona ordering: always first
Every one of the five current call sites puts `$HOME/.claude` (or its baseline/name
equivalent) before the `range $claudeEnvs` loop. The new template preserves that order rather
than leaving it unspecified, so no caller's existing ordering assumption breaks silently.

### Consumers extract fields with `jq`, not Go-template range gymnastics
`includeTemplate "persona-list" . | fromJson` yields a Go value; the simplest way for a bash
script to turn `[{"name":"default","dir":"$HOME/.claude",...}, ...]` into
`PERSONA_DIRS=("$HOME/.claude" "$HOME/.claude-work")` is still to template-range over it
(consistent with how `package-layer-items`'s own consumers already do a nested
`{{ range $groups }}{{ range .items }}` rather than shelling out to `jq` at render time). Each
call site keeps using Go-template `range` over the parsed array — only the *source* of the
array changes, not the rendering idiom each file already uses.

## Risks / Trade-offs

- **[Risk]** A subtle difference between the new template's output and any one call site's
  current derivation (e.g. ordering, trailing whitespace in a joined string) would silently
  change deployed script behavior. → **Mitigation**: tasks.md requires a byte-diff of each
  rendered file's relevant section before/after migration, not just "it looks right."
- **[Risk]** `claude-tooling-write-guard.tmpl`'s consumer is a comma-joined string
  (`$personaList`), not an array — a slightly different reduction of the same data.
  → **Mitigation**: keep that file's own `{{ range }}` join logic, just pointed at the new
  template's `name` field instead of `$claudeEnvs` directly; don't try to make the shared
  template itself emit pre-joined strings for one caller's convenience.
