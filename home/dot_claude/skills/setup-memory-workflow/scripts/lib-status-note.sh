# shellcheck shell=bash
# lib-status-note.sh — sourced by session-reminder.sh. Resolves and reads
# the current-status note: canonical-path-first resolution, Open-section
# excerpt extraction, and bloat detection.
#
# Contract: no arguments, relies on $PROJECT/$HOME already set by the
# caller. Read-only, never errors — degrades to empty/no-op on any missing
# file, directory, or section. Add a CHANGELOG.md entry alongside any new
# or changed function here.

# Excerpt size cap, unchanged from v17 (see CHANGELOG.md).
OPEN_EXCERPT_MAX_LINES=15

# Resolves the on-disk current-status note path for $PROJECT: canonical
# path first (status/$PROJECT-current-status.md), falling back to the
# broader glob — excluding "...Archive...md" siblings — only when absent,
# since an older note may still carry whatever Title Case the model chose
# at creation (e.g. "Chezmoi Current Status.md").
resolve_status_note_path() {
  local status_dir="$HOME/.local/share/basic-memory/$PROJECT/status"
  [ -d "$status_dir" ] || return 0

  local canonical="$status_dir/$PROJECT-current-status.md"
  [ -f "$canonical" ] && { printf '%s\n' "$canonical"; return 0; }

  find "$status_dir" -maxdepth 1 -iname '*current*status*.md' ! -iname '*archive*' 2>/dev/null | head -n1
}

# Whether a resolved path is the canonical one (flags a fallback hit, D4,
# without a global side-channel variable).
status_note_is_canonical() {
  [ "$1" = "$HOME/.local/share/basic-memory/$PROJECT/status/$PROJECT-current-status.md" ]
}

# Bounded, best-effort excerpt of the Open section — a cheap local read,
# never an MCP call. Any missing/unreadable file or absent section means no excerpt.
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
    # Bullets wrap across indented continuation lines, so cut at the last
    # top-level bullet ("- ..." at column 0) that fits the cap, and report
    # remaining bullets, not remaining lines. Falls back to a plain
    # physical-line cut when no bullet markers are found within the cap.
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

# Current-status note bloat: same thresholds as save-session-maintenance's
# own triage (total ≥8,000 chars, ≥200 lines, or any single line ≥800 chars).
check_status_note_bloat() {
  local status_note
  status_note=$(resolve_status_note_path)
  [ -n "$status_note" ] && [ -f "$status_note" ] || return 0

  local total_chars total_lines max_line
  total_chars=$(wc -c <"$status_note" 2>/dev/null | tr -d ' ')
  total_lines=$(wc -l <"$status_note" 2>/dev/null | tr -d ' ')
  max_line=$(awk '{ print length }' "$status_note" 2>/dev/null | sort -rn | head -n1)
  [ -n "$max_line" ] || max_line=0
  if [ "${total_chars:-0}" -ge 8000 ] || [ "${total_lines:-0}" -ge 200 ] || [ "${max_line:-0}" -ge 800 ] 2>/dev/null; then
    echo "[setup-memory-workflow] current-status note looks oversized — run /save-session-maintenance to triage it."
  fi
}
