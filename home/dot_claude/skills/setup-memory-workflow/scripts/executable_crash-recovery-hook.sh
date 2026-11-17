#!/usr/bin/env bash
# crash-recovery-hook.sh — SessionStart hook: detects a prior session that ended
# without save-session completing its evaluation for this project, and surfaces a
# catch-up instruction via stdout. No process is ever spawned, and recovery of
# transcript content requires a separate explicit user request.
set -euo pipefail

UNSAVED_TURN_THRESHOLD=5

# Parses marker content "SESSION_ID:TURN_COUNT" into MARKER_SESSION_ID/MARKER_TURN_COUNT.
# A bare-session-ID marker (no ":", from an older format) degrades to turn-count 0,
# as does any non-numeric tail (e.g. from a marker truncated by the crash itself).
parse_marker() {
    local content="$1"
    MARKER_SESSION_ID="${content%%:*}"
    if [ "$content" = "$MARKER_SESSION_ID" ]; then
        MARKER_TURN_COUNT=0
    else
        MARKER_TURN_COUNT="${content#*:}"
    fi
    [[ "$MARKER_TURN_COUNT" =~ ^[0-9]+$ ]] || MARKER_TURN_COUNT=0
}

# Most recently modified *.jsonl in $1, excluding $2 (the session starting now).
latest_prior_transcript() {
    local dir="$1" exclude="$2" latest="" latest_mtime=0 f mtime
    for f in "$dir"/*.jsonl; do
        [ -f "$f" ] || continue
        [ "$(basename "$f" .jsonl)" = "$exclude" ] && continue
        mtime=$(stat -f '%m' "$f" 2>/dev/null || stat -c '%Y' "$f" 2>/dev/null || echo 0)
        [ "$mtime" -gt "$latest_mtime" ] && {
            latest_mtime=$mtime
            latest=$f
        }
    done
    if [ -n "$latest" ]; then
        printf '%s\n' "$latest"
    fi
}

INPUT=$(cat) || exit 0
jq -e 'type == "object"' >/dev/null 2>&1 <<<"$INPUT" || exit 0

SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty')
TRANSCRIPT_PATH=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty')
HOOK_CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty')
[ -z "$HOOK_CWD" ] || cd "$HOOK_CWD" 2>/dev/null || exit 0

[ -n "$TRANSCRIPT_PATH" ] && [ -n "$SESSION_ID" ] || exit 0
TRANSCRIPT_DIR=$(dirname "$TRANSCRIPT_PATH")
[ -d "$TRANSCRIPT_DIR" ] || exit 0

MARKER=".claude/.last-saved-session"
MARKER_CONTENT=""
if [ -f "$MARKER" ]; then
    MARKER_CONTENT=$(cat "$MARKER" 2>/dev/null) || exit 0
fi
parse_marker "$MARKER_CONTENT"

LATEST_PRIOR=$(latest_prior_transcript "$TRANSCRIPT_DIR" "$SESSION_ID")
[ -n "$LATEST_PRIOR" ] || exit 0
PRIOR_SESSION_ID=$(basename "$LATEST_PRIOR" .jsonl)

PRIOR_TOTAL_TURNS=$(jq -c 'select(.type=="user" and (.toolUseResult // null)==null and (.isMeta // false)==false)' "$LATEST_PRIOR" 2>/dev/null | wc -l | tr -d ' ') || exit 0
if [ "$PRIOR_SESSION_ID" = "$MARKER_SESSION_ID" ]; then
    UNSAVED_TURNS=$((PRIOR_TOTAL_TURNS - MARKER_TURN_COUNT))
else
    UNSAVED_TURNS=$PRIOR_TOTAL_TURNS
fi
[ "$UNSAVED_TURNS" -gt "$UNSAVED_TURN_THRESHOLD" ] || exit 0

echo "SYSTEM REMINDER (background context; defer to the user's current request): Prior session ${PRIOR_SESSION_ID} has potentially unsaved work (${UNSAVED_TURNS} real user turns beyond the saved checkpoint). This does not establish a crash or an unobserved SessionEnd event. Offer recovery of ${LATEST_PRIOR}; wait for an explicit recovery request covering reading that named transcript and saving reconstructed findings. Standing recording consent alone does not authorize recovery.

After that request, read only the named transcript to reconstruct decision-worthy content, then run save-session from its identity/prerequisite/authorization checks through its receipt verification. Do not skip those checks. If no content is worth saving, report a no-op. Leave the marker unchanged for recovery: the current-session checkpoint must not claim coverage of a different transcript. Failed or uncertain writes also leave the marker unchanged; report partial success without blindly replaying an append."

exit 0
