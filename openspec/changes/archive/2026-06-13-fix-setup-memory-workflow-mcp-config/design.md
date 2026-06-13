## Context

The `setup-memory-workflow` skill installs basic-memory session tooling into any project. Previously it wrote the basic-memory MCP server entry directly into `.claude/settings.local.json`. This was wrong in three ways:

1. `.claude/settings.local.json` is for personal Claude Code settings (hooks, permissions), not MCP server declarations. The canonical project-level MCP file is `.mcp.json` at the repo root.
2. The command used (`basic-memory mcp`) doesn't match how the server is globally registered on chezmoi-managed machines (`uvx --python 3.12 basic-memory mcp`), creating subtle inconsistency.
3. The skill always wrote the entry even on machines where basic-memory is already registered globally (via `claude mcp add -s user`), producing redundant — and potentially conflicting — entries.

## Goals / Non-Goals

**Goals:**
- Write MCP server config to `.mcp.json` (project root)
- Use the correct `uvx --python 3.12 basic-memory mcp` command
- Skip the `.mcp.json` write if basic-memory is already globally registered
- Keep the UserPromptSubmit hook in `.claude/settings.local.json` (unchanged)
- Let the user decide whether to gitignore `.mcp.json`

**Non-Goals:**
- Migrating existing `.claude/settings.local.json` entries written by old skill runs
- Changing the hook content or structure
- Modifying the global chezmoi MCP registration in packages.yaml

## Decisions

### Decision: Check `claude mcp list` for global registration
**Chosen**: `claude mcp list 2>/dev/null | grep -q "basic-memory"`

**Why**: This is the most direct way to ask Claude Code itself whether the server is registered in the active environment. It works regardless of *how* registration happened (chezmoi script, manual `claude mcp add`, or existing `.mcp.json`).

**Alternative considered**: Check for the binary (`which basic-memory`) — rejected because binary presence doesn't imply MCP registration.

**Alternative considered**: Check `~/.claude-*/settings.json` files directly — rejected because it couples the skill to internal Claude Code file formats, which may change.

**Caveat**: `claude mcp list` reflects the *active* Claude environment (`CLAUDE_CONFIG_DIR`). A user running the skill in a non-default environment where basic-memory isn't registered will get `.mcp.json` written even if it's registered elsewhere. This is acceptable — the project-level `.mcp.json` is valid and useful in that case.

### Decision: `.mcp.json` format — `mcpServers` key
**Chosen**: Write `{"mcpServers": {"basic-memory": {...}}}` to `.mcp.json`

**Why**: This matches the Claude Code documented format for project-level MCP config files, consistent with how `.claude/settings.json` and `.claude/settings.local.json` structure their `mcpServers` keys.

**Merge strategy**: Use jq `//=` to set the key only if absent — same idempotency pattern already used for the settings.local.json hook. If `.mcp.json` doesn't exist, create it with `echo '{}'` first.

### Decision: Let user decide on gitignore
**Chosen**: Mention `.mcp.json` in the confirm step with a note about gitignore, no automatic action.

**Why**: `.mcp.json` has two legitimate uses: team-shared (committed) and personal (gitignored). The skill can't know which context applies. Automating gitignore would be wrong for shared setups; not mentioning it would leave users confused.

## Risks / Trade-offs

**Risk: `claude mcp list` is slow or unavailable** → Mitigation: redirect stderr to `/dev/null`, treat failure as "not registered" and proceed with `.mcp.json` write. This is safe — a redundant entry is harmless.

**Risk: `.mcp.json` conflicts with an existing file that uses a different schema** → Mitigation: the `//=` merge is additive; it never overwrites existing keys. If the file is malformed, jq exits non-zero and the verification step catches it.

**Risk: Divergence from upstream superpowers `setup-memory-workflow` skill** → The chezmoi-managed skill and the plugin version are already separate files. This change is intentional: the chezmoi version knows about `uvx`, `.mcp.json`, and global registration in a way the generic plugin version doesn't. Acceptable divergence.

## Migration Plan

No automated migration. Existing `.claude/settings.local.json` entries written by previous skill runs remain in place but are now inert (they're valid JSON Claude Code will still read, but the MCP server is better declared in `.mcp.json`). Users who want to clean up can manually remove the `mcpServers["basic-memory"]` key from `settings.local.json`.

The SKILL.md and spec.md are the only files to update. No chezmoi scripts, templates, or packages.yaml need changing.

## Open Questions

_(none — all decisions resolved in exploration)_
