# shellcheck shell=bash
# lib-open-items.sh — sourced by session-reminder.sh after lib-status-note.sh.
# Detects when the status note's Open section has grown past a live-item cap.
#
# Contract: no arguments, relies on $PROJECT/$HOME already set by the
# caller, and on resolve_status_note_path() from lib-status-note.sh already
# being sourced. Read-only, never errors — degrades to no-op on any missing
# file or section. Add a CHANGELOG.md entry alongside any new or changed
# function here.

# Open-section live-item cap: past this many "- " bullets, the section is
# growing unboundedly and stale items should be rolled into the index.
OPEN_LINE_CAP=15

# Open-section overflow signal: counts top-level bullets in the Open
# section (same awk extraction as extract_open_excerpt()) and warns only
# when that count exceeds OPEN_LINE_CAP. No-op if no status note, or no
# Open section, resolves.
check_open_section_overflow() {
    local note
    note=$(resolve_status_note_path)
    [ -n "$note" ] && [ -r "$note" ] || return 0

    local count
    count=$(awk '
    /^## Open[[:space:]]*$/ { found=1; next }
    found && /^##/ { exit }
    found && /^- / { n++ }
    END { print n + 0 }
  ' "$note" 2>/dev/null) || true
    [ -n "$count" ] || return 0

    if [ "$count" -gt "$OPEN_LINE_CAP" ] 2>/dev/null; then
        echo "[setup-memory-workflow] Open section has $count live items (cap $OPEN_LINE_CAP) — run /save-session-maintenance to roll stale items into the index."
    fi
}
