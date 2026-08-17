#!/usr/bin/env bash
# check-drift.sh — mechanical checks and safe/idempotent actions for the
# setup-memory-workflow skill. Marker parsing, JSON comparisons, and template
# rendering are fixed, repeatable operations, so they live here instead of as
# inline bash the model re-derives (and can mistype) on every run.
#
# Usage:
#   check-drift.sh check
#     Reports status per piece: CREATED (missing pieces are always safe to
#     create and are created directly), UP-TO-DATE, DRIFT (version-only
#     mismatch — the installed piece's project identity is still correct,
#     only its content is stale; safe to repair via `update`), or
#     NAME-MISMATCH (the installed piece's project identity doesn't match
#     current resolution — never auto-repaired by `update`, regardless of
#     version state; requires `apply <piece>` after explicit confirmation).
#
#   check-drift.sh update
#     Unconditionally repairs every piece currently reporting DRIFT — no
#     per-piece confirmation, since version-only drift by definition just
#     means "this should already look like canonical." Never touches a piece
#     reporting NAME-MISMATCH, even if that piece is also version-stale.
#
#   check-drift.sh apply <save-session-skill|mcp-config|hook-config|sync-memory-skill|sync-memory-script>
#     Overwrites the named piece with the canonical version, regardless of
#     its current status. This is the only path that repairs NAME-MISMATCH —
#     only run it after the user has confirmed the identity change shown by
#     `check` is intentional. Showing that diff and getting confirmation is
#     the model's job, not this script's.
#
# $PROJECT resolution (apply-time only — no runtime script ships in any
# installed piece):
#   1. <project-root>/.claude/basic-memory-project.txt, if present and
#      non-blank (a deliberately narrow escape hatch for when a project's
#      basic-memory identity needs to diverge from its directory name)
#   2. basename of `git rev-parse --show-toplevel`
#
# Bump SMW_VERSION whenever any canonical asset changes — the three
# __PROJECT__/__SMW_VERSION__-templated assets (assets/*.template) plus
# scripts/sync-memory.py.template — so existing installs get flagged as
# drifted on their next check. When a change also leaves behind a legacy
# artifact from a prior version (not just new canonical content), add a
# migrate_<piece> cleanup function to migrations.sh and a CHANGELOG.md
# entry — see migrations.sh's header for the contract.

set -euo pipefail

SMW_VERSION=11
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ASSETS_DIR="$SKILL_DIR/assets"

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$PROJECT_ROOT"

# Resolves $PROJECT once, at apply-time. No runtime script — every installed
# piece gets this value baked in via render() below, not re-derived later.
resolve_project() {
  local override_file="$PROJECT_ROOT/.claude/basic-memory-project.txt"
  if [ -f "$override_file" ]; then
    local override
    override=$(tr -d '[:space:]' <"$override_file" 2>/dev/null || true)
    if [ -n "$override" ]; then
      # Print the file's actual (untrimmed-of-internal-content) first line, not
      # the whitespace-stripped value used only to test for blankness above.
      head -n1 "$override_file" | tr -d '\r\n'
      return
    fi
  fi
  basename "$PROJECT_ROOT"
}
PROJECT=$(resolve_project)

render() {
  sed -e "s/__PROJECT__/$PROJECT/g" -e "s/__SMW_VERSION__/$SMW_VERSION/g" "$1"
}

source "$SKILL_DIR/scripts/migrations.sh"

# Cleans up legacy artifacts from prior versions of this skill, unconditionally,
# before any check/update/apply logic runs — see migrations.sh's header for the
# contract.
migrate_hook_config

# ---- templated-file pieces (save-session skill, sync-memory skill+script) ----

# Returns exactly one of CREATED, UP-TO-DATE, DRIFT, NAME-MISMATCH on stdout.
# Performs the CREATE side effect directly when the file is missing (always
# safe — there is nothing to lose). Never overwrites an existing file itself;
# callers decide whether/how to repair DRIFT/NAME-MISMATCH. Identity always
# takes precedence over version: a piece with the wrong project name is
# NAME-MISMATCH even if its version marker is also stale, so `update` can
# never silently re-identity a file while "just" fixing its version.
piece_status() {
  local installed="$1" template="$2" executable="${3:-no}"
  if [ ! -f "$installed" ]; then
    render "$template" > "$installed"
    [ "$executable" = "yes" ] && chmod +x "$installed"
    echo "CREATED"
    return
  fi
  local marker name_match
  marker=$(grep -o 'setup-memory-workflow-version:[0-9]*' "$installed" | grep -o '[0-9]*$' || true)
  name_match=$(grep -qF "$PROJECT" "$installed" && echo yes || echo no)
  if [ "$name_match" = "no" ]; then
    echo "NAME-MISMATCH"
  elif [ "$marker" = "$SMW_VERSION" ]; then
    echo "UP-TO-DATE"
  else
    echo "DRIFT"
  fi
}

# Renders template over an installed file unconditionally — only call after
# confirming a DRIFT or NAME-MISMATCH repair is wanted.
apply_templated_file() {
  local installed="$1" template="$2" executable="${3:-no}"
  render "$template" > "$installed"
  [ "$executable" = "yes" ] && chmod +x "$installed"
  echo "APPLIED: $installed"
}

# Verbose per-piece report used by `check`.
report_templated_piece() {
  local installed="$1" template="$2" executable="${3:-no}"
  local status
  status=$(piece_status "$installed" "$template" "$executable")
  case "$status" in
    CREATED)
      echo "CREATED: $installed"
      ;;
    UP-TO-DATE)
      echo "UP-TO-DATE: $installed"
      ;;
    DRIFT)
      local marker
      marker=$(grep -o 'setup-memory-workflow-version:[0-9]*' "$installed" | grep -o '[0-9]*$' || true)
      echo "DRIFT (version ${marker:-none} -> $SMW_VERSION): $installed"
      echo "  fix with: check-drift.sh update"
      echo "--- current ---"
      cat "$installed"
      echo "--- canonical ---"
      render "$template"
      ;;
    NAME-MISMATCH)
      echo "NAME-MISMATCH: $installed does not refer to \"$PROJECT\" — was this directory renamed, or the override file changed?"
      echo "  never auto-repaired; fix with: check-drift.sh apply <piece>  (only after confirming this is intentional)"
      ;;
  esac
}

# Silent repair used by `update` — acts only on DRIFT, reports and skips
# everything else.
update_templated_piece() {
  local piece_name="$1" installed="$2" template="$3" executable="${4:-no}"
  local status
  status=$(piece_status "$installed" "$template" "$executable")
  case "$status" in
    DRIFT)
      apply_templated_file "$installed" "$template" "$executable"
      ;;
    NAME-MISMATCH)
      echo "SKIPPED (NAME-MISMATCH — use 'apply $piece_name' after confirming): $installed"
      ;;
    CREATED)
      echo "CREATED: $installed"
      ;;
    UP-TO-DATE) ;; # nothing to report
  esac
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
  report_templated_piece ".claude/skills/save-session/SKILL.md" "$ASSETS_DIR/save-session-skill.md.template"

  mkdir -p .claude/skills/sync-memory/scripts

  echo
  echo "== sync-memory skill =="
  report_templated_piece ".claude/skills/sync-memory/SKILL.md" "$ASSETS_DIR/sync-memory-skill.md.template"

  echo
  echo "== sync-memory script =="
  report_templated_piece ".claude/skills/sync-memory/scripts/sync-memory.py" "$SKILL_DIR/scripts/sync-memory.py.template" yes

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
      echo "  fix with: check-drift.sh update"
      echo "  current:   $current"
      echo "  canonical: $canonical"
    fi
  fi

  echo
  echo "== SessionStart hook =="
  [ -f .claude/settings.local.json ] || echo '{}' > .claude/settings.local.json
  local existing_cmd canonical_msg canonical_cmd
  existing_cmd=$(jq -r '[.hooks.SessionStart[]?.hooks[]?.command // empty] | map(select(contains("basic-memory")))[0] // empty' .claude/settings.local.json)
  canonical_msg=$(render "$ASSETS_DIR/hook-message.txt.template")
  canonical_cmd="echo '${canonical_msg}'"
  if [ -z "$existing_cmd" ]; then
    jq --arg cmd "$canonical_cmd" \
      '.hooks.SessionStart += [{"matcher": "", "hooks": [{"type": "command", "command": $cmd}]}]' \
      .claude/settings.local.json > .claude/settings.local.json.tmp \
      && mv .claude/settings.local.json.tmp .claude/settings.local.json
    echo "CREATED: hook in .claude/settings.local.json"
  else
    local name_match
    name_match=$(echo "$existing_cmd" | grep -qF "$PROJECT" && echo yes || echo no)
    if [ "$name_match" = "no" ]; then
      echo "NAME-MISMATCH: hook does not refer to \"$PROJECT\" — was this directory renamed, or the override file changed?"
      echo "  never auto-repaired; fix with: check-drift.sh apply hook-config  (only after confirming this is intentional)"
    elif [ "$existing_cmd" = "$canonical_cmd" ]; then
      echo "UP-TO-DATE: hook"
    else
      echo "DRIFT: hook"
      echo "  fix with: check-drift.sh update"
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
  jq '{hook_commands: [.hooks.SessionStart[]?.hooks[]?.command // ""]}' .claude/settings.local.json || { echo "ERROR: malformed settings.local.json"; exit 1; }
}

cmd_update() {
  mkdir -p .claude/skills/save-session .claude/skills/sync-memory/scripts

  echo "== save-session skill =="
  update_templated_piece "save-session-skill" ".claude/skills/save-session/SKILL.md" "$ASSETS_DIR/save-session-skill.md.template"

  echo
  echo "== sync-memory skill =="
  update_templated_piece "sync-memory-skill" ".claude/skills/sync-memory/SKILL.md" "$ASSETS_DIR/sync-memory-skill.md.template"

  echo
  echo "== sync-memory script =="
  update_templated_piece "sync-memory-script" ".claude/skills/sync-memory/scripts/sync-memory.py" "$SKILL_DIR/scripts/sync-memory.py.template" yes

  echo
  echo "== .mcp.json =="
  if claude mcp list 2>/dev/null | grep -q "basic-memory"; then
    echo "SKIP: basic-memory already registered globally"
  else
    [ -f .mcp.json ] || echo '{}' > .mcp.json
    local current canonical
    current=$(jq -c '.mcpServers["basic-memory"] // empty' .mcp.json)
    canonical='{"command":"uvx","args":["--python","3.12","basic-memory","mcp"]}'
    if [ -z "$current" ] || [ "$(echo "$current" | jq -S .)" != "$(echo "$canonical" | jq -S .)" ]; then
      jq '.mcpServers["basic-memory"] = {"command": "uvx", "args": ["--python", "3.12", "basic-memory", "mcp"]}' \
        .mcp.json > .mcp.json.tmp && mv .mcp.json.tmp .mcp.json
      echo "APPLIED: .mcp.json"
    else
      echo "UP-TO-DATE: .mcp.json"
    fi
  fi

  echo
  echo "== SessionStart hook =="
  [ -f .claude/settings.local.json ] || echo '{}' > .claude/settings.local.json
  local existing_cmd canonical_msg canonical_cmd
  existing_cmd=$(jq -r '[.hooks.SessionStart[]?.hooks[]?.command // empty] | map(select(contains("basic-memory")))[0] // empty' .claude/settings.local.json)
  canonical_msg=$(render "$ASSETS_DIR/hook-message.txt.template")
  canonical_cmd="echo '${canonical_msg}'"
  if [ -z "$existing_cmd" ]; then
    jq --arg cmd "$canonical_cmd" \
      '.hooks.SessionStart += [{"matcher": "", "hooks": [{"type": "command", "command": $cmd}]}]' \
      .claude/settings.local.json > .claude/settings.local.json.tmp \
      && mv .claude/settings.local.json.tmp .claude/settings.local.json
    echo "CREATED: hook in .claude/settings.local.json"
  else
    local name_match
    name_match=$(echo "$existing_cmd" | grep -qF "$PROJECT" && echo yes || echo no)
    if [ "$name_match" = "no" ]; then
      echo "SKIPPED (NAME-MISMATCH — use 'apply hook-config' after confirming): hook"
    elif [ "$existing_cmd" != "$canonical_cmd" ]; then
      jq --arg cmd "$canonical_cmd" '
        .hooks.SessionStart |= map(
          .hooks |= map(
            if (.command // "" | contains("basic-memory")) then .command = $cmd else . end
          )
        )
      ' .claude/settings.local.json > .claude/settings.local.json.tmp \
        && mv .claude/settings.local.json.tmp .claude/settings.local.json
      echo "APPLIED: hook in .claude/settings.local.json"
    fi
  fi
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
        .hooks.SessionStart |= map(
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
  update) cmd_update ;;
  apply) cmd_apply "${2:?Usage: check-drift.sh apply <save-session-skill|mcp-config|hook-config|sync-memory-skill|sync-memory-script>}" ;;
  *) echo "Usage: check-drift.sh <check|update|apply PIECE>" >&2; exit 1 ;;
esac
