## 1. Restructure packages.yaml

- [x] 1.1 Remove `mcp`, (empty) `skills`, `plugin_marketplaces`, `plugins` from `packages.darwin.dev`
- [x] 1.2 Remove `skills`, `plugin_marketplaces`, `plugins` from `packages.darwin.ai`
- [x] 1.3 Add `packages.darwin.ai.agents.claude_code` with `mcp_servers`, `skills`, `plugin_marketplaces`, `plugins` populated from the items removed in 1.1 and 1.2 (rename `mcp` → `mcp_servers`)
- [x] 1.4 Add commented placeholder blocks for `codex` and `gemini` under `ai.agents` (no live keys, just documentation of the schema)
- [x] 1.5 Verify `packages.yaml` parses with `yq '.packages.darwin.ai.agents' home/.chezmoidata/packages.yaml`

## 2. Rename existing Claude scripts to free position 38

- [x] 2.1 `git mv home/.chezmoiscripts/run_onchange_after_darwin-38-install-claude-plugins.sh.tmpl home/.chezmoiscripts/run_onchange_after_darwin-39-install-claude-plugins.sh.tmpl`
- [x] 2.2 `git mv home/.chezmoiscripts/run_onchange_after_darwin-39-load-claude-launchagent.sh.tmpl home/.chezmoiscripts/run_onchange_after_darwin-40-load-claude-launchagent.sh.tmpl`
- [x] 2.3 Confirm no other files reference the old numbered names (`grep -rn "darwin-38-install-claude-plugins\|darwin-39-load-claude-launchagent" .`)

## 3. Update Claude Code skills install script (position 37)

- [x] 3.1 In `run_onchange_after_darwin-37-install-claude-skills.sh.tmpl`, replace the `range $category := $categories` loop with a direct read of `$.packages.darwin.ai.agents.claude_code.skills`
- [x] 3.2 Guard the install loop on the list being non-empty so the script still prints the env header but no-ops cleanly when no skills are declared
- [x] 3.3 Test the template renders: `chezmoi execute-template < home/.chezmoiscripts/run_onchange_after_darwin-37-install-claude-skills.sh.tmpl`

## 4. New MCP install script (position 38)

- [x] 4.1 Create `home/.chezmoiscripts/run_onchange_after_darwin-38-install-claude-mcp-servers.sh.tmpl`
- [x] 4.2 Gate on `eq .chezmoi.os "darwin"` and `has "ai" .tags`; source `shared-utils.sh`; require `claude` via `require_tools`
- [x] 4.3 Resolve `claude_envs` from machine settings (default `~/.claude`), matching scripts 37 and 39
- [x] 4.4 Iterate `$.packages.darwin.ai.agents.claude_code.mcp_servers`; for each entry, parse first word as `name` and remainder as `command...`
- [x] 4.5 For each Claude env, invoke `CLAUDE_CONFIG_DIR="$env_dir" claude mcp add --scope user "$name" -- $rest`; on failure, `print_message "warning"` and continue
- [x] 4.6 Test the template renders: `chezmoi execute-template < home/.chezmoiscripts/run_onchange_after_darwin-38-install-claude-mcp-servers.sh.tmpl`
- [x] 4.7 Verify the script is executable after apply (chezmoi treats `run_*` scripts as executable)

## 5. Update Claude Code plugins install script (now at position 39)

- [x] 5.1 In the renamed `run_onchange_after_darwin-39-install-claude-plugins.sh.tmpl`, replace the per-tag iteration with direct reads of `$.packages.darwin.ai.agents.claude_code.plugin_marketplaces` and `$.packages.darwin.ai.agents.claude_code.plugins`
- [x] 5.2 Keep the outer `for env_dir` loop and the marketplace-before-plugin ordering unchanged
- [x] 5.3 Test the template renders: `chezmoi execute-template < home/.chezmoiscripts/run_onchange_after_darwin-39-install-claude-plugins.sh.tmpl`

## 6. Update audit-packages.sh

- [x] 6.1 Add a `declared_for_agent <agent> <key>` helper that reads `.packages.darwin.ai.agents.<agent>.<key>[]?`
- [x] 6.2 Update `audit_claude_plugins`, `audit_claude_marketplaces`, and `audit_claude_skills` to call `declared_for_agent "claude_code" "<key>"` instead of `declared_for "<key>"`
- [x] 6.3 Add `audit_claude_mcp_servers`: reads mcpServers from ~/.claude*/settings.json (user-scope); compare against `declared_for_agent "claude_code" "mcp_servers"` reduced to first-token (`awk '{print $1}'`). Note: `claude mcp list --json` is unsupported in this version; settings.json is the reliable source.
- [x] 6.4 Wire `audit_claude_mcp_servers` into `audit_claude` so it runs whenever the `ai` tag is active and `claude` is available
- [x] 6.5 Run `audit-packages` after applying the change to verify no false-positive orphans
- [x] 6.6 Run `audit-packages --strict` to confirm clean exit

## 7. Update docs and canonical spec

- [x] 7.1 In `CLAUDE.md`, update the "Script execution order" reference to: `37: skills | 38: MCP servers | 39: plugins | 40: LaunchAgent`
- [x] 7.2 Apply the spec deltas from `openspec/changes/restructure-ai-agents-config/specs/package-management/spec.md` into `openspec/specs/package-management/spec.md`
- [x] 7.3 Verify spec validates: `openspec validate restructure-ai-agents-config --strict`

## 8. End-to-end verification

- [x] 8.1 `chezmoi diff` shows expected changes (yaml restructure; scripts 37, 38-new, 39-renamed, 40-renamed; audit-packages.sh; CLAUDE.md; spec) with no unrelated drift
- [x] 8.2 `chezmoi apply` succeeds; all renamed/new scripts re-run idempotently and report success
- [x] 8.3 `claude mcp list` shows the playwright server registered (✓ Connected)
- [x] 8.4 `claude plugins list` shows all expected plugins from `ai.agents.claude_code.plugins`
- [x] 8.5 Skill collections are present in `~/.claude-personal/skills/`
- [x] 8.6 `audit-packages` shows zero Claude Code MCP orphans; pre-existing work-env orphans unchanged
