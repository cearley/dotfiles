## Why

MCP clients don't always inherit the user's shell environment. GUI clients (Claude Desktop) are launched by macOS launchd and never inherit `~/.zshrc`/`~/.bashrc`. Terminal clients (Claude Code) usually inherit the shell but may not when launched from an IDE, launcher, or non-login context. In both cases, the only reliable way to inject env vars today is to hardcode them in the client's config file, which is chezmoi-managed and requires `chezmoi apply` to change — friction that defeats per-machine tuning.

## What Changes

- **New**: `~/.local/bin/mcp-env-wrapper` — a generic wrapper script that sources `~/.config/mcp-env/<server-name>.env` (if present) before exec'ing any MCP server command, for any client type
- **New**: `private_dot_config/mcp-env/private_localstack-mcp-server.env.tmpl` — chezmoi-managed env file for localstack; `LOCALSTACK_AUTH_TOKEN` sourced from KeePassXC at `chezmoi apply` time
- **Modified**: `modify_claude_desktop_config.json.tmpl` — `aws-mcp` entry updated to use `mcp-env-wrapper`; `env` block removed
- **Modified**: `run_onchange_after_darwin-38-install-claude-mcp-servers.sh.tmpl` — registration parser extended to support bare `-- ` separator (no `-e` flags) alongside existing `-e VAR -- ` format
- **Modified**: `packages.yaml` — `localstack-mcp-server` switched from `-e LOCALSTACK_AUTH_TOKEN` to `mcp-env-wrapper`
- **Modified**: `private_dot_zsh_secrets.tmpl` — `LOCALSTACK_AUTH_TOKEN` removed; no longer needed in shell environment
- **Removed**: `executable_aws-mcp-wrapper` — superseded by the generic wrapper

## Capabilities

### New Capabilities

- `mcp-env-injection`: Per-server environment variable injection for MCP servers launched by any client (GUI or terminal). Env files live at `~/.config/mcp-env/<server-name>.env`. Files containing KeePassXC-sourced secrets are chezmoi-managed templates; files containing personal/local values (e.g. `AWS_PROFILE`) are user-managed and untracked. Necessary for GUI clients; provides a consistent launch-context-independent injection point for terminal clients too.

### Modified Capabilities

<!-- No existing spec-level requirement changes -->

## Non-Goals

- Chezmoi-managing env files that contain personal/local values (e.g. `AWS_PROFILE`) — those remain user-edited files
- Replacing the `env` block for static, non-sensitive config values (e.g. `FASTMCP_LOG_LEVEL`)
- Wrapping every MCP server — opt-in per server

## Impact

- `home/dot_local/bin/executable_mcp-env-wrapper` — new chezmoi-managed file
- `home/private_Library/private_Application Support/Claude/modify_claude_desktop_config.json.tmpl` — `aws-mcp` command and args updated
- `home/.chezmoiscripts/run_onchange_after_darwin-38-install-claude-mcp-servers.sh.tmpl` — parser extended
- `home/.chezmoidata/packages.yaml` — `localstack-mcp-server` registration updated
- Affects machines with the `ai` tag (Desktop config, wrapper) and `ai+dev` tags (localstack env file)
- `home/private_dot_config/mcp-env/private_localstack-mcp-server.env.tmpl` — new chezmoi-managed secret file (KeePassXC-sourced)
- `home/private_dot_zsh_secrets.tmpl` — `LOCALSTACK_AUTH_TOKEN` removed
