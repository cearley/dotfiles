## 1. Update SKILL.md

- [x] 1.1 In step 5, add global-registration check: `claude mcp list 2>/dev/null | grep -q "basic-memory"` before any MCP write; print skip message if found
- [x] 1.2 Replace the `.claude/settings.local.json` MCP server jq block with a `.mcp.json` write: create `{}` if absent, then `jq '.mcpServers["basic-memory"] //= {"command":"uvx","args":["--python","3.12","basic-memory","mcp"]}'`
- [x] 1.3 Rename step 5 to make clear the hook stays in `settings.local.json` while the MCP server goes to `.mcp.json` (split into two clearly labelled sub-steps)
- [x] 1.4 Update step 5.5 verification: add a separate jq check against `.mcp.json` for the MCP server entry; keep the existing hook verification against `settings.local.json`; add a skip note for when global registration was detected
- [x] 1.5 Update step 6 confirm checklist: change MCP server line to reference `.mcp.json`; add note that `.mcp.json` should be gitignored or committed per team preference

## 2. Update spec.md

- [x] 2.1 Sync `openspec/specs/setup-memory-workflow/spec.md` with the delta spec from this change (merge ADDED and MODIFIED requirements into the main spec)
- [x] 2.2 Verify the final spec accurately describes the new behavior end-to-end
