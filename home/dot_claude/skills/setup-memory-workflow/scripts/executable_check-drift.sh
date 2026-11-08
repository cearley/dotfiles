#!/usr/bin/env bash
# check-drift.sh — orchestrator: sources lib-project.sh/lib-pieces.sh/
# migrations.sh, defines the piece table, dispatches
# check|update|apply|drift-warn. No note-content logic here (see
# session-reminder.sh); usage docs live in SKILL.md.
set -euo pipefail
SMW_VERSION=19; SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; ASSETS_DIR="$SKILL_DIR/assets"
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd); cd "$PROJECT_ROOT"
# shellcheck source=home/dot_claude/skills/setup-memory-workflow/scripts/lib-project.sh
source "$SKILL_DIR/scripts/lib-project.sh"; PROJECT=$(resolve_project)
# shellcheck source=home/dot_claude/skills/setup-memory-workflow/scripts/lib-pieces.sh
source "$SKILL_DIR/scripts/lib-pieces.sh"
# shellcheck source=home/dot_claude/skills/setup-memory-workflow/scripts/migrations.sh
source "$SKILL_DIR/scripts/migrations.sh"
migrate_hook_config; migrate_sync_memory; migrate_legacy_reminder_hook
TEMPLATED_PIECE_NAMES=(save-session-skill save-session-maintenance-skill)
TEMPLATED_PIECE_PATHS=(".claude/skills/save-session/SKILL.md" ".claude/skills/save-session-maintenance/SKILL.md")
TEMPLATED_PIECE_TEMPLATES=("$ASSETS_DIR/save-session-skill.md.template" "$ASSETS_DIR/save-session-maintenance-skill.md.template")
# Fixed, non-templated, global script paths, no $PROJECT substitution.
HOOK_PIECE_NAMES=(hook-config write-guard-hook crash-recovery-hook)
HOOK_PIECE_LABELS=("SessionStart hook" "PreToolUse write-guard hook" "crash-recovery hook")
HOOK_PIECE_SHORT=(hook "write-guard hook" "crash-recovery hook")
HOOK_PIECE_EVENTS=(SessionStart PreToolUse SessionStart)
HOOK_PIECE_MATCHERS=("" "Bash|Edit|Write" "")
HOOK_PIECE_SUBSTRS=(session-reminder.sh basic-memory-write-guard crash-recovery-hook.sh)
HOOK_PIECE_CMDS=("\${CLAUDE_CONFIG_DIR:-\$HOME/.claude}/skills/setup-memory-workflow/scripts/session-reminder.sh; \${CLAUDE_CONFIG_DIR:-\$HOME/.claude}/skills/setup-memory-workflow/scripts/check-drift.sh drift-warn 2>/dev/null || true" "\${CLAUDE_CONFIG_DIR:-\$HOME/.claude}/skills/setup-memory-workflow/scripts/basic-memory-write-guard.sh" "\${CLAUDE_CONFIG_DIR:-\$HOME/.claude}/skills/setup-memory-workflow/scripts/crash-recovery-hook.sh")
MCP_CANONICAL='{"command":"uvx","args":["--python","3.12","basic-memory","mcp"]}'; MCP_SKIP=no
apply_mcp_piece() {
  [ -f .mcp.json ] || echo '{}' > .mcp.json
  jq '.mcpServers["basic-memory"] = {"command": "uvx", "args": ["--python", "3.12", "basic-memory", "mcp"]}' .mcp.json > .mcp.json.tmp && mv .mcp.json.tmp .mcp.json
  echo "APPLIED: .mcp.json"
}
mcp_piece_handle() {
  local mode="$1" current
  if claude mcp list 2>/dev/null | grep -q "basic-memory"; then echo "SKIP: basic-memory already registered globally"; MCP_SKIP=yes; return; fi
  MCP_SKIP=no; [ -f .mcp.json ] || echo '{}' > .mcp.json
  current=$(jq -c '.mcpServers["basic-memory"] // empty' .mcp.json)
  if [ -z "$current" ]; then apply_mcp_piece >/dev/null; echo "CREATED: basic-memory entry in .mcp.json"
  elif [ "$(echo "$current" | jq -S .)" = "$(echo "$MCP_CANONICAL" | jq -S .)" ]; then echo "UP-TO-DATE: .mcp.json"
  elif [ "$mode" = check ]; then printf 'DRIFT: .mcp.json\n  fix with: check-drift.sh update\n  current:   %s\n  canonical: %s\n' "$current" "$MCP_CANONICAL"
  else apply_mcp_piece
  fi
}
hook_piece_handle() {
  local mode="$1" short="$2" event="$3" matcher="$4" substr="$5" canonical="$6"
  case "$(hook_piece_status .claude/settings.local.json "$event" "$matcher" "$substr" "$canonical")" in
    CREATED) echo "CREATED: $short in .claude/settings.local.json" ;;
    UP-TO-DATE) [ "$mode" = check ] && echo "UP-TO-DATE: $short"; true ;;
    DRIFT)
      if [ "$mode" = check ]; then printf 'DRIFT: %s\n  fix with: check-drift.sh update\n  current:   %s\n  canonical: %s\n' "$short" "$(jq -r --arg ev "$event" --arg m "$substr" '[.hooks[$ev][]?.hooks[]?.command // empty] | map(select(contains($m)))[0] // empty' .claude/settings.local.json)" "$canonical"
      else hook_piece_apply .claude/settings.local.json "$event" "$matcher" "$substr" "$canonical" >/dev/null; echo "APPLIED: $short in .claude/settings.local.json"
      fi
      ;;
  esac
}
cmd_run() {
  local mode="$1" i
  [ "$mode" = check ] && { echo "== basic-memory installed =="; command -v basic-memory &>/dev/null || { echo "MISSING: basic-memory not found — install with 'uv tool install basic-memory', then stop."; exit 1; }; echo "PASS"; echo "== project registration ($PROJECT) =="; basic-memory project add "$PROJECT" "$HOME/.local/share/basic-memory/$PROJECT"; }
  for i in "${!TEMPLATED_PIECE_NAMES[@]}"; do
    mkdir -p "$(dirname "${TEMPLATED_PIECE_PATHS[$i]}")"; if [ "$mode" = check ]; then echo "== ${TEMPLATED_PIECE_NAMES[$i]} =="; report_templated_piece "${TEMPLATED_PIECE_PATHS[$i]}" "${TEMPLATED_PIECE_TEMPLATES[$i]}"
    else update_templated_piece "${TEMPLATED_PIECE_NAMES[$i]}" "${TEMPLATED_PIECE_PATHS[$i]}" "${TEMPLATED_PIECE_TEMPLATES[$i]}"; fi
  done
  [ "$mode" = check ] && echo "== .mcp.json =="; mcp_piece_handle "$mode"
  [ -f .claude/settings.local.json ] || echo '{}' > .claude/settings.local.json
  for i in "${!HOOK_PIECE_NAMES[@]}"; do
    [ "$mode" = check ] && echo "== ${HOOK_PIECE_LABELS[$i]} =="; hook_piece_handle "$mode" "${HOOK_PIECE_SHORT[$i]}" "${HOOK_PIECE_EVENTS[$i]}" "${HOOK_PIECE_MATCHERS[$i]}" "${HOOK_PIECE_SUBSTRS[$i]}" "${HOOK_PIECE_CMDS[$i]}"
  done
  [ "$mode" = check ] || return 0; echo "== verification =="
  if [ "$MCP_SKIP" = yes ]; then echo "SKIP: .mcp.json (basic-memory registered globally, see above)"
  else jq '{mcp: .mcpServers["basic-memory"]}' .mcp.json || { echo "ERROR: malformed .mcp.json"; exit 1; }; fi
  jq '{hook_commands: [.hooks.SessionStart[]?.hooks[]?.command // ""]}' .claude/settings.local.json || { echo "ERROR: malformed settings.local.json"; exit 1; }
}
cmd_apply() {
  local piece="$1" i
  for i in "${!TEMPLATED_PIECE_NAMES[@]}"; do
    [ "$piece" = "${TEMPLATED_PIECE_NAMES[$i]}" ] || continue
    mkdir -p "$(dirname "${TEMPLATED_PIECE_PATHS[$i]}")"; apply_templated_file "${TEMPLATED_PIECE_PATHS[$i]}" "${TEMPLATED_PIECE_TEMPLATES[$i]}"; return
  done
  for i in "${!HOOK_PIECE_NAMES[@]}"; do
    [ "$piece" = "${HOOK_PIECE_NAMES[$i]}" ] || continue
    [ -f .claude/settings.local.json ] || echo '{}' > .claude/settings.local.json; hook_piece_apply .claude/settings.local.json "${HOOK_PIECE_EVENTS[$i]}" "${HOOK_PIECE_MATCHERS[$i]}" "${HOOK_PIECE_SUBSTRS[$i]}" "${HOOK_PIECE_CMDS[$i]}" >/dev/null; echo "APPLIED: ${HOOK_PIECE_SHORT[$i]} in .claude/settings.local.json"; return
  done
  [ "$piece" = "mcp-config" ] && { apply_mcp_piece; return; }
  echo "Unknown piece: $piece (expected save-session-skill|save-session-maintenance-skill|mcp-config|hook-config|write-guard-hook|crash-recovery-hook)" >&2; exit 1
}
cmd_drift_warn() {
  local file=".claude/skills/save-session/SKILL.md" installed_version; [ -f "$file" ] || return 0
  installed_version=$(grep -o 'setup-memory-workflow-version:[0-9]*' "$file" 2>/dev/null | grep -o '[0-9]*$' || true)
  [ -n "$installed_version" ] && [ "$installed_version" -lt "$SMW_VERSION" ] 2>/dev/null &&
    echo "[setup-memory-workflow] save-session skill is v$installed_version, latest is v$SMW_VERSION — run the setup-memory-workflow skill (or check-drift.sh update) to refresh it."
  return 0
}
case "${1:-}" in
  check) cmd_run check ;;
  update) cmd_run update ;;
  apply) cmd_apply "${2:?Usage: check-drift.sh apply <save-session-skill|save-session-maintenance-skill|mcp-config|hook-config|write-guard-hook|crash-recovery-hook>}" ;;
  drift-warn) cmd_drift_warn ;;
  *) echo "Usage: check-drift.sh <check|update|apply PIECE|drift-warn>" >&2; exit 1 ;;
esac
