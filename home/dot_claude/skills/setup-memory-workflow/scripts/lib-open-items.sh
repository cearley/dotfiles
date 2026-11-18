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

# Session-count staleness threshold: an open-item note whose
# last_touched_session is this many (or more) status-note sessions in the
# past is stale and should be rolled into the index.
STALE_SESSION_THRESHOLD=5

# Open-section overflow signal: counts top-level bullets in the Open
# section (same awk extraction as extract_open_excerpt()) and warns only
# when that count exceeds OPEN_LINE_CAP. No-op if no status note, or no
# Open section, resolves. Legacy bullets (no "[[Open: " pointer, predating
# this feature) are counted separately from pointer bullets, because the
# maintenance rollup can only ever roll up pointer-ized items — on a
# project where legacy bullets dominate the overflow, the rollup can't
# clear the warning, so the message must point at legacy conversion
# instead of promising a rollup fix.
check_open_section_overflow() {
    local note
    note=$(resolve_status_note_path)
    [ -n "$note" ] && [ -r "$note" ] || return 0

    local counts legacy pointer count
    counts=$(awk '
    /^## Open[[:space:]]*$/ { found=1; next }
    found && /^##/ { exit }
    found && /^- / { if ($0 ~ /\[\[Open: /) p++; else l++ }
    END { print (l + 0) "\t" (p + 0) }
  ' "$note" 2>/dev/null) || true
    [ -n "$counts" ] || return 0

    legacy=$(printf '%s' "$counts" | cut -f1)
    pointer=$(printf '%s' "$counts" | cut -f2)
    count=$((legacy + pointer))

    if [ "$count" -gt "$OPEN_LINE_CAP" ] 2>/dev/null; then
        if [ "$legacy" -ge "$pointer" ]; then
            echo "[setup-memory-workflow] Open section has $count live items (cap $OPEN_LINE_CAP), mostly legacy bullets without an [[Open: ]] pointer — /save-session-maintenance's rollup can't touch those; use its on-request legacy-conversion path to pointer-ize them first."
        else
            echo "[setup-memory-workflow] Open section has $count live items (cap $OPEN_LINE_CAP) — run /save-session-maintenance to roll stale items into the index."
        fi
    fi
}

# Resolves the on-disk open-items directory for $PROJECT. Prints nothing if
# it doesn't exist (no items have ever been created).
resolve_open_items_dir() {
    local dir="$HOME/.local/share/basic-memory/$PROJECT/open-items"
    [ -d "$dir" ] || return 0
    printf '%s\n' "$dir"
}

# Session-count staleness: for every open-items/*.md note with
# "status: open", counts how many status-note sessions have passed since
# its "last_touched_session" date and prints "<path>\t<count>" for every
# note at or past STALE_SESSION_THRESHOLD. Prints nothing (and always
# exits 0) if the open-items directory is missing/empty, the status note
# is missing/unreadable, or its Status Summary section has no dated
# entries.
#
# Session dates are collected from the status note's "## Status Summary"
# section only (same bounded-section idiom as extract_open_excerpt()), in
# file order (top = newest), without deduplicating same-day entries — each
# matched "**YYYY-MM-DD" line counts as one session. An item's
# sessions-untouched count is how many collected dates are strictly newer
# than its last_touched_session (i.e. appear above the first collected
# date that is <= it). If last_touched_session doesn't match any
# collected date, it's treated as older than all of them (count = total
# collected dates) — the conservative fallback for a date condensed away
# by a prior maintenance run.
stale_open_items() {
    local items_dir note dates
    items_dir=$(resolve_open_items_dir)
    [ -n "$items_dir" ] || return 0

    note=$(resolve_status_note_path)
    [ -n "$note" ] && [ -r "$note" ] || return 0

    dates=$(awk '
    /^## Status Summary[[:space:]]*$/ { found=1; next }
    found && /^##/ { exit }
    found && /^\*\*[0-9]{4}-[0-9]{2}-[0-9]{2}/ { print substr($0, 3, 10) }
  ' "$note" 2>/dev/null) || true
    [ -n "$dates" ] || return 0

    local total
    total=$(printf '%s\n' "$dates" | wc -l | tr -d ' ')

    # Pin collation for the [[ > ]] string date comparison below so a
    # non-C locale can't reorder "YYYY-MM-DD" strings unexpectedly.
    local LC_ALL=C
    local f status last_touched count d matched
    for f in "$items_dir"/*.md; do
        [ -f "$f" ] || continue
        # Basic Memory can re-serialize these as YAML-quoted strings
        # (e.g. 'open', "2026-11-17") on a note that goes through a
        # bm_write/bm_edit path that re-serializes metadata; strip quotes
        # along with whitespace or a quoted value never matches/sorts right.
        status=$(sed -n 's/^status:[[:space:]]*//p' "$f" | head -n1 | tr -d "\"'[:space:]")
        [ "$status" = open ] || continue
        last_touched=$(sed -n 's/^last_touched_session:[[:space:]]*//p' "$f" | head -n1 | tr -d "\"'[:space:]")
        [ -n "$last_touched" ] || continue

        count=0
        matched=0
        while IFS= read -r d; do
            if ! [[ "$d" > "$last_touched" ]]; then
                matched=1
                break
            fi
            count=$((count + 1))
        done <<<"$dates"
        [ "$matched" -eq 1 ] || count=$total

        if [ "$count" -ge "$STALE_SESSION_THRESHOLD" ]; then
            printf '%s\t%s\n' "$f" "$count"
        fi
    done
    return 0
}
