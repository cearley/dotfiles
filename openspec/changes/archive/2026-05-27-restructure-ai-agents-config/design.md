## Context

`packages.yaml` currently mixes two unrelated concerns inside the `dev` and `ai` tags:

1. **Generic ecosystem packages** that other layers install (`brews`, `casks`, `uv`, `bun`, `cargo`).
2. **Claude-Code-specific configuration** (`skills`, `plugin_marketplaces`, `plugins`, `mcp`) — concepts that exist only because Claude Code is the user's coding agent.

Consuming scripts (`run_onchange_after_darwin-37-install-claude-skills.sh.tmpl`, `run_onchange_after_darwin-38-install-claude-plugins.sh.tmpl`) iterate over *every* active tag looking for these keys, which lets the same Claude-Code concept appear under both `dev` and `ai`. That worked when Claude Code was the only AI coding agent in scope, but the user is starting to use Codex and Gemini CLI in parallel. There's no place to put their equivalents without inventing a parallel set of top-level keys.

Reorganizing now — when only `claude_code` is populated — is strictly cheaper than after a second agent is in production.

## Goals / Non-Goals

**Goals:**
- One namespace for each coding agent's configuration: `ai.agents.<agent>.*`.
- Make Claude-Code-specific keys (`skills`, `plugin_marketplaces`, `plugins`, `mcp_servers`) discoverable by structure, not by scanning every tag.
- Preserve the existing install/audit behavior of the items being moved — no item added, no item removed.
- **Close the MCP gap**: declared `mcp_servers` entries SHALL actually be installed by a chezmoi script (parity with skills and plugins).
- Document the schema for `codex` and `gemini` so it's obvious where to add their configuration when the time comes.

**Non-Goals:**
- Implementing installers for Codex or Gemini CLI.
- Removing stale MCP servers from Claude config when they're removed from `packages.yaml` (matches the additive-only pattern of skills/plugins scripts).
- Cross-agent shared sections (e.g. `ai.shared.mcp_servers`). YAGNI until the second agent is real.
- Touching any items inside the moved lists.

## Decisions

### D1. Namespace shape: `ai.agents.<agent>.<key>` (vs. flat per-agent prefixes)

**Chosen:**
```yaml
ai:
  agents:
    claude_code:
      mcp_servers: [...]
      skills: [...]
      plugin_marketplaces: [...]
      plugins: [...]
```

**Alternatives considered:**
- *Flat prefix*: `claude_code_skills:`, `claude_code_plugins:` directly under `ai`. Rejected — does not nest cleanly; YAML keys would balloon as agents are added; harder to write `range $agents` over.
- *Top-level `agents` (sibling of `ai`)*: `packages.darwin.agents.claude_code.*`. Rejected — agents only make sense when the `ai` tag is active; nesting under `ai` makes the gating self-evident.
- *YAML anchors for shared MCP servers*: defer — premature with only one agent.

### D2. Field rename: `mcp` → `mcp_servers`

Renamed for clarity: `mcp` ambiguously suggests the protocol; `mcp_servers` makes it clear these are server-registration entries (each item is a server name + launch command). One-shot rename costs nothing because there's no consuming script today.

### D3. Consolidate under `ai` (drop the `dev` half)

All four keys currently appear (or could appear) under both `dev` and `ai`. After this change they live only under `ai`. Rationale from the user: "the `dev` tag implies `ai` in practice."

**Trade-off:** Anyone running `core,dev` without `ai` previously got the Claude-Code items that lived under `dev` (notably `aws/agent-toolkit-for-aws`, `microsoftdocs/mcp` marketplaces, `aws-core@agent-toolkit-for-aws` plugin). After this change those installs require `ai`. No current machine has the `dev`-without-`ai` profile, so this is a documentation note, not a real migration.

### D4. Codex and Gemini as commented placeholders (not empty entries)

```yaml
    # codex:
    #   mcp_servers: []
    #   skills: []
    # gemini:
    #   mcp_servers: []
    #   skills: []
    #   extensions: []
```

Empty live keys would be visible to consumers (the audit script would iterate them); commented placeholders document the schema without polluting active data. When the user actually starts using Codex, uncommenting one block is the entire opt-in.

### D5. Scripts read directly, not via tag iteration

Existing scripts iterate over `$categories := prepend .tag_choices "core"` looking for `$categoryData.skills`. After the move:

```go-template
{{- if has "ai" .tags }}
{{- $claudeCode := index $.packages.darwin.ai.agents "claude_code" }}
{{- if $claudeCode.skills }}
  ...
{{- end }}
{{- end }}
```

This is shorter, more explicit, and trivially extensible (a future Codex install script does the same with `index $.packages.darwin.ai.agents "codex"`).

### D6. Audit script gets a small helper, not a broad refactor

`audit-packages.sh` currently uses `declared_for "<key>"`, which scans every active tag. For agent-keyed items, add a parallel helper:

```bash
declared_for_agent() {
    local agent="$1" key="$2"
    yq ".packages.darwin.ai.agents.${agent}.${key}[]?" "$PACKAGES_YAML" 2>/dev/null | sort -u
}
```

`audit_claude_plugins`, `audit_claude_marketplaces`, and `audit_claude_skills` switch to `declared_for_agent "claude_code" "<key>"`. The `ai`-tag gate already exists in `audit_claude()`, so no new gating logic is needed.

### D7. New MCP install script at position 38

The existing `mcp:` key (under `dev`) has no consuming installer. This change adds `run_onchange_after_darwin-38-install-claude-mcp-servers.sh.tmpl` to register declared servers.

**Position rationale**: Inserting MCP at 38 keeps all Claude-config scripts numerically adjacent (skills 37 → MCP 38 → plugins 39 → LaunchAgent 40). Plugins shifts 38→39 and LaunchAgent shifts 39→40. LaunchAgent ending up at 40 is a one-slot encroachment into the "Env Setup" range; acceptable because LaunchAgent at 39 was already a boundary case (env wiring, not toolchain).

**Alternative considered:** appending MCP at position 40 (no renames). Rejected because it would separate MCP from skills/plugins for no functional gain — MCP, skills, and plugins are all Claude-config concerns and belong together.

**Command syntax** (verified against `claude mcp add --help`):

```bash
claude mcp add --scope user <name> -- <command...>
```

Each entry in `mcp_servers` is parsed as `name` (first word) + `command...` (rest):

```bash
while IFS= read -r entry; do
    [[ -z "$entry" ]] && continue
    read -r name rest <<< "$entry"
    [[ -z "$name" || -z "$rest" ]] && continue
    CLAUDE_CONFIG_DIR="$env_dir" claude mcp add --scope user "$name" -- $rest
done
```

`$rest` is intentionally unquoted so `npx @playwright/mcp@latest` becomes separate argv slots. Server entries with embedded shell metacharacters are out of scope; if a future entry needs them, the template will iterate via a Go-templated array instead of a bash heredoc.

**Idempotency**: `claude mcp add` reports an error if a server with that name is already registered. The script tolerates per-entry failures (warning + continue) rather than aborting, matching the plugins script's resilience pattern. Re-running after no change → all warnings; re-running after edit → only changed/new entries succeed cleanly.

**HTTP transport**: not in current scope. The current entry is stdio. If a future entry needs `--transport http` (or `-e`, `-H` flags), the YAML entry format will need to grow beyond bare `"name command..."` strings, which is a separate change.

### D8. Audit MCP servers from `claude mcp list`

Mirror the plugins audit:

```bash
audit_claude_mcp_servers() {
    # Installed: parse `claude mcp list --json` (jq .[].name), fallback to text
    # Declared: declared_for_agent "claude_code" "mcp_servers" | awk '{print $1}'
    #           (server name only — the command portion is install-time detail)
    report_orphans "Claude Code MCP Servers" "$installed_file" "$declared_file"
}
```

Compare server names only (not full commands) — the audit's job is to flag "this server is registered but not declared", not to verify launch commands match.

## Risks / Trade-offs

- **[Risk] `run_onchange_*` scripts re-trigger on next `chezmoi apply`** → Mitigation: the install commands are idempotent (`npx skills add`, `claude plugins install`); re-running is the cost, not a real risk.
- **[Risk] Someone running `core,dev` (no `ai`) loses access to AWS-toolkit marketplace + plugin that previously lived under `dev`** → Mitigation: user has confirmed this matches their intent ("dev implies ai"); no real machine has the affected profile.
- **[Risk] `mcp` → `mcp_servers` rename is a breaking key change** → Mitigation: nothing reads `mcp` today, so the rename is invisible to current behavior. The audit script doesn't audit MCP either; nothing to update beyond the YAML.
- **[Trade-off] Slightly deeper nesting (`ai.agents.claude_code.skills` vs. `ai.skills`)** — accepted: one extra level is the price of cleanly accommodating multiple agents.

## Migration Plan

This is a single-user dotfiles repo with one production machine. The change is atomic across one commit:

1. Update `packages.yaml` to the new shape.
2. Rename script 38→39 (plugins) and 39→40 (LaunchAgent); add new script 38 (MCP install).
3. Update consumer scripts (37, new-38, renamed-39) and `audit-packages.sh` in the same commit.
4. Update `CLAUDE.md` script-order reference and `openspec/specs/package-management/spec.md`.
5. User runs `chezmoi apply`. All renamed/new scripts hash-trigger and run; install commands are idempotent.
6. User runs `audit-packages` to verify no orphans (including the new MCP section).

**Rollback:** revert the commit. No on-disk state changes outside of (idempotent) Claude Code config that was already going to be reinstalled. MCP servers registered by the new script can be removed via `claude mcp remove <name>` if the rollback needs to be clean.

## Open Questions

None — design is fully constrained by the user's stated intent and the existing consumer scripts.
