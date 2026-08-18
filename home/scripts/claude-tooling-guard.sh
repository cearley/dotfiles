#!/bin/bash
# claude-tooling-guard.sh — PreToolUse hook (Bash matcher) that reminds Claude to check
# claude-tooling.md before editing Claude Code skill/MCP/plugin config directly via a
# shell command (jq/mv/sed/etc.), which bypasses the path-frontmatter auto-load that
# normally triggers claude-tooling.md for Read/Edit/Write on the same paths.
# Read-only: never blocks, never modifies anything — only injects a reminder.
set -euo pipefail

jq -r --arg pattern '\.claude[A-Za-z0-9_-]*/settings\.json|\.claude[A-Za-z0-9_-]*/\.claude\.json|\.chezmoidata/packages\.yaml|dot_claude(-[A-Za-z0-9_-]+)?/' '
  (.tool_input.command // "") as $command
  | if ($command != "" and ($command | test($pattern))) then
      {
        hookSpecificOutput: { permissionDecision: "allow" },
        systemMessage: "This command touches Claude Code skill/MCP/plugin config that this machine'\''s chezmoi dotfiles repo manages. Before editing settings.json/.claude.json skillOverrides, disabledMcpServers, or enabledPlugins directly: check whether the target is DECLARED in home/.chezmoidata/packages.yaml (packages.darwin.ai.agents.claude_code) — if so, edit that declaration instead, since a local override only drifts from the declared state without undoing it. Full guidance: ~/.claude/rules/claude-tooling.md"
      } | tojson
    else
      empty
    end
'
