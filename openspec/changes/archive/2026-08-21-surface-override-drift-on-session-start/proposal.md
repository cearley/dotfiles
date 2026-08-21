## Why

`check-claude-overrides` already detects `skillOverrides`/`enabledPlugins` entries that have
silently drifted from a persona's chezmoi-managed baseline, but it only runs when the user or
an agent thinks to invoke it manually — real drift (confirmed on this machine for
`viewpoint-report-automation`, see `openspec/specs/claude-override-audit`) can sit unnoticed
for days. Claude Code already fires a `SessionStart` hook for other per-persona purposes
(`setup-memory-workflow`'s context-priming reminder), and `claude-settings-hooks-modifier`
already wires a comparable automatic check — `claude-tooling-guard` on `PreToolUse` — through
the same per-persona `modify_settings.json.tmpl` mechanism. Reusing that pattern for override
drift closes the gap without inventing a new delivery mechanism.

## What Changes

- Add a `SessionStart` entry to `claude-settings-hooks-modifier`'s `managed_hooks`, invoking
  `check-claude-overrides` for the persona whose session is starting only — not a full sweep
  of every `claude_envs` persona — mirroring `claude-tooling-guard`'s per-session, per-persona
  scope.
- `check-claude-overrides` gains an automatic-invocation mode, scoped to the single persona
  derived from `$CLAUDE_CONFIG_DIR`, that emits a short `additionalContext`/`systemMessage`
  pointer (consistent with `claude-tooling-guard`'s truncation-aware, report-only pattern) —
  not the full sectioned-TSV `## drift` report the on-demand/agent invocation already
  produces.
- Add per-persona dedup state: the hook SHALL fingerprint the currently-flagged
  persona/kind/key/value tuples and only surface a session-start message when that
  fingerprint changes from the last one recorded for that persona — not on every session
  start for a drift state the user has already been shown and not yet acted on.
- No change to `check-claude-overrides`'s existing on-demand behavior: default read-only
  operation, the full TSV report, and `--fix <persona> <kind> <key>` all keep their current
  requirements unchanged.

## Non-Goals

- Not building a full-sweep "check every persona at once" mode — that's what manual
  `check-claude-overrides` invocation is already for.
- Not adding an interactive resolve flow inside the hook itself (choosing "keep" vs "drop"
  stays a separate, manual step via `--fix` or a `/skill`/`/plugin` command) — the hook only
  ever reports.
- Not changing `--fix` mode's semantics, verification, or the "requires an existing target
  sub-dict" constraint.
- Not deduping *across* personas — each persona's drift-state fingerprint is tracked and
  surfaced independently.

## Capabilities

### New Capabilities
(none)

### Modified Capabilities
- `claude-override-audit`: adds automatic, current-persona-scoped invocation at Claude Code
  session start (via a new `claude-settings-hooks-modifier`-managed `SessionStart` hook),
  plus per-persona once-per-drift-state dedup so an unresolved, unchanged drift state isn't
  re-reported every session. Existing on-demand/manual requirements (read-only default,
  TSV report format, `--fix` mode and its verification/sub-dict constraints) are unchanged.

## Impact

- `home/dot_local/bin/executable_check-claude-overrides.tmpl` — new single-persona,
  automatic-invocation code path and terse hook-output format; existing manual code path
  untouched.
- `home/.chezmoitemplates/claude-settings-hooks-modifier` — new `SessionStart` entry in
  `managed_hooks`, alongside the existing `claude-tooling-guard` `PreToolUse` entry.
- New per-persona dedup state (a small marker/fingerprint file, location TBD in design —
  likely alongside `claude-tooling-guard`'s existing `$TMPDIR`-based marker pattern or a
  `$CLAUDE_CONFIG_DIR`-scoped cache path).
- Affects every machine/persona combination that already receives
  `claude-settings-hooks-modifier`'s managed hooks (the `ai` tag). No security-sensitive
  change: the session-start path is read-only, never writes `settings.json` or any
  `modify_settings.json.tmpl` on its own — only `--fix`, unchanged here, does that.
