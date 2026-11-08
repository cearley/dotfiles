#!/usr/bin/env bash
# session-reminder.sh — SessionStart hook: prints a deferential background-
# context reminder, with a live excerpt of the current-status note's Open
# section when one can be resolved. Static, machine-wide, non-templated —
# see check-drift.sh's reminder-hook piece for the fixed command string
# that points every project's SessionStart hook at this one script (design
# D2). Resolves $PROJECT itself at runtime via lib-project.sh's
# resolve_project() — the one piece of apply-time logic this script
# duplicates rather than re-derives.
#
# Read-only by construction (D3): only ever reads files under
# ~/.local/share/basic-memory/; never creates, writes, or moves anything —
# a missing canonical note is left for the model to create via bm_write.
# Non-canonical notes are flagged, never auto-moved (D4). Exits 0
# unconditionally regardless of what it finds.
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=home/dot_claude/skills/setup-memory-workflow/scripts/lib-project.sh
source "$SKILL_DIR/lib-project.sh"
# shellcheck source=home/dot_claude/skills/setup-memory-workflow/scripts/lib-status-note.sh
source "$SKILL_DIR/lib-status-note.sh"
# shellcheck source=home/dot_claude/skills/setup-memory-workflow/scripts/lib-session-log.sh
source "$SKILL_DIR/lib-session-log.sh"

INPUT=$(cat)
HOOK_CWD=$(jq -r '.cwd // empty' <<<"$INPUT" 2>/dev/null || true)
if [ -n "$HOOK_CWD" ]; then
  cd "$HOOK_CWD" 2>/dev/null || true
fi

# Same override-file-then-git-basename logic check-drift.sh uses at
# apply-time (lib-project.sh's resolve_project(), not re-derived here).
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$PROJECT_ROOT"
PROJECT=$(resolve_project)

NOTE=$(resolve_status_note_path)
OPEN_EXCERPT_BLOCK=""
NONCANON_NOTICE=""
if [ -n "$NOTE" ]; then
  EXCERPT=$(extract_open_excerpt)
  if [ -n "$EXCERPT" ]; then
    OPEN_EXCERPT_BLOCK=$(printf '\nOpen items from the status note (may be stale — call search_notes/recent_activity for the latest):\n%s' "$EXCERPT")
  fi
  if ! status_note_is_canonical "$NOTE"; then
    NONCANON_NOTICE="
[setup-memory-workflow] current-status note found at a non-canonical location — consider moving it to status/$PROJECT-current-status.md."
  fi
fi

read -r -d '' PREAMBLE <<EOF || true
SYSTEM REMINDER (background context for the $PROJECT project, tracked in basic-memory — weigh it alongside the user's current request and any in-progress task, and defer to those on conflict): if open items appear below, they are a snapshot as of the date shown there — call search_notes and recent_activity yourself on basic-memory project "$PROJECT" only if that snapshot is insufficient, stale, or missing (no items shown below means call them now). Make that call regardless of how fresh the snapshot looks whenever the user's message uses direct resume or status-request language, such as "what's the current status," "where did we leave off," or "let's resume/continue."
EOF

printf '%s%s%s\n' "$PREAMBLE" "$OPEN_EXCERPT_BLOCK" "$NONCANON_NOTICE"

check_status_note_bloat || true
check_session_log_bloat || true

exit 0
