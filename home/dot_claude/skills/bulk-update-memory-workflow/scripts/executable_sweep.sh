#!/usr/bin/env bash
# sweep.sh — bulk-update-memory-workflow's own helper: discover every project on this
# machine with setup-memory-workflow installed, then run check-drift.sh against each.
#
# Usage:
#   sweep.sh check    # informational only — report drift per project, change nothing
#   sweep.sh update   # repair every plain-DRIFT piece in every discovered project
#
# Always run `check` first and read its output for NAME-MISMATCH before ever running
# `update` in bulk — see this skill's SKILL.md for why.
set -euo pipefail

MODE="${1:-}"
case "$MODE" in
  check|update) ;;
  *)
    echo "Usage: sweep.sh <check|update>" >&2
    exit 1
    ;;
esac

CHECK_DRIFT="$HOME/.claude/skills/setup-memory-workflow/scripts/check-drift.sh"
if [ ! -x "$CHECK_DRIFT" ]; then
  echo "MISSING: $CHECK_DRIFT not found or not executable — is setup-memory-workflow installed?" >&2
  exit 1
fi

fd --hidden --no-ignore-vcs --type d --full-path '\.claude/skills/save-session$' "$HOME" \
  | grep -v '\.stversions\|_Archived Items' \
  | sed 's#/\.claude/skills/save-session/\?$##' \
  | while IFS= read -r p; do
      echo "=== $p ==="
      ( cd "$p" 2>/dev/null && "$CHECK_DRIFT" "$MODE" ) || echo "  FAILED: $p"
    done
