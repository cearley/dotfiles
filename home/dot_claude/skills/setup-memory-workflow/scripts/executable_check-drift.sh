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
#   check-drift.sh apply <save-session-skill|save-session-maintenance-skill|mcp-config|hook-config|write-guard-hook|crash-recovery-hook>
#     Overwrites the named piece with the canonical version, regardless of
#     its current status. This is the only path that repairs NAME-MISMATCH —
#     only run it after the user has confirmed the identity change shown by
#     `check` is intentional. Showing that diff and getting confirmation is
#     the model's job, not this script's.
#
#   check-drift.sh drift-warn
#     Silent and fast: prints exactly one line if the installed save-session
#     skill is older than this (globally-installed) script's own
#     SMW_VERSION, otherwise prints nothing. Invoked automatically from the
#     rendered SessionStart hook command itself (see canonical_hook_cmd())
#     so staleness surfaces without anyone having to remember to re-run
#     `check`. Never errors the hook: callers should still redirect stderr
#     and tolerate a non-zero exit.
#
# $PROJECT resolution (apply-time only — no runtime script ships in any
# installed piece):
#   1. <project-root>/.claude/basic-memory-project.txt, if present and
#      non-blank (a deliberately narrow escape hatch for when a project's
#      basic-memory identity needs to diverge from its directory name)
#   2. basename of `git rev-parse --show-toplevel`
#
# Bump SMW_VERSION whenever any canonical asset changes — the two
# __PROJECT__/__SMW_VERSION__-templated assets (assets/*.template) — so
# existing installs get flagged as drifted on their next check. When a
# change also leaves behind a legacy
# artifact from a prior version (not just new canonical content), add a
# migrate_<piece> cleanup function to migrations.sh and a CHANGELOG.md
# entry — see migrations.sh's header for the contract.

set -euo pipefail

SMW_VERSION=17
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ASSETS_DIR="$SKILL_DIR/assets"
OPEN_EXCERPT_MAX_LINES=15

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

# Resolves the on-disk current-status note path for $PROJECT by globbing the
# status/ directory, since the literal filename is whatever Title Case the
# note's title happened to be when created (e.g. "Chezmoi Current Status.md",
# "herdr Current Status.md") — basic-memory's MCP permalink convention
# ($PROJECT/status/$PROJECT-current-status) resolves server-side and gives no
# guarantee about the on-disk filename, which this script has no MCP access
# to resolve any other way. Excludes "...Archive...md" siblings. Degrades to
# empty (no error) when the status directory is missing or nothing matches,
# consistent with every other fallback in this script.
resolve_status_note_path() {
  local status_dir="$HOME/.local/share/basic-memory/$PROJECT/status"
  [ -d "$status_dir" ] || return 0
  find "$status_dir" -maxdepth 1 -iname '*current*status*.md' ! -iname '*archive*' 2>/dev/null | head -n1
}

# Bounded, best-effort excerpt of the current-status note's Open section, for
# baking into the SessionStart reminder at render time (see canonical_hook_cmd()
# below). A cheap local file read, not an MCP call — never fails loudly: any
# missing file, unreadable file, or absent "## Open" section just means no
# excerpt (empty stdout), so callers always get a usable render() either way.
extract_open_excerpt() {
  local note
  note=$(resolve_status_note_path)
  [ -n "$note" ] && [ -r "$note" ] || return 0

  local lines
  lines=$(awk '
    /^## Open[[:space:]]*$/ { found=1; next }
    found && /^##/ { exit }
    found && NF { print }
  ' "$note" 2>/dev/null) || true
  [ -n "$lines" ] || return 0

  local total_lines
  total_lines=$(printf '%s\n' "$lines" | wc -l | tr -d ' ')
  if [ "$total_lines" -gt "$OPEN_EXCERPT_MAX_LINES" ]; then
    # Real Open-section bullets routinely wrap across indented continuation
    # lines, so a plain physical-line cut can land mid-entry. Prefer cutting
    # at the end of the last top-level bullet ("- ..." at column 0) that
    # fully fits within the cap, and report remaining *bullets*, not
    # remaining physical lines. Falls back to the old physical-line cut when
    # the content has no detectable bullet markers, or when even the first
    # bullet alone overruns the cap (nothing to cut at).
    local bullet_starts=()
    while IFS= read -r ln; do
      bullet_starts+=("$ln")
    done < <(printf '%s\n' "$lines" | grep -n '^- ' | cut -d: -f1 || true)

    local cut_line=0 i boundary
    for ((i = 1; i < ${#bullet_starts[@]}; i++)); do
      boundary=$((bullet_starts[i] - 1))
      [ "$boundary" -le "$OPEN_EXCERPT_MAX_LINES" ] && cut_line=$boundary
    done

    local shown remaining
    if [ "$cut_line" -gt 0 ]; then
      shown=$(printf '%s\n' "$lines" | head -n "$cut_line")
      remaining=0
      for ln in "${bullet_starts[@]}"; do
        [ "$ln" -gt "$cut_line" ] && remaining=$((remaining + 1))
      done
    else
      shown=$(printf '%s\n' "$lines" | head -n "$OPEN_EXCERPT_MAX_LINES")
      remaining=$((total_lines - OPEN_EXCERPT_MAX_LINES))
    fi
    printf '%s\n... (%d more open items — see the status note)\n' "$shown" "$remaining"
  else
    printf '%s\n' "$lines"
  fi
}

# Bash-native substring substitution, not sed: __OPEN_EXCERPT__ can expand to
# multi-line content, and sed's s///g has no clean way to splice a replacement
# string containing literal newlines.
#
# __OPEN_EXCERPT__ sits at the very end of hook-message.txt.template's single
# line, with no template-literal newline of its own around it — when
# extract_open_excerpt() has nothing, the substitution is empty and the
# rendered message is byte-identical to the no-excerpt message. When it has
# something, the leading "\n" below is what makes the excerpt its own line(s)
# rather than text glued onto the end of the reminder sentence.
render() {
  local content open_excerpt open_excerpt_block
  content=$(cat "$1")
  open_excerpt=$(extract_open_excerpt)
  open_excerpt_block=""
  if [ -n "$open_excerpt" ]; then
    open_excerpt_block=$(printf '\nOpen items from the status note (may be stale — call search_notes/recent_activity for the latest):\n%s' "$open_excerpt")
  fi
  content=${content//__PROJECT__/$PROJECT}
  content=${content//__SMW_VERSION__/$SMW_VERSION}
  content=${content//__OPEN_EXCERPT__/$open_excerpt_block}
  printf '%s\n' "$content"
}

# The canonical SessionStart hook command: the rendered reminder message,
# followed by a silent, best-effort call back into this same (globally
# installed) script to print a one-line staleness warning if needed. The
# `|| true` and stderr redirect mean a missing/broken check-drift.sh on some
# future machine can never break the primary reminder.
canonical_hook_cmd() {
  local canonical_msg canonical_msg_escaped
  canonical_msg=$(render "$ASSETS_DIR/hook-message.txt.template")
  # canonical_msg can contain free text from the status note's Open section
  # (apostrophes are routine — "doesn't", "machine's", ...), and it's spliced
  # into a single-quoted `echo '...'` below. Escape each embedded single
  # quote via the standard POSIX technique (close-quote, escaped literal
  # quote, reopen-quote) so it can't terminate that string early.
  canonical_msg_escaped=${canonical_msg//\'/\'\\\'\'}
  echo "echo '${canonical_msg_escaped}'; \"\${CLAUDE_CONFIG_DIR:-\$HOME/.claude}/skills/setup-memory-workflow/scripts/check-drift.sh\" drift-warn 2>/dev/null || true"
}

# The canonical PreToolUse write-guard hook command: always the same global,
# non-templated script path (see scripts/executable_basic-memory-write-guard.sh) —
# the guard targets the whole ~/.local/share/basic-memory/ tree, not a per-project
# path, so unlike canonical_hook_cmd() above there is no $PROJECT substitution here.
canonical_write_guard_cmd() {
  echo "\${CLAUDE_CONFIG_DIR:-\$HOME/.claude}/skills/setup-memory-workflow/scripts/basic-memory-write-guard.sh"
}

# The canonical crash-recovery-hook SessionStart command: same shape as
# canonical_write_guard_cmd() above — a fixed, non-templated global script path, no
# $PROJECT substitution, since the script only reads session_id/transcript_path/cwd
# from hook stdin and compares local file mtimes.
canonical_crash_recovery_cmd() {
  echo "\${CLAUDE_CONFIG_DIR:-\$HOME/.claude}/skills/setup-memory-workflow/scripts/crash-recovery-hook.sh"
}

# shellcheck source=home/dot_claude/skills/setup-memory-workflow/scripts/migrations.sh
source "$SKILL_DIR/scripts/migrations.sh"

# Cleans up legacy artifacts from prior versions of this skill, unconditionally,
# before any check/update/apply logic runs — see migrations.sh's header for the
# contract.
migrate_hook_config
migrate_sync_memory

# ---- templated-file pieces (save-session skill) ----

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

  mkdir -p .claude/skills/save-session-maintenance

  echo
  echo "== save-session-maintenance skill =="
  report_templated_piece ".claude/skills/save-session-maintenance/SKILL.md" "$ASSETS_DIR/save-session-maintenance-skill.md.template"

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
  local existing_cmd canonical_cmd
  existing_cmd=$(jq -r '[.hooks.SessionStart[]?.hooks[]?.command // empty] | map(select(contains("basic-memory")))[0] // empty' .claude/settings.local.json)
  canonical_cmd=$(canonical_hook_cmd)
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
  echo "== PreToolUse write-guard hook =="
  local existing_guard_cmd canonical_guard_cmd
  existing_guard_cmd=$(jq -r '[.hooks.PreToolUse[]?.hooks[]?.command // empty] | map(select(contains("basic-memory-write-guard")))[0] // empty' .claude/settings.local.json)
  canonical_guard_cmd=$(canonical_write_guard_cmd)
  if [ -z "$existing_guard_cmd" ]; then
    jq --arg cmd "$canonical_guard_cmd" \
      '.hooks.PreToolUse += [{"matcher": "Bash|Edit|Write", "hooks": [{"type": "command", "command": $cmd}]}]' \
      .claude/settings.local.json > .claude/settings.local.json.tmp \
      && mv .claude/settings.local.json.tmp .claude/settings.local.json
    echo "CREATED: write-guard hook in .claude/settings.local.json"
  elif [ "$existing_guard_cmd" = "$canonical_guard_cmd" ]; then
    echo "UP-TO-DATE: write-guard hook"
  else
    echo "DRIFT: write-guard hook"
    echo "  fix with: check-drift.sh update"
    echo "  current:   $existing_guard_cmd"
    echo "  canonical: $canonical_guard_cmd"
  fi

  echo
  echo "== crash-recovery hook =="
  local existing_crash_cmd canonical_crash_cmd
  existing_crash_cmd=$(jq -r '[.hooks.SessionStart[]?.hooks[]?.command // empty] | map(select(contains("crash-recovery-hook.sh")))[0] // empty' .claude/settings.local.json)
  canonical_crash_cmd=$(canonical_crash_recovery_cmd)
  if [ -z "$existing_crash_cmd" ]; then
    jq --arg cmd "$canonical_crash_cmd" \
      '.hooks.SessionStart += [{"matcher": "", "hooks": [{"type": "command", "command": $cmd}]}]' \
      .claude/settings.local.json > .claude/settings.local.json.tmp \
      && mv .claude/settings.local.json.tmp .claude/settings.local.json
    echo "CREATED: crash-recovery hook in .claude/settings.local.json"
  elif [ "$existing_crash_cmd" = "$canonical_crash_cmd" ]; then
    echo "UP-TO-DATE: crash-recovery hook"
  else
    echo "DRIFT: crash-recovery hook"
    echo "  fix with: check-drift.sh update"
    echo "  current:   $existing_crash_cmd"
    echo "  canonical: $canonical_crash_cmd"
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
  mkdir -p .claude/skills/save-session .claude/skills/save-session-maintenance

  echo "== save-session skill =="
  update_templated_piece "save-session-skill" ".claude/skills/save-session/SKILL.md" "$ASSETS_DIR/save-session-skill.md.template"

  echo
  echo "== save-session-maintenance skill =="
  update_templated_piece "save-session-maintenance-skill" ".claude/skills/save-session-maintenance/SKILL.md" "$ASSETS_DIR/save-session-maintenance-skill.md.template"

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
  local existing_cmd canonical_cmd
  existing_cmd=$(jq -r '[.hooks.SessionStart[]?.hooks[]?.command // empty] | map(select(contains("basic-memory")))[0] // empty' .claude/settings.local.json)
  canonical_cmd=$(canonical_hook_cmd)
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

  echo
  echo "== PreToolUse write-guard hook =="
  local existing_guard_cmd canonical_guard_cmd
  existing_guard_cmd=$(jq -r '[.hooks.PreToolUse[]?.hooks[]?.command // empty] | map(select(contains("basic-memory-write-guard")))[0] // empty' .claude/settings.local.json)
  canonical_guard_cmd=$(canonical_write_guard_cmd)
  if [ -z "$existing_guard_cmd" ]; then
    jq --arg cmd "$canonical_guard_cmd" \
      '.hooks.PreToolUse += [{"matcher": "Bash|Edit|Write", "hooks": [{"type": "command", "command": $cmd}]}]' \
      .claude/settings.local.json > .claude/settings.local.json.tmp \
      && mv .claude/settings.local.json.tmp .claude/settings.local.json
    echo "CREATED: write-guard hook in .claude/settings.local.json"
  elif [ "$existing_guard_cmd" != "$canonical_guard_cmd" ]; then
    jq --arg cmd "$canonical_guard_cmd" '
      .hooks.PreToolUse |= map(
        .hooks |= map(
          if (.command // "" | contains("basic-memory-write-guard")) then .command = $cmd else . end
        )
      )
    ' .claude/settings.local.json > .claude/settings.local.json.tmp \
      && mv .claude/settings.local.json.tmp .claude/settings.local.json
    echo "APPLIED: write-guard hook in .claude/settings.local.json"
  fi

  echo
  echo "== crash-recovery hook =="
  local existing_crash_cmd canonical_crash_cmd
  existing_crash_cmd=$(jq -r '[.hooks.SessionStart[]?.hooks[]?.command // empty] | map(select(contains("crash-recovery-hook.sh")))[0] // empty' .claude/settings.local.json)
  canonical_crash_cmd=$(canonical_crash_recovery_cmd)
  if [ -z "$existing_crash_cmd" ]; then
    jq --arg cmd "$canonical_crash_cmd" \
      '.hooks.SessionStart += [{"matcher": "", "hooks": [{"type": "command", "command": $cmd}]}]' \
      .claude/settings.local.json > .claude/settings.local.json.tmp \
      && mv .claude/settings.local.json.tmp .claude/settings.local.json
    echo "CREATED: crash-recovery hook in .claude/settings.local.json"
  elif [ "$existing_crash_cmd" != "$canonical_crash_cmd" ]; then
    jq --arg cmd "$canonical_crash_cmd" '
      .hooks.SessionStart |= map(
        .hooks |= map(
          if (.command // "" | contains("crash-recovery-hook.sh")) then .command = $cmd else . end
        )
      )
    ' .claude/settings.local.json > .claude/settings.local.json.tmp \
      && mv .claude/settings.local.json.tmp .claude/settings.local.json
    echo "APPLIED: crash-recovery hook in .claude/settings.local.json"
  fi
}

cmd_apply() {
  local piece="$1"
  case "$piece" in
    save-session-skill)
      apply_templated_file ".claude/skills/save-session/SKILL.md" "$ASSETS_DIR/save-session-skill.md.template"
      ;;
    save-session-maintenance-skill)
      mkdir -p .claude/skills/save-session-maintenance
      apply_templated_file ".claude/skills/save-session-maintenance/SKILL.md" "$ASSETS_DIR/save-session-maintenance-skill.md.template"
      ;;
    mcp-config)
      [ -f .mcp.json ] || echo '{}' > .mcp.json
      jq '.mcpServers["basic-memory"] = {"command": "uvx", "args": ["--python", "3.12", "basic-memory", "mcp"]}' \
        .mcp.json > .mcp.json.tmp && mv .mcp.json.tmp .mcp.json
      echo "APPLIED: .mcp.json"
      ;;
    hook-config)
      local canonical_cmd
      canonical_cmd=$(canonical_hook_cmd)
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
    write-guard-hook)
      local canonical_guard_cmd
      canonical_guard_cmd=$(canonical_write_guard_cmd)
      [ -f .claude/settings.local.json ] || echo '{}' > .claude/settings.local.json
      if jq -e '[.hooks.PreToolUse[]?.hooks[]?.command // empty] | map(select(contains("basic-memory-write-guard"))) | length > 0' .claude/settings.local.json >/dev/null 2>&1; then
        jq --arg cmd "$canonical_guard_cmd" '
          .hooks.PreToolUse |= map(
            .hooks |= map(
              if (.command // "" | contains("basic-memory-write-guard")) then .command = $cmd else . end
            )
          )
        ' .claude/settings.local.json > .claude/settings.local.json.tmp \
          && mv .claude/settings.local.json.tmp .claude/settings.local.json
      else
        jq --arg cmd "$canonical_guard_cmd" \
          '.hooks.PreToolUse += [{"matcher": "Bash|Edit|Write", "hooks": [{"type": "command", "command": $cmd}]}]' \
          .claude/settings.local.json > .claude/settings.local.json.tmp \
          && mv .claude/settings.local.json.tmp .claude/settings.local.json
      fi
      echo "APPLIED: write-guard hook in .claude/settings.local.json"
      ;;
    crash-recovery-hook)
      local canonical_crash_cmd
      canonical_crash_cmd=$(canonical_crash_recovery_cmd)
      [ -f .claude/settings.local.json ] || echo '{}' > .claude/settings.local.json
      if jq -e '[.hooks.SessionStart[]?.hooks[]?.command // empty] | map(select(contains("crash-recovery-hook.sh"))) | length > 0' .claude/settings.local.json >/dev/null 2>&1; then
        jq --arg cmd "$canonical_crash_cmd" '
          .hooks.SessionStart |= map(
            .hooks |= map(
              if (.command // "" | contains("crash-recovery-hook.sh")) then .command = $cmd else . end
            )
          )
        ' .claude/settings.local.json > .claude/settings.local.json.tmp \
          && mv .claude/settings.local.json.tmp .claude/settings.local.json
      else
        jq --arg cmd "$canonical_crash_cmd" \
          '.hooks.SessionStart += [{"matcher": "", "hooks": [{"type": "command", "command": $cmd}]}]' \
          .claude/settings.local.json > .claude/settings.local.json.tmp \
          && mv .claude/settings.local.json.tmp .claude/settings.local.json
      fi
      echo "APPLIED: crash-recovery hook in .claude/settings.local.json"
      ;;
    *)
      echo "Unknown piece: $piece (expected save-session-skill|save-session-maintenance-skill|mcp-config|hook-config|write-guard-hook|crash-recovery-hook)" >&2
      exit 1
      ;;
  esac
}

cmd_drift_warn() {
  local file=".claude/skills/save-session/SKILL.md" installed_version
  if [ -f "$file" ]; then
    installed_version=$(grep -o 'setup-memory-workflow-version:[0-9]*' "$file" 2>/dev/null | grep -o '[0-9]*$' || true)
    if [ -n "$installed_version" ] && [ "$installed_version" -lt "$SMW_VERSION" ] 2>/dev/null; then
      echo "[setup-memory-workflow] save-session skill is v$installed_version, latest is v$SMW_VERSION — run the setup-memory-workflow skill (or check-drift.sh update) to refresh it."
    fi
  fi

  # Independent signal: current-status note bloat (same thresholds as
  # save-session-maintenance's own triage, reusing the already-resolved
  # $PROJECT — see resolve_project() above, not re-derived here).
  local status_note
  status_note=$(resolve_status_note_path)
  if [ -n "$status_note" ] && [ -f "$status_note" ]; then
    local total_chars total_lines max_line
    total_chars=$(wc -c <"$status_note" 2>/dev/null | tr -d ' ')
    total_lines=$(wc -l <"$status_note" 2>/dev/null | tr -d ' ')
    max_line=$(awk '{ print length }' "$status_note" 2>/dev/null | sort -rn | head -n1)
    [ -n "$max_line" ] || max_line=0
    if [ "${total_chars:-0}" -ge 8000 ] || [ "${total_lines:-0}" -ge 200 ] || [ "${max_line:-0}" -ge 800 ] 2>/dev/null; then
      echo "[setup-memory-workflow] current-status note looks oversized — run /save-session-maintenance to triage it."
    fi
  fi

  return 0
}

case "${1:-}" in
  check) cmd_check ;;
  update) cmd_update ;;
  apply) cmd_apply "${2:?Usage: check-drift.sh apply <save-session-skill|save-session-maintenance-skill|mcp-config|hook-config|write-guard-hook|crash-recovery-hook>}" ;;
  drift-warn) cmd_drift_warn ;;
  *) echo "Usage: check-drift.sh <check|update|apply PIECE|drift-warn>" >&2; exit 1 ;;
esac
