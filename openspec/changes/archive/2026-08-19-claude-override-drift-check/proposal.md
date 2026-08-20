## Why

`claude-tooling.md`'s "Checking for Override Drift" section documents a manual, multi-file
audit procedure (read every persona's `settings.json`, read its `modify_settings.json.tmpl`
baseline by eye, diff by hand) for detecting `skillOverrides`/`enabledPlugins` entries that
silently suppress a chezmoi-declared skill or plugin — the mirror image of the
installed-but-undeclared direction that `audit-packages`/`clean-claude-orphans` already
automate. This asymmetry isn't hypothetical: on 2026-08-17 `memory-notes` and `memory-schema`
were found silently disabled this way, with no automated check that would have caught it
earlier. Closing the gap with a script (not a new skill) keeps the resolve judgment call where
it already lives — in `claude-tooling.md`'s existing prose — while removing the error-prone
by-hand comparison.

## What Changes

- New read-only script `check-claude-overrides`, deployed directly on PATH as a rendered
  chezmoi template — `home/dot_local/bin/executable_check-claude-overrides.tmpl` — the same
  pairing `executable_claude-tooling-guard.tmpl` already uses in that directory. The persona
  list (from this machine's `claude_envs` config) and every chezmoi-source path it needs are
  baked in at `chezmoi apply` render time via `{{ .chezmoi.sourceDir }}` and
  `{{ range $claudeEnvs }}`; no runtime self-location or config re-derivation.
- For each baked-in persona, the script renders that persona's `modify_settings.json.tmpl`
  via `chezmoi execute-template` *at runtime* (unlike the persona list, this has to be fresh
  on every invocation, since the template's content can change without a `chezmoi apply`
  having run yet) and extracts the intended `skillOverrides`/`enabledPlugins`/`permissions`
  baseline from the rendered `claude-settings-hooks-modifier` output (the
  `extra_settings='...'` JSON literal), rather than hand-parsing the source template's Go
  `dict(...)` syntax.
- It flags any live `settings.json` entry the baseline doesn't explain: `skillOverrides.<skill>:
  "off"` for a native skill (listed under `home/dot_claude/skills/`), or
  `enabledPlugins.<id>: false` for a plugin declared in `packages.yaml`'s
  `claude_code.plugins` list. Output is a `## drift` TSV section, same style as
  `clean-claude-orphans`' existing `list-claude-orphans.sh`.
- `claude-tooling.md.tmpl`'s "Checking for Override Drift" section is edited to direct the
  reader to run `check-claude-overrides` in place of its current manual step 1 (read every
  `settings.json` and `modify_settings.json.tmpl` by hand); the resolve guidance (steps 3-4)
  is unchanged.
- `clean-claude-orphans`'s `SKILL.md.tmpl` gets a one-line, non-blocking cross-reference to
  `check-claude-overrides` as the complementary check for the opposite drift direction.
- `check-claude-overrides` gains a `--fix <persona> <skillOverrides|enabledPlugins> <key>`
  mode that writes the "keep the override" resolution directly into the target persona's
  `modify_settings.json.tmpl`, reading the value to codify straight from the live
  `settings.json` and self-verifying via a re-render before the real source file is ever
  touched (see design.md - Decisions for the exact mechanism).

## Capabilities

### New Capabilities
- `claude-override-audit`: read-only detection of Claude Code `skillOverrides`/
  `enabledPlugins` entries that silently diverge from a persona's chezmoi-managed baseline.

### Modified Capabilities
- `claude-tooling-rule`: the rule's required content coverage gains a pointer to the new
  script for the override-drift direction, replacing the current fully-manual procedure
  description.

## Impact

- New file: `home/dot_local/bin/executable_check-claude-overrides.tmpl`.
- Edited files: `home/dot_claude/rules/claude-tooling.md.tmpl` (Checking for Override Drift
  section), `home/dot_claude/skills/clean-claude-orphans/SKILL.md.tmpl` (one-line
  cross-reference).
- Tags affected: `ai` only (darwin+ai machines), matching `claude-tooling-rule`'s existing
  scope — no change to non-AI or non-darwin machines.
- No secrets, no SIP implications: purely reads local Claude Code config files and renders
  chezmoi templates already present on disk; installs nothing, modifies nothing.

## Non-goals

- Does not automate the "drop the override" resolution — removing a live `skillOverrides`/
  `enabledPlugins` entry from a `settings.json` remains the existing manual `/skill` or
  `/plugin` command, unchanged from today. `--fix` only ever writes the "keep" direction into
  the source template; deciding *which* direction is still the judgment call in
  `claude-tooling.md`'s steps 3-4.
- `--fix` does not scaffold a brand-new `$extra`/`claudeExtraSettings` dict structure (or a
  missing `skillOverrides`/`enabledPlugins` sub-dict) for a persona that has none yet — see
  design.md - Decisions. That remains a one-time manual edit.
- `--fix` does not offer a bulk or interactive apply-all mode — each entry is fixed
  individually via an explicit `<persona> <kind> <key>` argument, keeping the same
  confirm-then-execute discipline (list the plan, get explicit confirmation, execute one
  named action) the rest of this repo's tooling (`clean-claude-orphans`) already uses.
- Does not become a new Claude Code skill — deliberately script-only, since the resolve
  logic already lives in the always-loaded `claude-tooling.md` rule and needs no separate
  trigger.
- Does not cover `disabledMcpServers` drift — that setting is intentionally
  not-chezmoi-managed per existing status notes; scope is limited to `skillOverrides`/
  `enabledPlugins`, matching the current "Checking for Override Drift" section's scope.
- Does not merge into or modify `clean-claude-orphans`'s own detection logic — remains a
  separate, single-purpose script for the mirror-image direction, cross-referenced only.
