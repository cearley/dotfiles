## Why

`~/.claude-bedrock/settings.json`'s `env` block currently persists `AWS_PROFILE` and `AWS_CREDENTIAL_PROCESS` at rest, where they're read on every Claude Code invocation regardless of need. Scoping these two values to only the `claude` process invocation itself — the same way `CLAUDE_CONFIG_DIR` is already scoped per-invocation — reduces the surface where Bedrock-related configuration persists in a config file instead of living transiently in the shell.

## What Changes

- Extend `home/.chezmoitemplates/claude-environments` so every `claude-<name>()` function optionally sources `~/.config/claude-env/<name>.env` (if the file exists) and exports its variables only for that one `claude` invocation. This generalizes the mechanism across all `claude_envs` entries rather than special-casing `bedrock`.
- This mirrors the existing `mcp-env-wrapper` pattern (see `openspec/specs/mcp-env-injection/spec.md`), which already establishes untracked, user-managed env files as the convention for personal/machine-specific values like `AWS_PROFILE`.
- Remove `AWS_PROFILE` and `AWS_CREDENTIAL_PROCESS` from `~/.claude-bedrock/settings.json`'s `env` block (a live, non-chezmoi-managed edit — that file's `env` key is preserved as-is by `modify_settings.json.tmpl`, not templated).
- Create `~/.config/claude-env/bedrock.env` (untracked, user-managed, created directly — not chezmoi source state) containing the two values.
- No chezmoi data file (e.g. `config.yaml`) will store these values. This repo is public (`github.com/cearley/dotfiles`) and `config.yaml` is git-tracked, so a data-driven approach (like `claude_env_colors`) is not appropriate for personal secrets/paths.

## Non-Goals

- Not building a general-purpose secrets manager for Claude environments — this only adds an optional per-environment env-file sourcing step, structurally identical to the existing MCP env injection pattern.
- Not changing how `CLAUDE_CONFIG_DIR` or any other existing `claude-<name>()` behavior works for environments that don't have a `~/.config/claude-env/<name>.env` file — the change is a no-op for `work` and `personal`.
- Not restricting what the `claude` process itself can do with these vars once set (e.g. subprocess/tool inheritance within a single Claude session) — the goal is keeping them out of persisted settings.json, not process-tree isolation within one invocation.
- Not migrating `~/.claude-bedrock/settings.json`'s other `env` entries (e.g. `AWS_REGION`, model overrides, OTEL config) — only `AWS_PROFILE` and `AWS_CREDENTIAL_PROCESS` are in scope.

## Capabilities

### New Capabilities
(none)

### Modified Capabilities
- `claude-environments`: The "Per-Environment Shell Functions" requirement gains an optional local env-file-sourcing step, applied generically to every entry in `claude_envs` (not bedrock-specific).

## Impact

- `home/.chezmoitemplates/claude-environments` — template logic change to `claude-<name>()` function generation
- `openspec/specs/claude-environments/spec.md` — new requirement/scenarios via delta spec
- `~/.claude-bedrock/settings.json` — manual edit removing two `env` keys; outside chezmoi's management scope (not a chezmoi source-state change)
- New untracked file `~/.config/claude-env/bedrock.env` — created directly on this machine, never committed to the repo
- Scope: `ai`-tagged machines only; `work` and `personal` environments unaffected unless a matching env file is later created for them
