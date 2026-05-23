## Why

Three pieces of Claude environment wiring — per-env shell functions (`claude-bedrock`, `claude-personal`, `claude-work`), `*-spec` aliases, and the new `claude-env` switcher's case statement — are hardcoded in the `claude-environments` partial, while the canonical list of provisioned environments lives in `claude_envs` in `home/.chezmoidata/config.yaml`. The two can drift: `claude_default` may point to an env that isn't in `claude_envs` (typo or omission), and `claude-env <name>` will silently `export CLAUDE_CONFIG_DIR` to a path that was never provisioned. Adding a fourth env (e.g., `claude-school`) today requires editing `config.yaml` *and* the partial in three separate places.

## What Changes

- **BREAKING**: `claude_envs` becomes the single source of truth for which Claude environments exist on a machine. The `claude-environments` partial generates per-env functions, `*-spec` aliases, and the `claude-env` case statement by deriving names from `claude_envs` at template-render time.
- **BREAKING**: `claude_envs` entries MUST match the pattern `~/.claude-<name>`. Non-conforming entries cause `chezmoi apply` to fail with a precise error.
- **BREAKING**: When `claude_default` is set, it MUST equal `claude-<name>` for some `<name>` derived from `claude_envs`. A mismatch causes `chezmoi apply` to fail with a precise error.
- The set of valid arguments to `claude-env` is now per-machine: on Mac Studio (envs: personal, work) the function rejects `bedrock`; on a future machine with a `school` env, `claude-env school` works automatically.
- On a machine with the `ai` tag but empty `claude_envs`, the partial emits no per-env wrappers and the `claude-env` switcher reports an empty valid set in its usage message.
- Color palette in `prompt_claude_env` stays hardcoded (`work=33 / personal=76 / bedrock=208 / *=244`); newly added envs render in grey until colors are made data-driven in a follow-up change.

## Capabilities

### New Capabilities
<!-- None -->

### Modified Capabilities
- `claude-environments`: Per-environment shell functions, `*-spec` aliases, and the `claude-env` switcher SHALL be derived from the machine's `claude_envs` list at template-render time. The partial SHALL fail at template-render time when `claude_envs` contains a non-conforming entry or when `claude_default` does not match any derived name.

## Impact

- **Affected files**:
  - `home/.chezmoitemplates/claude-environments` — adds template-time validation guard, replaces three hardcoded function definitions with a `range` over derived env names, replaces three hardcoded `*-spec` aliases with a `range`, replaces hardcoded case pattern in `claude-env` with derived alternation.
  - `home/.chezmoidata/config.yaml` — comment block updated to document that `claude_envs` paths MUST match `~/.claude-<name>` and that `claude_default` MUST equal `claude-<name>` for an entry in `claude_envs`.
  - `openspec/specs/claude-environments/spec.md` — modified delta: existing scenarios for fixed `claude-bedrock|personal|work` functions and `*-spec` aliases generalize to "for each name derived from `claude_envs`"; the `claude-env` "Switch to a known environment" scenario generalizes the same way; new requirement adds template-render-time validation.
- **Tags affected**: `ai` only (the partial is gated on `has "ai" .tags`).
- **Machines affected**:
  - MacBook Pro (envs: bedrock, personal, work) — same wrappers and case as today; behavior unchanged.
  - Mac Studio (envs: personal, work) — `claude-bedrock`, `claude-bedrock-spec` no longer defined; `claude-env bedrock` rejected with usage. (Today these silently target a never-provisioned directory.)
  - Mac mini (no `ai` tag) — partial emits nothing; unchanged.
- **Dependencies**: none. Pure refactor of existing template logic plus a fail-fast guard. No new packages, no new files, no new scripts.
- **Security implications**: none. No secret handling, no permission changes, no SIP-relevant operations.

## Non-goals

- Making the prompt-segment color palette data-driven. Each new env still falls back to grey 244 until a follow-up change adds a per-env color in `claude_envs` (e.g., as a dict of `{path, color}` rather than a list of paths).
- Detecting that an env listed in `claude_envs` lacks a `~/.claude-<name>` directory on disk. Existing `install-claude-skills` and `install-claude-plugins` scripts already skip missing directories; this change does not add a separate provisioning check.
- Folding the `claude-spec`, `codex-spec`, `gemini-spec`, and `openspecui` aliases into the per-env loop. They are not env-specific and remain hardcoded.
