# Proposal

## Why

`jev-model-router` (a Claude Code "mod" — a function-hooks plugin — from
`davila7/claude-code-templates`) picks a cheaper or more capable model/effort
per turn using TypeSafe's Jev decision model, with a safe no-account fallback
to Claude Code's own built-in classifier. It's useful machine-wide, but its
upstream installer (`npx claude-code-templates --mod ...`) hardcodes a
literal `.claude` path segment under its `--directory` target, so it can only
ever write to this machine's default `~/.claude` — never to a named persona
(`~/.claude-personal`, `~/.claude-work`, `~/.claude-bedrock`). It also reports
install analytics to a third-party tracking service on every run. Neither
property is acceptable for a machine-wide, chezmoi-managed dotfiles setup.
There is currently no chezmoi-native pattern for this class of plugin at
all — mods are "skills-dir-loaded" (auto-loaded straight from a skills
directory, no marketplace registration), which is a third install shape
distinct from the two this repo already automates (`npx skills add -g` and
`claude plugins install`).

## What Changes

- New capability: chezmoi vendors a Claude Code "mod"'s plugin files
  (`.claude-plugin/plugin.json`, `hooks/hooks.json`, and its hook modules)
  directly via `.chezmoiexternal.toml` **file**-type sources into
  `home/dot_claude/skills/<mod-name>/`, instead of shelling out to the
  upstream CLI. Because every declared persona's `skills/` is already a
  symlink to `~/.claude/skills/` (`claude-environments` capability), the
  files reach every persona for free from one externals declaration.
- Both `home/dot_zshrc.tmpl` and `home/dot_bashrc.tmpl` export
  `CLAUDE_CODE_ENABLE_FUNCTION_HOOKS=1`, alongside the `CLAUDE_CONFIG_DIR`
  export already there — mods refuse to load without it, and since it's a
  process-level flag (not a per-persona file), setting it once in the shared
  shell rc covers every persona's `claude` invocation.
- Each persona's `.claude-settings.json` (the source file already merged into
  that persona's live `settings.json` by the `claude-settings-ledger`
  modifier) declares the mod's non-secret `pluginConfigs.<name>.options` —
  provider choice, model tiers, confidence thresholds, routing switches.
  `settings.json` is explicitly *not* shared across personas, so this is a
  4-way repeated declaration, not a single shared file.
- First (and, for this change, only) mod vendored under the new capability:
  `jev-model-router`, configured with `provider: "typesafe"`,
  `typesafeBaseUrl: "https://openrouter.ai/api"`,
  `typesafeModel: "~typesafe/jev-latest"` — OpenRouter hosts TypeSafe's Jev
  model at `POST https://openrouter.ai/api/v1/systemone`, which matches this
  mod's own `typesafe`-backend endpoint-building (`{typesafeBaseUrl}/v1/systemone`)
  and request shape (`{model, state, questions}`), letting the user's existing
  OpenRouter account back it with no new TypeSafe signup.
- `typesafeApiKey` is deliberately **not** declared in any `.claude-settings.json`
  — the mod's hook code reads plugin options only from `settings.json`
  (verified by reading `hooks/jev-model-router.ts`; there is no `process.env`
  fallback), so it must be set once per persona through Claude Code's own
  `/config` UI. The settings-ledger modifier's runtime-key preservation keeps
  a `/config`-set key across future `chezmoi apply` runs.

## Capabilities

### New Capabilities
- `claude-function-hooks-mods`: chezmoi vendors Claude Code "mod" plugins
  (function-hooks plugins auto-loaded from a skills directory, distinct from
  marketplace-installed plugins) via file-type `.chezmoiexternal.toml`
  sources, enables the function-hooks flag machine-wide, and declares each
  mod's non-secret plugin options per persona.

### Modified Capabilities
(none — `claude-environments`, `claude-settings-ledger`, and
`claude-plugin-marketplace` are all relied upon as-is; none of their
requirements change)

## Impact

- New: `home/dot_claude/.chezmoiexternal.toml.tmpl`
- Modified: `home/dot_claude/.claude-settings.json`,
  `home/dot_claude-personal/.claude-settings.json`,
  `home/dot_claude-work/.claude-settings.json`,
  `home/dot_claude-bedrock/.claude-settings.json` (add `pluginConfigs`)
- Modified: `home/dot_zshrc.tmpl`, `home/dot_bashrc.tmpl` (add
  `CLAUDE_CODE_ENABLE_FUNCTION_HOOKS=1` export)
- No `packages.yaml` change and no new `run_onchange_` script — this is
  purely a vendored-content + settings-data change gated on the existing
  darwin + `ai` tag condition.
- Tags affected: `ai` only (same gate every other Claude Code tooling item
  already uses).
- Security implications: once a `typesafeApiKey` is configured (by hand, via
  `/config`, out of scope for this change), the mod sends prompt text to
  OpenRouter for classification on every routed turn — this is opt-in per
  persona (no key, no external call; falls back to the built-in classifier)
  and involves no chezmoi-side secret handling, so there's nothing for SOPS
  or KeePassXC to manage here. No SIP-restricted paths or elevated
  permissions are touched.

## Non-goals

- Not chezmoi-managing the `typesafeApiKey` secret itself (KeePassXC or
  SOPS+age) — set by hand per persona via `/config`.
- Not smoke-testing OpenRouter's `/v1/systemone` request/response shape
  against this mod's exact wire format before merging — the endpoint-path
  and body-shape match is inferred from reading both sides' code/docs, not
  from a live call. Call it out as a manual follow-up, not a task here.
- Not resolving or automating the per-persona workspace/plugin trust-prompt
  behavior for a mod auto-loaded from the *global* skills-dir (as opposed to
  a project-local `.claude/skills/`, which is the case the upstream
  installer's own docs describe) — verify by hand per persona, not scripted.
- Not adopting the upstream `claude-code-templates` npx CLI as an install
  mechanism (directory-naming limitation, third-party telemetry).
- Not adding a generic `packages.yaml` `mods:` list with its own
  `run_onchange_` installer script — the externals-vendoring mechanism this
  change introduces is deliberately reusable for a future mod without one,
  but building that generic list is out of scope here.
