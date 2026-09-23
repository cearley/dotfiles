# Proposal

## Why

On a machine with the `ai` tag but no `claude_envs`, such as Mac mini or a fresh bootstrap VM that matches no machine entry, scripts 38 and 39 fall back to the list `~/.claude` and run `CLAUDE_CONFIG_DIR=$HOME/.claude claude …`. Claude Code doesn't treat that as the unnamed default. With the variable set, it keeps `.claude.json` at `$CLAUDE_CONFIG_DIR/.claude.json`. Unset, which is how a normal session on such a machine runs, it uses `~/.claude.json`.

This was reproduced in a sandboxed `HOME` on 2026-09-23:
- **Script 38 (MCP servers) is broken.** `claude mcp add --scope user` with the variable set wrote to `$HOME/.claude/.claude.json`, and `claude mcp list` with it unset reported "No MCP servers configured". Declared user-scope servers such as `basic-memory` never reach interactive sessions on those machines.
- **Script 39 (plugins) works but leaves clutter.** `settings.json` and `plugins/known_marketplaces.json` were written to the same place either way, but a stray `$HOME/.claude/.claude.json` was created.

## What Changes

- Add a shared utility, `run_claude_in_env <env_dir> <claude args…>`. For `$HOME/.claude` it runs `claude` with `CLAUDE_CONFIG_DIR` removed from its environment. For any other folder it runs `claude` with `CLAUDE_CONFIG_DIR` set to that folder. The variable has to be removed, not just left out, because `chezmoi apply` inherits the shell's exported persona (for example `~/.claude-work`).
- Scripts 38 and 39 call `claude` only through `run_claude_in_env`.
- Manual cleanup on affected machines: delete the stray `~/.claude/.claude.json` after the fixed script 38 has re-registered servers in `~/.claude.json`.

## Non-goals

- Machines with named personas. There `claude_envs` never contains `~/.claude` (config validation requires `~/.claude-<name>`), and setting the variable is correct.
- Script 37 (`npx skills`). It uses `CLAUDE_CONFIG_DIR` only to find `skills/`, which is the same folder either way, and it never writes `.claude.json`.
- Migrating registrations automatically out of the stray file.

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `shared-utilities`: add the requirement "Claude CLI Invocation per Environment" for the `run_claude_in_env` helper.
- `package-management`: add a requirement that MCP-server and plugin registration reach the unnamed default's real config when no personas are declared.

## Impact

- **Files:**
  - `home/scripts/shared-utils.sh` gets the new helper.
  - `home/.chezmoiscripts/run_onchange_after_darwin-38-install-claude-mcp-servers.sh.tmpl` and `…-39-install-claude-plugins.sh.tmpl` switch to calling it.
  - Both scripts' rendered content changes, so `run_onchange` re-runs them once on every `ai` machine. They're idempotent, and on persona machines the behavior is unchanged.
- **Tags:** `ai`.
- **Security:** none. No secrets are involved, and `env -u` only removes a variable.
