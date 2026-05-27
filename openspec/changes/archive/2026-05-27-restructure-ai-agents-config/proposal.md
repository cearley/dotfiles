## Why

The `skills`, `plugin_marketplaces`, `plugins`, and `mcp` keys in `packages.yaml` are Claude-Code-specific but currently sit at the top level of both the `dev` and `ai` tags alongside generic package fields (`brews`, `casks`, `uv`, `bun`, `cargo`). This conflates "what AI tools to install" with "how Claude Code is configured", and gives no place to declare equivalents for other coding agents (Codex, Gemini CLI, Cursor) the user is increasingly likely to run side-by-side. Reorganizing now — while there is only one agent populated — is much cheaper than after a second agent is added.

## What Changes

- **BREAKING** Move `skills`, `plugin_marketplaces`, and `plugins` from `packages.darwin.ai.*` and `packages.darwin.dev.*` into a new namespace: `packages.darwin.ai.agents.claude_code.*`.
- **BREAKING** Rename `mcp` → `mcp_servers` and move it from `packages.darwin.dev.mcp` into `packages.darwin.ai.agents.claude_code.mcp_servers`.
- Add commented placeholder stubs for `agents.codex` and `agents.gemini` under `ai.agents` to document the schema without polluting active data.
- Consolidate under `ai`: anything currently under `dev` that relates to Claude Code moves to `ai`, on the rationale that the `dev` tag implies `ai` in practice and the user wants these installed whenever `ai` is selected, regardless of whether `dev` is also selected.
- **New script**: add `run_onchange_after_darwin-38-install-claude-mcp-servers.sh.tmpl` to register declared MCP servers via `claude mcp add --scope user <name> -- <command...>`. This closes a pre-existing gap where `mcp` entries in `packages.yaml` were never installed by any script.
- **Renames** (to keep MCP grouped with skills/plugins at consecutive positions):
  - `…-38-install-claude-plugins.sh.tmpl` → `…-39-install-claude-plugins.sh.tmpl`
  - `…-39-load-claude-launchagent.sh.tmpl` → `…-40-load-claude-launchagent.sh.tmpl`
- Update consuming scripts to read from the new path:
  - `run_onchange_after_darwin-37-install-claude-skills.sh.tmpl`
  - (renamed) `run_onchange_after_darwin-39-install-claude-plugins.sh.tmpl`
  - `home/scripts/audit-packages.sh` (also gains a new `audit_claude_mcp_servers` section)
- Update `home/CLAUDE.md` / `openspec/specs/package-management/spec.md` references to the new script numbering.
- Update `openspec/specs/package-management/spec.md` to document the new `agents` namespace, its tag gating, and the MCP install script.

## Capabilities

### New Capabilities
<!-- None — this change refactors existing behavior. -->

### Modified Capabilities
- `package-management`: Adds an `agents` sub-namespace under the `ai` tag for per-coding-agent configuration (skills, plugins, marketplaces, MCP servers). Renames `mcp` to `mcp_servers`. Relocates Claude-Code-specific keys from `dev` to `ai`.

## Impact

- **Data file**: `home/.chezmoidata/packages.yaml` — structural change to the `ai` and `dev` tag sections.
- **Scripts**:
  - `home/.chezmoiscripts/run_onchange_after_darwin-37-install-claude-skills.sh.tmpl` — replace per-tag iteration with direct read of `ai.agents.claude_code.skills`.
  - `home/.chezmoiscripts/run_onchange_after_darwin-38-install-claude-mcp-servers.sh.tmpl` — **NEW** script registering MCP servers from `ai.agents.claude_code.mcp_servers` per Claude env.
  - `home/.chezmoiscripts/run_onchange_after_darwin-39-install-claude-plugins.sh.tmpl` — **RENAMED** from `…-38-…`; replace per-tag iteration with direct read of `ai.agents.claude_code.{plugin_marketplaces,plugins}`.
  - `home/.chezmoiscripts/run_onchange_after_darwin-40-load-claude-launchagent.sh.tmpl` — **RENAMED** from `…-39-…`; no content change.
  - `home/scripts/audit-packages.sh` — switch Claude sections to read agent-scoped paths; add new `audit_claude_mcp_servers` section.
- **Docs**: `CLAUDE.md` (project-level) — bump position numbers in the "Script execution order" reference.
- **Spec**: `openspec/specs/package-management/spec.md` — add requirements describing the agents namespace and the MCP install script.
- **Tag behavior**: Items currently gated on `dev` move to `ai`. Anyone running `core,dev` without `ai` will no longer get the Claude-Code-specific marketplaces/plugins that were under `dev`. This matches the user's intent ("dev implies ai in practice"); not expected to affect any real machine config.
- **Position-range note**: The Claude LaunchAgent ends up at position 40, one slot into the "Env Setup" range. This is a minor convention bend; LaunchAgent at 39 was already at the range boundary.
- **Unaffected**: Homebrew/UV/Bun/Cargo installation, Brewfile handling, `ai` brew/cask/uv/bun/cargo lists, all non-Claude-Code scripts.

## Non-goals

- Implementing Codex or Gemini CLI installers or wiring. The stubs are documentation-only; no scripts will read `ai.agents.codex` or `ai.agents.gemini` after this change.
- Removing stale MCP servers (entries previously registered but no longer declared in `packages.yaml`). The new script is additive/idempotent, matching the pattern of the skills and plugins scripts. Cleanup remains a manual `claude mcp remove` operation.
- Cross-agent shared configuration (e.g. a `shared.mcp_servers` list applied to all agents). YAGNI until a second agent is actually populated.
- Touching skill collection contents, plugin selections, or marketplace lists. This is purely a structural refactor (plus closing the MCP-install gap); no items are added or removed.
