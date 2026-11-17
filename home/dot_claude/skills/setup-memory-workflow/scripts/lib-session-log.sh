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

# Resolves the active session-log note by file recency (most recently
# modified under sessions/), not by re-parsing the status note's wikilinks —
# that's model-interpreted prose with no bash equivalent, and save-session
# always appends to the active log every run, so recency is reliable in
# practice. Degrades to empty when sessions/ is missing or empty.
resolve_active_session_log_path() {
    local sessions_dir="$HOME/.local/share/basic-memory/$PROJECT/sessions"
    [ -d "$sessions_dir" ] || return 0

    # Plain glob + stat, not `find -printf` (a GNU extension macOS's BSD
    # find rejects outright) — same stat -f/-c fallback as crash-recovery-hook.sh.
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

# Active-log bloat signal: same 300-line rollover threshold
# save-session-maintenance-skill.md.template documents. No-op if no log exists.
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
