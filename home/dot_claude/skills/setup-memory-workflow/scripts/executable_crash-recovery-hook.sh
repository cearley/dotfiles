#!/usr/bin/env bash
# crash-recovery-hook.sh — SessionStart hook: detects a prior session that ended
# without save-session completing its evaluation for this project, and surfaces a
# catch-up instruction via stdout — no process is ever spawned.
#
# Deployed once, machine-wide by chezmoi (like basic-memory-write-guard.sh); takes no
# __PROJECT__ substitution. See check-drift.sh's crash-recovery-hook piece for the
# per-project SessionStart entry pointing at this fixed global path.
#
# Detection uses local transcript metadata and turn counts only. It cannot prove
# how the prior session ended or whether a SessionEnd event was recorded.
# Recovery of transcript content requires a separate explicit user request.
set -euo pipefail

# Minimum number of real user turns unsaved since the last completed save-session
# evaluation before the catch-up reminder fires. See design.md Decision 6.
UNSAVED_TURN_THRESHOLD=5

INPUT=$(cat) || exit 0
jq -e 'type == "object"' >/dev/null 2>&1 <<<"$INPUT" || exit 0

SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty')
TRANSCRIPT_PATH=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty')
HOOK_CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty')

if [ -n "$HOOK_CWD" ]; then
    cd "$HOOK_CWD" 2>/dev/null || exit 0
fi

MARKER=".claude/.last-saved-session"

if [ -n "$TRANSCRIPT_PATH" ] && [ -n "$SESSION_ID" ]; then
    TRANSCRIPT_DIR=$(dirname "$TRANSCRIPT_PATH")
    if [ -d "$TRANSCRIPT_DIR" ]; then
        MARKER_CONTENT=""
        if [ -f "$MARKER" ]; then
            MARKER_CONTENT=$(cat "$MARKER" 2>/dev/null) || exit 0
        fi
        # New format is "SESSION_ID:TURN_COUNT"; an older bare-session-ID marker has no
        # ":" and degrades to turn-count 0 rather than erroring (self-heals on next save).
        MARKER_SESSION_ID="${MARKER_CONTENT%%:*}"
        if [ "$MARKER_CONTENT" = "$MARKER_SESSION_ID" ]; then
            MARKER_TURN_COUNT=0
        else
            MARKER_TURN_COUNT="${MARKER_CONTENT#*:}"
        fi
        # A marker truncated or corrupted by the very crash this hook detects can leave a
        # non-numeric tail; degrade to 0 (same as the old-bare-marker-format case above)
        # rather than letting the arithmetic below abort under set -e.
        [[ "$MARKER_TURN_COUNT" =~ ^[0-9]+$ ]] || MARKER_TURN_COUNT=0

        LATEST_PRIOR=""
        LATEST_PRIOR_MTIME=0
        for f in "$TRANSCRIPT_DIR"/*.jsonl; do
            [ -f "$f" ] || continue
            # Exclude the session that's starting right now — it's not a prior session to recover.
            [ "$(basename "$f" .jsonl)" = "$SESSION_ID" ] && continue
            MTIME=$(stat -f '%m' "$f" 2>/dev/null || stat -c '%Y' "$f" 2>/dev/null || echo 0)
            if [ "$MTIME" -gt "$LATEST_PRIOR_MTIME" ]; then
                LATEST_PRIOR_MTIME=$MTIME
                LATEST_PRIOR=$f
            fi
        done

        PRIOR_SESSION_ID=""
        [ -n "$LATEST_PRIOR" ] && PRIOR_SESSION_ID=$(basename "$LATEST_PRIOR" .jsonl)

        UNSAVED_TURNS=0
        if [ -n "$LATEST_PRIOR" ]; then
            PRIOR_TOTAL_TURNS=$(jq -c 'select(.type=="user" and (.toolUseResult // null)==null and (.isMeta // false)==false)' "$LATEST_PRIOR" 2>/dev/null | wc -l | tr -d ' ') || exit 0
            if [ "$PRIOR_SESSION_ID" = "$MARKER_SESSION_ID" ]; then
                UNSAVED_TURNS=$((PRIOR_TOTAL_TURNS - MARKER_TURN_COUNT))
            else
                UNSAVED_TURNS=$PRIOR_TOTAL_TURNS
            fi
        fi

        if [ -n "$LATEST_PRIOR" ] && [ "$UNSAVED_TURNS" -gt "$UNSAVED_TURN_THRESHOLD" ]; then
            echo "SYSTEM REMINDER (background context; defer to the user's current request): Prior session ${PRIOR_SESSION_ID} has potentially unsaved work (${UNSAVED_TURNS} real user turns beyond the saved checkpoint). This does not establish a crash or an unobserved SessionEnd event. Offer recovery of ${LATEST_PRIOR}; wait for an explicit recovery request covering reading that named transcript and saving reconstructed findings. Standing recording consent alone does not authorize recovery.

After that request, read only the named transcript to reconstruct decision-worthy content, then run save-session from its identity/prerequisite/authorization checks through its receipt verification. Do not skip those checks. If no content is worth saving, report a no-op. Leave the marker unchanged for recovery: the current-session checkpoint must not claim coverage of a different transcript. Failed or uncertain writes also leave the marker unchanged; report partial success without blindly replaying an append."

        fi
    fi
fi

exit 0
