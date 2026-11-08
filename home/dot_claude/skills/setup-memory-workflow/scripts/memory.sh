# shellcheck shell=bash
# memory.sh — reads live basic-memory note content for this skill.
#
# Sourced by check-drift.sh; never run standalone (no shebang, not chmod +x).
#
# Contract for every function here:
#   - No arguments. Relies on $PROJECT and $HOME already being set by the
#     sourcing script (check-drift.sh resolves $PROJECT via resolve_project()
#     before sourcing this file).
#   - Read-only: never creates, writes, or deletes anything. This is the
#     opposite concern from migrations.sh (which only ever mutates this
#     skill's own prior-version artifacts) and from check-drift.sh itself
#     (which renders and installs canonical template content) — this file
#     only ever reads a user's evolving basic-memory note content.
#   - Degrades to empty/no-op on any missing file or directory. Never
#     errors: a missing or unreadable note just means no signal, consistent
#     with every other fallback in check-drift.sh.
#
# Add a CHANGELOG.md entry alongside any new or changed function here.

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
# in check-drift.sh). A cheap local file read, not an MCP call — never fails
# loudly: any missing file, unreadable file, or absent "## Open" section just
# means no excerpt (empty stdout), so callers always get a usable render()
# either way.
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

# Independent signal: current-status note bloat (same thresholds as
# save-session-maintenance's own triage). Prints the oversized-note line, or
# nothing, consistent with every other check in this file. Degrades silently
# when the note doesn't exist yet.
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

# Resolves the active session-log note as the most recently modified file
# under the project's sessions/ directory — identification by file recency,
# not by re-parsing the current-status note's wikilinks (see design.md for
# why: that resolution is model-interpreted prose with no bash equivalent,
# and save-session always appends to the active log on every run, so the
# most-recently-modified file in sessions/ is reliably the active one in
# practice). Degrades to empty (no error) when the sessions directory is
# missing or contains no notes, consistent with every other fallback here.
resolve_active_session_log_path() {
  local sessions_dir="$HOME/.local/share/basic-memory/$PROJECT/sessions"
  [ -d "$sessions_dir" ] || return 0

  # Plain glob + stat, not `find -printf`: -printf is a GNU find extension
  # that macOS's BSD find rejects outright, which would otherwise silently
  # produce no signal at all on this skill's primary platform (see the
  # stat -f/-c fallback precedent in crash-recovery-hook.sh).
  local latest="" latest_mtime=0 f mtime
  for f in "$sessions_dir"/*.md; do
    [ -f "$f" ] || continue
    mtime=$(stat -f '%m' "$f" 2>/dev/null || stat -c '%Y' "$f" 2>/dev/null || echo 0)
    if [ "$mtime" -gt "$latest_mtime" ]; then
      latest_mtime=$mtime
      latest=$f
    fi
  done
  [ -n "$latest" ] && printf '%s\n' "$latest"
}

# Independent signal: active session-log bloat, same 300-line rollover
# threshold save-session-maintenance-skill.md.template documents. Prints the
# oversized-log line, or nothing. Degrades silently when no session log
# exists yet.
check_session_log_bloat() {
  local log_note
  log_note=$(resolve_active_session_log_path)
  [ -n "$log_note" ] && [ -f "$log_note" ] || return 0

  local total_lines
  total_lines=$(wc -l <"$log_note" 2>/dev/null | tr -d ' ')
  if [ "${total_lines:-0}" -ge 300 ] 2>/dev/null; then
    echo "[setup-memory-workflow] active session log looks oversized — run /save-session-maintenance to roll it over."
  fi
}
