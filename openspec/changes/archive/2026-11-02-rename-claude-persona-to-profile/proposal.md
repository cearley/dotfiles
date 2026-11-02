## Why

"Persona" is the name this repo uses for a named config directory for an AI coding agent CLI —
today that means Claude Code specifically (`~/.claude`, `~/.claude-personal`, `~/.claude-work`,
`~/.claude-bedrock`), each with its own `CLAUDE_CONFIG_DIR`, `settings.json`, and
`.claude-settings.json` override, but the same shape — one environment variable relocating one
config directory — also exists natively in Codex (`CODEX_HOME`), Gemini CLI
(`GEMINI_CLI_HOME`), and Copilot CLI (`COPILOT_HOME`), so the underlying concept is not
Claude-Code-specific even though this change's implementation is. The word "persona" collides
with its much stronger established meaning — a fictional UX/marketing user archetype — and it
sits oddly next to this repo's own upstream plugin, `zsh-claude-env`
(https://github.com/cearley/zsh-claude-env), which already uses **"environment"** for the
*active, switchable* runtime binding of the same underlying directories (the shell switcher,
`CLAUDE_ENV_SHOW_DEFAULT`, the prompt segment). "Persona" ends up naming the static config
bundle while a sibling concept already owns "environment" for the live one — exactly the kind
of two-names-one-concept smell that makes a term hard to use consistently. This surfaced during
a review of whether the repo would benefit from a documented ubiquitous language
(see `GLOSSARY.md`, added in a prior session).

"Profile" is the better name: it's the standard, unambiguous term for exactly this shape
(AWS CLI profiles, browser profiles, shell profiles — a named, switchable bundle of settings),
and it doesn't fight either "persona" (UX) or "environment" (this repo's runtime-binding term).
It also independently matches the landscape: the `omp` (Oh My Pi) agent CLI has a native
`--profile <name>` flag with isolated per-profile state, and third-party tooling for the `pi`
agent (`pi-harness-factory`, `Outfitter`) reaches for "profile" too. The one documented
exception: Codex's own `config.toml` already has an unrelated `[profiles.<name>]` concept
(model/approval presets picked via `--profile`, not account/directory switching) — a narrow
collision to call out explicitly if Codex support is ever built, not a reason to rename again
now. Whether and how to extend this repo's profile machinery to other agent CLIs is scoped in a
separate proposal (`generalize-agent-profile-management`); this change stays Claude-Code-only.

## What Changes

- Rename the **config-profile** concept from "persona" to "profile" everywhere it appears as
  prose, an identifier, or a filename: template name, shell variable/function names, CLI
  help-text placeholders, code comments, rule/skill prose, spec requirement titles and bodies,
  `CLAUDE.md`, and `GLOSSARY.md`.
- Rename the shared template `home/.chezmoitemplates/persona-list` to `profile-list` and update
  every call site.
- Rename shell identifiers built on "persona" to their "profile" equivalents (e.g.
  `PERSONA_DIRS` → `PROFILE_DIRS`, `detect_persona_drift` → `detect_profile_drift`,
  `resolve_current_persona_index` → `resolve_current_profile_index`, `$personaList` →
  `$profileList`).
- Update the `--fix <persona> ...` help-text placeholder in `check-claude-overrides` to
  `--fix <profile> ...` (the flag itself, `--fix`, is unchanged — only the documented argument
  name changes).
- Update the nine openspec capability specs that currently use "persona" in requirement titles
  or bodies (deltas included in this change).

## Capabilities

### New Capabilities
(none)

### Modified Capabilities
- `claude-override-audit`: three requirements renamed (`Persona Environment Enumeration` →
  `Profile Environment Enumeration`, `Automatic Session-Start Invocation Scoped to Current
  Persona` → `...Current Profile`, `Per-Persona Once-Per-Drift-State Dedup` →
  `Per-Profile...`); wording-only updates to nine others. No SHALL/THEN behavior changes.
- `claude-tooling-write-guard`: one requirement renamed (`chezmoi add of a Persona
  settings.json Is Denied` → `...a Profile settings.json...`); wording-only updates to two
  others.
- `claude-function-hooks-mods`: one requirement renamed (`Each persona declares a vendored
  mod's non-secret options` → `Each profile declares...`); wording-only updates to two others.
- `claude-repo-permission-patterns`: one requirement renamed (`Independence from the persona
  settings ledger` → `...the profile settings ledger`).
- `claude-tooling-rule`, `claude-settings-ledger`, `shared-utilities`, `package-management`,
  `claude-environments`: wording-only updates (no requirement titles contain "persona").

## Impact

- **Affected files** (identifier/filename-level rename):
  `home/.chezmoitemplates/persona-list` (renamed to `profile-list`),
  `home/.chezmoitemplates/CLAUDE.md`,
  `home/dot_local/bin/executable_check-claude-overrides.tmpl`,
  `home/dot_local/bin/executable_uninstall-claude-plugin-everywhere.tmpl`,
  `home/dot_local/lib/audit-claude-code.sh.tmpl`,
  `home/.chezmoiscripts/run_onchange_after_darwin-44-migrate-claude-md-symlinks.sh.tmpl`,
  `home/dot_local/bin/executable_claude-tooling-write-guard.tmpl`,
  `home/dot_claude/skills/clean-claude-orphans/scripts/executable_list-claude-orphans.sh.tmpl`.
- **Affected files** (prose-only rename):
  `home/dot_claude/skills/which-skill/SKILL.md`,
  `home/dot_claude/skills/which-skill/scripts/executable_list-skills.sh`,
  `home/dot_claude/rules/claude-tooling.md.tmpl`,
  `home/dot_claude/rules/global-preferences.md.tmpl`,
  `home/.chezmoitemplates/claude-settings-modifier`,
  `home/.chezmoitemplates/claude-pattern-a`, `claude-pattern-b`, `claude-pattern-c`,
  `home/.chezmoitemplates/claude-pattern-c-devcontainer/devcontainer.json`,
  `home/dot_local/bin/executable_apply-claude-pattern.tmpl`,
  `home/dot_claude/.chezmoiexternal.toml.tmpl`,
  `home/private_dot_config/claude-omc/config.jsonc`,
  `home/scripts/shared-utils.sh`,
  `tests/test-claude-tooling-write-guard.sh`, `tests/test-claude-settings-ledger.sh`,
  `CLAUDE.md`, `GLOSSARY.md`.
- **Affected specs**: the nine capabilities listed above (wording/title deltas included in this
  change; no behavior changes).
- **Risk**: low-to-moderate. No logic, data shape, or on-disk directory naming changes — this
  is a pure terminology substitution across a wide but shallow surface. The main risk is an
  incomplete rename leaving a stray "persona" that now disagrees with its neighbors; the
  verification task is a repo-wide grep that must return zero hits outside
  `openspec/changes/archive/**`.

## Non-goals

- Not renaming `claude_envs` (the `config.yaml` key), `$claudeEnvs` (its template variable), or
  any "environment" terminology owned by the `claude-environments` spec or the upstream
  `zsh-claude-env` plugin — that name is already correct for the *active, switchable* runtime
  concept and is out of scope here.
- Not renaming the on-disk directories themselves (`home/dot_claude-personal`,
  `dot_claude-work`, `dot_claude-bedrock`) — their suffix is the profile's role name
  (`personal`/`work`/`bedrock`), not the literal word "persona", so there is nothing to rename.
- Not touching `openspec/changes/archive/**` — those are historical records of past decisions
  and keep the terminology that was current when they were written, matching this repo's prior
  rename precedent (`rename-keepassxc-entries-to-secret-entries`).
- Not changing any behavior, drift-detection logic, file format, or CLI flag name (`--fix` is
  unchanged; only its documented argument placeholder changes).
- Not updating the basic-memory note `feedback_persona_hooks_can_diverge.md` — that lives
  outside this repo (in the user's personal Claude memory store) and is a separate follow-up.
- Not building or scoping multi-tool profile management here. "Profile" was chosen partly
  because it generalizes cleanly (see `design.md`), but extending the actual directory/
  env-var machinery to Codex, Gemini CLI, Copilot CLI, or others is the separate
  `generalize-agent-profile-management` proposal, not this change.
