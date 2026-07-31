#!/usr/bin/env bash
# check-drift.sh — mechanical checks and safe/idempotent actions for the
# setup-memory-workflow skill. Marker parsing and JSON comparisons are fixed,
# repeatable operations, so they live here instead of as inline bash the model
# re-derives (and can mistype) on every run.
#
# Usage:
#   check-drift.sh check
#     Runs all checks. Items that are always safe to create when missing
#     (project registration, a brand-new save-session skill file, a missing
#     .mcp.json entry, a missing hook) are created directly. Items that
#     already exist but differ from canonical are reported as DRIFT — never
#     overwritten here. Showing the user that diff and asking before
#     overwriting is the model's job, not this script's.
#
#   check-drift.sh apply <save-session-skill|mcp-config|hook-config|sync-memory-skill|sync-memory-script>
#     Overwrites the named piece with the canonical version. Only run this
#     after the user has confirmed they want the drifted item replaced.
#
# Bump SMW_VERSION whenever any canonical asset changes — the three
# __PROJECT__/__SMW_VERSION__-templated assets (assets/*.template) plus
# scripts/sync-memory.py.template — so existing installs get flagged as
# drifted on their next check.

set -euo pipefail

SMW_VERSION=6
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ASSETS_DIR="$SKILL_DIR/assets"

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PROJECT=$(basename "$PROJECT_ROOT")
cd "$PROJECT_ROOT"

render() {
  sed -e "s/__PROJECT__/$PROJECT/g" -e "s/__SMW_VERSION__/$SMW_VERSION/g" "$1"
}

# Checks an installed file that was rendered from a __PROJECT__/__SMW_VERSION__
# template. Reports CREATED (and creates it) if missing, UP-TO-DATE, DRIFT (shows
# current vs. canonical, never overwrites), or NAME-MISMATCH (marker is current but
# the project name in the file doesn't match — likely renamed, never overwrites).
check_templated_file() {
  local installed="$1" template="$2" executable="${3:-no}"
  if [ ! -f "$installed" ]; then
    render "$template" > "$installed"
    [ "$executable" = "yes" ] && chmod +x "$installed"
    echo "CREATED: $installed"
    return
  fi
  local marker name_match
  marker=$(grep -o 'setup-memory-workflow-version:[0-9]*' "$installed" | grep -o '[0-9]*$' || true)
  name_match=$(grep -qF "$PROJECT" "$installed" && echo yes || echo no)
  if [ "$marker" = "$SMW_VERSION" ] && [ "$name_match" = "yes" ]; then
    echo "UP-TO-DATE: $installed"
  elif [ -z "$marker" ] || [ "$marker" -lt "$SMW_VERSION" ]; then
    echo "DRIFT (version ${marker:-none} -> $SMW_VERSION): $installed"
    echo "--- current ---"
    cat "$installed"
    echo "--- canonical ---"
    render "$template"
  else
    echo "NAME-MISMATCH: $installed still refers to a different project name — was this directory renamed?"
  fi
}

# Renders template over an installed file unconditionally — only call after the
# user has confirmed they want a DRIFT or NAME-MISMATCH repaired.
apply_templated_file() {
  local installed="$1" template="$2" executable="${3:-no}"
  render "$template" > "$installed"
  [ "$executable" = "yes" ] && chmod +x "$installed"
  echo "APPLIED: $installed"
}

cmd_check() {
  echo "== basic-memory installed =="
  if ! command -v basic-memory &>/dev/null; then
    echo "MISSING: basic-memory not found — install with 'uv tool install basic-memory', then stop."
    exit 1
  fi
  echo "PASS"

  echo
  echo "== project registration ($PROJECT) =="
  basic-memory project add "$PROJECT" "$HOME/.local/share/basic-memory/$PROJECT"

  mkdir -p .claude/skills/save-session

  echo
  echo "== save-session skill =="
  check_templated_file ".claude/skills/save-session/SKILL.md" "$ASSETS_DIR/save-session-skill.md.template"

  mkdir -p .claude/skills/sync-memory/scripts

  echo
  echo "== sync-memory skill =="
  check_templated_file ".claude/skills/sync-memory/SKILL.md" "$ASSETS_DIR/sync-memory-skill.md.template"

  echo
  echo "== sync-memory script =="
  check_templated_file ".claude/skills/sync-memory/scripts/sync-memory.py" "$SKILL_DIR/scripts/sync-memory.py.template" yes

  echo
  echo "== .mcp.json =="
  local mcp_global_skip=no
  if claude mcp list 2>/dev/null | grep -q "basic-memory"; then
    echo "SKIP: basic-memory already registered globally"
    mcp_global_skip=yes
  else
    [ -f .mcp.json ] || echo '{}' > .mcp.json
    local current canonical
    current=$(jq -c '.mcpServers["basic-memory"] // empty' .mcp.json)
    canonical='{"command":"uvx","args":["--python","3.12","basic-memory","mcp"]}'
    if [ -z "$current" ]; then
      jq '.mcpServers["basic-memory"] = {"command": "uvx", "args": ["--python", "3.12", "basic-memory", "mcp"]}' \
        .mcp.json > .mcp.json.tmp && mv .mcp.json.tmp .mcp.json
      echo "CREATED: basic-memory entry in .mcp.json"
    elif [ "$(echo "$current" | jq -S .)" = "$(echo "$canonical" | jq -S .)" ]; then
      echo "UP-TO-DATE: .mcp.json"
    else
      echo "DRIFT: .mcp.json"
      echo "  current:   $current"
      echo "  canonical: $canonical"
    fi
  fi

  echo
  echo "== UserPromptSubmit hook =="
  [ -f .claude/settings.local.json ] || echo '{}' > .claude/settings.local.json
  local existing_cmd canonical_msg canonical_cmd
  existing_cmd=$(jq -r '[.hooks.UserPromptSubmit[]?.hooks[]?.command // empty] | map(select(contains("basic-memory")))[0] // empty' .claude/settings.local.json)
  canonical_msg=$(render "$ASSETS_DIR/hook-message.txt.template")
  canonical_cmd="echo '${canonical_msg}'"
  if [ -z "$existing_cmd" ]; then
    jq --arg cmd "$canonical_cmd" \
      '.hooks.UserPromptSubmit += [{"matcher": "", "hooks": [{"type": "command", "command": $cmd}]}]' \
      .claude/settings.local.json > .claude/settings.local.json.tmp \
      && mv .claude/settings.local.json.tmp .claude/settings.local.json
    echo "CREATED: hook in .claude/settings.local.json"
  else
    local marker name_match
    marker=$(echo "$existing_cmd" | grep -o 'setup-memory-workflow-version:[0-9]*' | grep -o '[0-9]*$' || true)
    name_match=$(echo "$existing_cmd" | grep -qF "$PROJECT" && echo yes || echo no)
    if [ "$marker" = "$SMW_VERSION" ] && [ "$name_match" = "yes" ]; then
      echo "UP-TO-DATE: hook"
    else
      echo "DRIFT: hook"
      echo "  current:   $existing_cmd"
      echo "  canonical: $canonical_cmd"
    fi
  fi

  echo
  echo "== verification =="
  if [ "$mcp_global_skip" = "yes" ]; then
    echo "SKIP: .mcp.json (basic-memory registered globally, see above)"
  else
    jq '{mcp: .mcpServers["basic-memory"]}' .mcp.json || { echo "ERROR: malformed .mcp.json"; exit 1; }
  fi
  jq '{hook_commands: [.hooks.UserPromptSubmit[]?.hooks[]?.command // ""]}' .claude/settings.local.json || { echo "ERROR: malformed settings.local.json"; exit 1; }
}

cmd_apply() {
  local piece="$1"
  case "$piece" in
    save-session-skill)
      apply_templated_file ".claude/skills/save-session/SKILL.md" "$ASSETS_DIR/save-session-skill.md.template"
      ;;
    sync-memory-skill)
      mkdir -p .claude/skills/sync-memory
      apply_templated_file ".claude/skills/sync-memory/SKILL.md" "$ASSETS_DIR/sync-memory-skill.md.template"
      ;;
    sync-memory-script)
      mkdir -p .claude/skills/sync-memory/scripts
      apply_templated_file ".claude/skills/sync-memory/scripts/sync-memory.py" "$SKILL_DIR/scripts/sync-memory.py.template" yes
      ;;
    mcp-config)
      [ -f .mcp.json ] || echo '{}' > .mcp.json
      jq '.mcpServers["basic-memory"] = {"command": "uvx", "args": ["--python", "3.12", "basic-memory", "mcp"]}' \
        .mcp.json > .mcp.json.tmp && mv .mcp.json.tmp .mcp.json
      echo "APPLIED: .mcp.json"
      ;;
    hook-config)
      local canonical_msg canonical_cmd
      canonical_msg=$(render "$ASSETS_DIR/hook-message.txt.template")
      canonical_cmd="echo '${canonical_msg}'"
      jq --arg cmd "$canonical_cmd" '
        .hooks.UserPromptSubmit |= map(
          .hooks |= map(
            if (.command // "" | contains("basic-memory")) then .command = $cmd else . end
          )
        )
      ' .claude/settings.local.json > .claude/settings.local.json.tmp \
        && mv .claude/settings.local.json.tmp .claude/settings.local.json
      echo "APPLIED: hook in .claude/settings.local.json"
      ;;
    *)
      echo "Unknown piece: $piece (expected save-session-skill|mcp-config|hook-config|sync-memory-skill|sync-memory-script)" >&2
      exit 1
      ;;
  esac
}

case "${1:-}" in
  check) cmd_check ;;
  apply) cmd_apply "${2:?Usage: check-drift.sh apply <save-session-skill|mcp-config|hook-config|sync-memory-skill|sync-memory-script>}" ;;
  *) echo "Usage: check-drift.sh <check|apply PIECE>" >&2; exit 1 ;;
esac
