## Why

`home/.chezmoidata/packages.yaml` currently installs a set of MCP servers, skills, and plugins user-scope, on every machine with the `ai` tag — regardless of whether a given project actually needs them. Several of these (the `localstack-mcp-server`, `playwright`, and `safari` MCP servers; the `openspec` MCP server's `--with-dashboard` flag; the 8 `wondelai/*` skills; and the commented-out `atlassian`/`aws-core`/`cloudflare` plugins) are genuinely project-specific rather than needed in every session. There is currently no opt-in mechanism for these — either they're always installed, or they exist only as inert comments. The existing `chezmoi-personal` plugin marketplace (used previously for `basic-memory-workflow`) already provides exactly this per-project opt-in mechanism, but its current spec assumes a marketplace of one self-authored plugin and doesn't yet support the shapes these capabilities need (bundled `.mcp.json` servers, skill-only wrapper entries, and re-pointing at third-party plugin sources).

## What Changes

- Remove `localstack-mcp-server`, `playwright`, `safari`, and `openspec` from `packages.darwin.ai.agents.claude_code.mcp_servers`, and the 8 `wondelai/*` entries from `.skills`, in `home/.chezmoidata/packages.yaml`. The `@fission-ai/openspec@latest` Bun-installed CLI is unaffected — only the MCP server registration (with `--with-dashboard`) moves.
- Remove the commented-out `atlassian@claude-plugins-official`, `aws-core@agent-toolkit-for-aws`, and `cloudflare@cloudflare` lines from `.plugins` — they become real installable entries in `chezmoi-personal` instead of inert comments.
- Add 8 new plugins under `plugins/` in the `chezmoi-personal` marketplace, each individually installable via `claude plugins install <name>@chezmoi-personal`:
  - `aws-local-dev` — bundles the `localstack-mcp-server` MCP server via `.mcp.json` (routed through the existing `mcp-env-wrapper` for `LOCALSTACK_AUTH_TOKEN`)
  - `browser-tools` — bundles the `playwright` and `safari` MCP servers via `.mcp.json`
  - `openspec-dashboard` — bundles the `openspec` MCP server (`--with-dashboard`) via `.mcp.json`
  - `code-quality` — bundles 5 wondelai skills (`clean-code`, `refactoring-patterns`, `clean-architecture`, `software-design-philosophy`, `pragmatic-programmer`) as a marketplace `skills` array pointing at the `wondelai/skills` repo, no local content copy
  - `systems-design` — bundles 3 wondelai skills (`domain-driven-design`, `ddia-systems`, `system-design`) the same way
  - `atlassian`, `aws-core`, `cloudflare` — re-point at the same upstream sources `claude-plugins-official` / `agent-toolkit-for-aws` / `cloudflare/skills` already use, so each installs from `chezmoi-personal` independent of those marketplaces being registered
- Revise the `claude-plugin-marketplace` spec to explicitly permit the marketplace shapes above: third-party git/URL sources on individual plugin entries, `.mcp.json`-bundling plugins, and source+`skills`-array-only plugins (no `plugin.json` required). The marketplace's own registration mechanism (still a local path, still chezmoi-bootstrapped) is unchanged.
- No new automation for enabling plugins per project — `claude plugins install <name>@chezmoi-personal`, run by hand, is the intended workflow (per the existing "per-project enablement is a separate, manual step" requirement).

**Non-goals**
- Not touching what stays in `packages.yaml` as always-on (`basic-memory`, `fast-filesystem` MCP servers; the basicmachines-co memory skills, `claude-session-index`, `specstoryai` skills; the `claude-code-setup`, `claude-md-management`, `example-skills`, `ralph-loop`, `superpowers` plugins) — these remain user-scope per this change's "core to every session" criterion.
- Not building any auto-enable/browse UI beyond what `claude plugins install` already provides.
- Not vendoring or forking wondelai's skill content — the new plugins reference it live from `wondelai/skills`.
- Not deregistering the `plugin_marketplaces` entries (`claude-plugins-official`, `aws/agent-toolkit-for-aws`, `cloudflare/skills`, etc.) — they stay registered; registration alone has no installation side effect.

## Capabilities

### Modified Capabilities
- `claude-plugin-marketplace`: loosens the "plugin sources must be a local path" requirement to allow individual plugin entries to reference third-party git/URL sources; adds requirements permitting `.mcp.json`-bundling plugins and source+`skills`-array-only plugins (no `plugin.json`) within this marketplace.

## Impact

- **Affected files**: `home/.chezmoidata/packages.yaml` (removals); `.claude-plugin/marketplace.json` (8 new entries); 8 new directories under `plugins/`; `openspec/specs/claude-plugin-marketplace/spec.md` (requirement revisions).
- **Affected tags**: `ai` (all changes are scoped to `packages.darwin.ai.agents.claude_code`; no other tag is touched).
- **Affected scripts**: none of the existing `run_onchange_after_darwin-37/38/39/44` scripts change behavior — they just process shorter lists. No new chezmoi script is needed since plugin installation is manual, not chezmoi-bootstrapped.
- **Security implications**: none of the moved capabilities carry secrets except `localstack-mcp-server`'s `LOCALSTACK_AUTH_TOKEN`, which stays sourced from the shell environment via `mcp-env-wrapper` exactly as today — no secret handling changes.
- **External dependencies added**: the marketplace now points at third-party repos (`atlassian/atlassian-mcp-server`, `aws/agent-toolkit-for-aws`, `cloudflare/skills`, `wondelai/skills`) directly from `chezmoi-personal`'s own `marketplace.json`, pinned by ref/sha the same way `claude-plugins-official` pins its own entries.
