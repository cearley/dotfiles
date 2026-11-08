#!/usr/bin/env bash
# crash-recovery-hook.sh — SessionStart hook: detects a prior session that ended
# without save-session ever completing its own evaluation for this project, and
# surfaces a catch-up instruction via stdout — no process is ever spawned.
#
# Deployed once, machine-wide, by chezmoi (like basic-memory-write-guard.sh) — this
# script takes no __PROJECT__ substitution; only session_id/transcript_path/cwd from
# hook stdin and local file mtimes matter. See check-drift.sh's crash-recovery-hook
# piece for the per-project SessionStart entry pointing at this fixed global path.
#
# SessionEnd cannot fire on SIGKILL/crash/closed-terminal by construction — this is
# the best-effort, next-session fallback (see design.md Decision 4). But a missing
# SessionEnd record is NOT proof of a crash: confirmed 2026-11-08 that a `/clear`
# transition can also leave no SessionEnd logged on the old session, even though it
# was an intentional, clean end. This script's own SessionStart invocation carries a
# `source` field ("startup"|"resume"|"clear"|"compact"|"fork" per Claude Code's hook
# schema) that tells us whether THIS session was itself born from a `/clear` — when it
# was, the predecessor's missing SessionEnd is known to be benign, so the reminder
# below says so instead of asserting "killed, crashed, or terminal closed" as fact.
# Kept non-blocking by exiting 0 unconditionally: every branch here is a cheap local
# file check, never a spawned process (that's the whole point — see design.md
# Decision 4's "the better answer is usually to make the worker something that isn't
# a Claude Code session").
set -euo pipefail

# Minimum number of real user turns unsaved since the last completed save-session
# evaluation before the catch-up reminder fires. See design.md Decision 6.
UNSAVED_TURN_THRESHOLD=5

INPUT=$(cat)
jq -e . >/dev/null 2>&1 <<<"$INPUT" || exit 0

SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty')
TRANSCRIPT_PATH=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty')
HOOK_CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty')
# Why THIS session started — see the header comment above. Absent/unrecognized values
# fall through to the generic (unasserted-cause) message branch below, unchanged from
# this script's prior behavior.
SOURCE=$(printf '%s' "$INPUT" | jq -r '.source // empty')

if [ -n "$HOOK_CWD" ]; then
  cd "$HOOK_CWD" 2>/dev/null || exit 0
fi

MARKER=".claude/.last-saved-session"

if [ -n "$TRANSCRIPT_PATH" ] && [ -n "$SESSION_ID" ]; then
  TRANSCRIPT_DIR=$(dirname "$TRANSCRIPT_PATH")
  if [ -d "$TRANSCRIPT_DIR" ]; then
    MARKER_CONTENT=""
    [ -f "$MARKER" ] && MARKER_CONTENT=$(cat "$MARKER")
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
      PRIOR_TOTAL_TURNS=$(jq -c 'select(.type=="user" and (.toolUseResult // null)==null and (.isMeta // false)==false)' "$LATEST_PRIOR" | wc -l | tr -d ' ')
      if [ "$PRIOR_SESSION_ID" = "$MARKER_SESSION_ID" ]; then
        UNSAVED_TURNS=$((PRIOR_TOTAL_TURNS - MARKER_TURN_COUNT))
      else
        UNSAVED_TURNS=$PRIOR_TOTAL_TURNS
      fi
    fi

    if [ -n "$LATEST_PRIOR" ] && [ "$UNSAVED_TURNS" -gt "$UNSAVED_TURN_THRESHOLD" ]; then
      if [ "$SOURCE" = "clear" ]; then
        CAUSE_PHRASE="ended via /clear, not a crash — but its SessionEnd was never logged (a known Claude Code gap on some /clear transitions)"
      else
        CAUSE_PHRASE="ended without SessionEnd ever being logged — most often this means it was killed, crashed, or had its terminal closed, but it could also have been a clean exit that simply wasn't recorded"
      fi
      echo "SYSTEM REMINDER: A prior Claude Code session (${PRIOR_SESSION_ID}) ${CAUSE_PHRASE}, so no in-session or SessionEnd save happened for it. Mention this to the user somewhere in your response rather than holding onto it silently, and ask whether they want you to run a crash-recovery catch-up pass for it now — do not run it without asking first.

If they agree: read ${LATEST_PRIOR} first (JSONL, one message/tool-call per line) — this is NOT your own conversation and you have no other context, so reconstruct what was changed or decided from that transcript before doing anything else — then follow the save-session skill's Step 1 through Step 2, then \"On success\"/\"On failure\", using that reconstructed content. If nothing decision-worthy happened in that session, stop without saving and log a no-op instead of forcing an entry."
    fi
  fi
fi

exit 0
