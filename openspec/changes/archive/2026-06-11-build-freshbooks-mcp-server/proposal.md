## Why

The FreshBooks MCP server is fetched as an external git-repo by chezmoi but ships as TypeScript source — it must be compiled before it can run. Without a build step, the server directory lands on disk as unbuilt source and any MCP client attempting to launch it will fail.

## What Changes

- Add `run_onchange_after_darwin-38-build-freshbooks-mcp-server.sh.tmpl`: a chezmoi script that runs `npm install && npm run build` inside `~/.local/share/freshbooks-mcp-server` after every 30-day time-bucket cycle (matching the external's `refreshPeriod`)
- Gate on `darwin` + `ai` + `dev` tags, matching the gate on the external entry in `.chezmoiexternal.toml.tmpl`
- The external entry itself (`.chezmoiexternal.toml.tmpl`) was already updated in the same session to add `[".local/share/freshbooks-mcp-server"]`

## Capabilities

### New Capabilities

- `freshbooks-mcp-server-build`: Automated post-fetch build step for the FreshBooks MCP server external dependency

### Modified Capabilities

- `package-management`: The external-dependency lifecycle now includes an npm build phase for TypeScript MCP servers, extending beyond simple file placement

## Impact

- **New file**: `home/.chezmoiscripts/run_onchange_after_darwin-38-build-freshbooks-mcp-server.sh.tmpl`
- **Tags affected**: `ai` + `dev` (build script is a no-op on machines without both tags)
- **Dependencies**: requires `npm` (Node.js) to be available at apply time — Node is installed via nvm (script 35), so this script at position 38 runs after nvm setup
- **No breaking changes**: script gracefully skips if the server directory is missing

## Non-goals

- Registering the built server as an MCP server in Claude Code (that belongs in the existing `38-install-claude-mcp-servers` script)
- Managing Node.js version pinning for the build
- Supporting non-macOS platforms
