# shellcheck shell=bash
# lib-session-log.sh — sourced by session-reminder.sh. Resolves the active
# session-log note and checks it for rollover bloat.
#
# Contract for every function here: no arguments, relies on $PROJECT/$HOME
# already being set by the caller. Read-only — never creates, writes, or
# deletes anything. Degrades to empty/no-op on any missing file or
# directory. Never errors.
#
# Add a CHANGELOG.md entry alongside any new or changed function here.

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
