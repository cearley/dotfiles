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
# the best-effort, next-session fallback (see design.md Decision 4). Kept
# non-blocking by exiting 0 unconditionally: every branch here is a cheap local file
# check, never a spawned process (that's the whole point — see design.md Decision 4's
# "the better answer is usually to make the worker something that isn't a Claude Code
# session").
set -euo pipefail

INPUT=$(cat)
jq -e . >/dev/null 2>&1 <<<"$INPUT" || exit 0

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
    MARKER_SESSION_ID=""
    [ -f "$MARKER" ] && MARKER_SESSION_ID=$(cat "$MARKER")

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

    if [ -n "$LATEST_PRIOR" ] && [ "$PRIOR_SESSION_ID" != "$MARKER_SESSION_ID" ]; then
      echo "Run the save-session skill (Step 1 through Step 2, then \"On success\"/\"On failure\") for the Claude Code session whose full transcript is at: ${LATEST_PRIOR}

This is NOT your own conversation and you have no other context — read that transcript file first (JSONL, one message/tool-call per line) to reconstruct what was changed or decided, then follow save-session's steps exactly using that reconstructed content. This is a crash-recovery catch-up: session ${PRIOR_SESSION_ID} ended without SessionEnd ever firing (killed, crashed, or terminal closed), so no in-session or SessionEnd save happened for it. If nothing decision-worthy happened in that session, stop without saving and log a no-op instead of forcing an entry."
    fi
  fi
fi

exit 0
