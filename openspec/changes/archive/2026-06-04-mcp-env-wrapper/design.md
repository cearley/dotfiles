## Context

MCP clients spawn MCP servers as child processes. The environment those servers receive depends entirely on how the client was launched:

- **GUI clients** (Claude Desktop) — launched by launchd, receive only launchd's minimal environment. Nothing from `~/.zshrc`, `~/.bashrc`, or `~/.profile` is available.
- **Terminal clients** (Claude Code) — launched from a shell, usually inherit the full user environment. However, when launched from an IDE terminal, a launchd agent, or a non-login shell, the environment may be sparse or missing expected vars.

The previous workaround for GUI clients was an `env` block in `claude_desktop_config.json`. For terminal clients, `-e VAR` flags in the MCP server registration forwarded vars from the current shell at registration time. Both approaches coupled runtime values to chezmoi-managed files, requiring `chezmoi apply` to change.

## Goals / Non-Goals

**Goals:**
- Single, reusable wrapper script deployable for any MCP server, any client type
- Per-server env files editable directly, outside chezmoi, at any time
- Both client types (GUI and terminal) supported with consistent mechanism
- Registration script supports wrapper format alongside existing `-e` flag format

**Non-Goals:**
- Chezmoi-managing env files that contain personal/local values (e.g. `AWS_PROFILE`) — those stay user-edited
- Replacing static `env` blocks (e.g. `FASTMCP_LOG_LEVEL=ERROR`) — those are fine in config
- Wrapping every server — opt-in per server

## Decisions

### Single generic script over per-server scripts

**Chosen**: One `mcp-env-wrapper` script; server name passed as first arg.

**Alternatives considered**:
- Per-server scripts (e.g. `aws-mcp-wrapper`) — more scripts to maintain, no reuse
- Symlinks to a single script, name derived via `$0` — implicit magic, fragile if script is called directly

Explicit server name as `$1` is unambiguous and requires no filesystem trickery.

### Env file location: `~/.config/mcp-env/<name>.env`

Follows XDG Base Directory convention (`~/.config/`). Subdirectory `mcp-env/` scopes files clearly, avoids cluttering `~/.config` root. File extension `.env` signals shell-sourceable format.

### Env file management: hybrid model

Env files are managed based on the nature of their values:

- **KeePassXC-sourced secrets** → chezmoi-managed templates (e.g. `private_localstack-mcp-server.env.tmpl`). The value is already obtained from KeePassXC at `chezmoi apply` time; making it a template adds no friction and removes the need to export the token into the general shell environment via `zsh_secrets`.
- **Personal/local values** → user-managed, untracked files (e.g. `aws-mcp.env`). These are machine-specific preferences that change frequently; routing them through `chezmoi apply` would add friction without benefit.

Chezmoi manages the wrapper and any secret-bearing env files; the user manages everything else.

### `exec` for process replacement

The wrapper uses `exec "$@"` to replace itself with the target process. This avoids a dangling shell wrapper process in the MCP server process tree, which some clients inspect.

### Bare `-- ` separator in registration format

The MCP registration script already supported `<name> -e VAR -- <command>`. The wrapper format needs `<name> -- <command>` (no `-e` flags). Rather than changing to the simple format (no `--`), the bare `-- ` variant is added so the format remains visually consistent and the `--` explicitly signals "command starts here". The parser checks `[[ "$_mcp_rest" == "-- "* ]]` before the existing `*" -- "*` check.

### Terminal client command as bare name in packages.yaml

`packages.yaml` is a static data file — no templates, no `$HOME` expansion. Using bare `mcp-env-wrapper` (not `~/.local/bin/mcp-env-wrapper`) relies on PATH, which is valid for terminal clients that inherit the shell environment. Claude Desktop config uses the full template-expanded path.

## Risks / Trade-offs

- **Missing env file** → server runs without expected vars, may fail on first AWS/Localstack call. Mitigation: comment in wrapper script documents the expected file format with an example.
- **Syntax error in env file** → `source` will error, wrapper fails before exec. Mitigation: `.env` format is simple `export KEY=VALUE`; hard to get wrong.
- **`mcp-env-wrapper` not in PATH for terminal client** → registration works but server launch fails. Mitigation: `~/.local/bin` is in PATH on all configured machines; chezmoi deploys the wrapper there.
- **User-managed env file not created** → server runs without expected vars (e.g. `aws-mcp` if `aws-mcp.env` is absent). Mitigation: documented in wrapper comment with example.

## Migration Plan

1. `chezmoi apply` deploys `~/.local/bin/mcp-env-wrapper` (executable)
2. Claude Desktop picks up updated config on next launch → aws-mcp uses wrapper
3. Claude Code re-registers localstack-mcp-server on next `chezmoi apply` → uses wrapper
4. `chezmoi apply` also deploys `~/.config/mcp-env/localstack-mcp-server.env` (KeePassXC-sourced token, `ai+dev` tags only)
5. User creates personal env files as needed: `~/.config/mcp-env/aws-mcp.env` with `AWS_PROFILE` / `AWS_REGION`

Rollback: revert template/packages changes and re-add `env` block / `-e` flags respectively.

## Open Questions

None — implementation is complete.
