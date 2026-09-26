# Design

## Context

See `proposal.md` - Why. Three existing mechanisms already cover adjacent
ground but none fit a "mod" (a function-hooks plugin auto-loaded from a
skills directory):

- `claude-environments`: `home/dot_claude/skills/` is the one real
  directory; every persona's `skills/` is a `symlink_` pointing at it. This
  is what makes a single externals declaration reach every persona.
- `claude-settings-ledger`: the generic `modify_settings.json.tmpl` /
  `claude-settings-modifier` partial merges each persona's
  `.claude-settings.json` into that persona's live `settings.json`,
  preserving runtime-added keys (e.g. anything set via `/config`) and
  retracting only what a previous chezmoi run itself added.
- `claude-plugin-marketplace`: covers marketplace-registered,
  `claude plugins install`-enabled plugins — a different runtime path from a
  mod, which Claude Code auto-loads straight from a skills directory with no
  marketplace or install step at all.

The upstream `claude-code-templates` CLI's `installIndividualMod()` (read
from its `cli-tool/src/index.js`) always writes to
`path.join(targetDir, '.claude', 'skills', baseName)` — the literal `.claude`
segment is hardcoded, not derived from `--directory`. `--directory "$HOME"`
resolves correctly for the default persona (`~/.claude`) but there is no
`--directory` value that produces `~/.claude-personal/skills/...`, since that
directory isn't literally named `.claude`. It also calls
`trackingService.trackDownload()` / `trackInstallationOutcome()` on every
run.

## Goals / Non-Goals

**Goals:**
- Vendor a mod's plugin files without the upstream CLI, using only
  chezmoi-native externals.
- Reach every persona from a single declaration, reusing the existing
  skills-symlink mechanism rather than adding a new sharing mechanism.
- Keep the mod's sensitive `userConfig` fields (API keys) entirely outside
  chezmoi's management, per this repo's "no hardcoded secrets" rule and the
  fact that the mod's hook code has no environment-variable fallback to
  intercept them through anyway.

**Non-Goals:**
- A generic `packages.yaml`-driven mod installer/list (a `mods:` key with its
  own `run_onchange_` script). One mod does not justify that generality yet;
  the `claude-function-hooks-mods` spec's requirements are already written
  generically enough that a second mod is just more externals entries and
  more `pluginConfigs` blocks, not a spec change.
- Verifying OpenRouter's System One API request/response shape against this
  mod's exact TypeSPec wire format with a live call (see proposal.md -
  Non-goals).
- Automating or working around Claude Code's per-persona workspace/plugin
  trust prompt.

## Decisions

**Vendor via `.chezmoiexternal.toml` `file`-type entries, not `archive`.**
`davila7/claude-code-templates` is a large monorepo; an `archive`-type
external (as used for `.oh-my-zsh`, `zsh-claude-env`, etc. in the existing
`home/.chezmoiexternal.toml.tmpl`) would download the entire repository
tarball on every refresh for four small files. Four `file`-type entries,
each pointing at one `raw.githubusercontent.com/.../main/...` URL, fetch
only what's needed. Alternative considered: mirror the files into this repo
as plain committed source (no external at all). Rejected because it would
silently drift from upstream with no `chezmoi update` signal; a `file`
external with a `refreshPeriod` (168h, matching the existing zsh-plugin
externals) gets periodic upstream sync for free.

**A new `.chezmoiexternal.toml.tmpl` scoped under `home/dot_claude/`, not an
addition to the existing root-level `home/.chezmoiexternal.toml.tmpl`.**
Chezmoi resolves a nested `.chezmoiexternal.toml(.tmpl)` relative to the
directory it lives in, so entries scoped under `home/dot_claude/` can use
skills-relative paths (`skills/jev-model-router/...`) instead of repeating
`.claude/skills/...` from the root file's perspective, and stay next to the
capability they belong to rather than mixed in with oh-my-zsh plugin
sources. This mirrors how `home/dot_claude/skills/audit-skills/` is already
a same-directory, self-contained skill.

**Gate the new export on the `ai` tag, independent of `claude_default`.**
The existing `CLAUDE_CONFIG_DIR` export in `dot_zshrc.tmpl` /
`dot_bashrc.tmpl` is conditional only on a machine declaring
`claude_default`, not on the `ai` tag directly (in practice the two overlap,
but they're independent conditions). `CLAUDE_CODE_ENABLE_FUNCTION_HOOKS=1`
has nothing to do with which persona is default — every persona needs it
once any mod is vendored — so it's gated on `has "ai" .tags` directly,
matching every other Claude-tooling item's gate, rather than piggybacking on
the unrelated `claude_default` condition.

**Point `jev-model-router`'s `typesafe` backend at OpenRouter, not TypeSafe's
own API.** `policy.ts`'s `endpoint()` builds `{typesafeBaseUrl}/v1/systemone`;
OpenRouter's documented System One API is `POST
https://openrouter.ai/api/v1/systemone` — same path suffix. Setting
`typesafeBaseUrl: "https://openrouter.ai/api"` and `typesafeModel:
"~typesafe/jev-latest"` reuses the user's existing OpenRouter account instead
of requiring a new TypeSafe signup, and gets TypeSafe's calibrated-confidence
response shape (which the `gateway` backend's Vercel AI Gateway path does
not provide — no `confidence` field, only an optional probability
distribution). Alternative considered: leave `provider` on `auto` with no
key set, accepting the built-in classifier. Rejected only as the default
recommendation, not disallowed — declaring the non-secret options doesn't
require a key to be present (see `claude-function-hooks-mods` - the
"Each persona declares..." requirement is independent of whether a key is
ever set), so the user can adopt the key on their own timeline per persona.

**Do not declare `typesafeApiKey` anywhere in `.claude-settings.json`, and do
not route it through `private_dot_zsh_secrets.tmpl` either.** Confirmed by
reading `hooks/jev-model-router.ts`: `options` (from which `typesafeApiKey`
is read) comes from Claude Code's own plugin-options mechanism, sourced from
`settings.json`; there is no `process.env` read anywhere in the mod. An env
var would silently do nothing. The only two places the key could
meaningfully live are a chezmoi-rendered `settings.json` value (which this
repo's "no hardcoded secrets" convention and the two-tier secret model would
push toward a SOPS+age-encrypted source) or Claude Code's own `/config`,
which writes directly to the live file and is preserved by the
`claude-settings-ledger` modifier's retraction rules. The user chose
`/config` for its simplicity — no encrypted file to maintain — accepting
that the key then isn't reproduced automatically on a fresh machine.

## Risks / Trade-offs

- **[Risk]** OpenRouter's System One API might not accept exactly the
  `{model, state, questions}` body this mod's `typesafe` path sends (e.g. a
  different required field, or `model` expected in the URL rather than the
  body) → **Mitigation**: this is called out explicitly as an unverified
  hypothesis in the proposal; a manual `curl` smoke test against the live
  endpoint (with a real OpenRouter key) is a recommended manual step before
  or shortly after configuring `typesafeApiKey`, not a task this change
  claims to have completed.
- **[Risk]** A mod auto-loaded from the global skills-dir might hit a
  workspace-trust prompt whose state lives in each persona's own
  `.claude.json` (not symlinked), meaning the mod silently doesn't load in a
  project/persona combination until that prompt is cleared once → **Mitigation**:
  documented as a manual per-persona verification step, not something this
  change scripts around; if it turns out to block silently with no visible
  prompt, that's new information for a follow-up change, not a reason to
  guess at a workaround now.
- **[Risk]** Upstream renames or restructures the mod's directory (e.g. adds
  a new hook module file) without a tagged release to pin to → **Mitigation**:
  the externals track `main` with a 168h `refreshPeriod`, the same
  update-lag trade-off this repo already accepts for its other `main`/`master`-tracked
  externals (`.oh-my-zsh`, `zsh-claude-env`, etc.); a broken upstream change
  surfaces as a failed `chezmoi apply` fetch, not silent corruption.
- **[Trade-off]** Declaring `pluginConfigs.jev-model-router.options` in all
  four personas' `.claude-settings.json`, even before any key is set
  anywhere, means three of the four personas carry inert configuration
  until their key is added. Accepted because it's harmless (the mod falls
  back to the built-in classifier with no key) and keeps the four files
  consistent rather than drifting.

## Migration Plan

No migration - this is new vendored content and new settings keys, nothing
existing is restructured or removed. Rollback is deleting the new
`.chezmoiexternal.toml.tmpl` file and the added `pluginConfigs` blocks /
shell-rc exports, then re-running `chezmoi apply`, which will remove the
vendored files (external no longer declared) and retract the settings
entries (per `claude-settings-ledger`'s existing retraction semantics - no
new retraction behavior is introduced here).
