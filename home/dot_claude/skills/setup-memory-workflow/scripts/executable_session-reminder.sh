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

INPUT=$(cat) || exit 0
jq -e 'type == "object"' >/dev/null 2>&1 <<<"$INPUT" || exit 0
HOOK_CWD=$(jq -r '.cwd // empty' <<<"$INPUT" 2>/dev/null) || exit 0
if [ -n "$HOOK_CWD" ]; then
    cd "$HOOK_CWD" 2>/dev/null || exit 0
fi

# Same override-file-then-git-basename logic check-drift.sh uses at
# apply-time (lib-project.sh's resolve_project(), not re-derived here).
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$PROJECT_ROOT" 2>/dev/null || exit 0
PROJECT=$(resolve_project 2>/dev/null) || exit 0

NOTE=$(resolve_status_note_path)
OPEN_EXCERPT_BLOCK=""
NONCANON_NOTICE=""
if [ -n "$NOTE" ]; then
    EXCERPT=$(extract_open_excerpt)
    if [ -n "$EXCERPT" ]; then
        OPEN_EXCERPT_BLOCK=$(printf '\nOpen items from the status note (may be stale — use scoped bm_search/bm_project recent for the latest):\n%s' "$EXCERPT")
    fi
    if ! status_note_is_canonical "$NOTE"; then
        NONCANON_NOTICE="
[setup-memory-workflow] current-status note found at a non-canonical location — consider moving it to status/$PROJECT-current-status.md."
    fi
fi

read -r -d '' PREAMBLE <<EOF || true
SYSTEM REMINDER (background context for the $PROJECT project in basic-memory; defer to the user's current request and any in-progress task on conflict): any Open excerpt below is a snapshot. Perform the startup memory lookup required by higher-priority instructions, with project="$PROJECT" explicitly. Beyond that required lookup, use bm_search and bm_project(command="recent", project="$PROJECT") only when the snapshot is insufficient, stale or missing. Direct resume or status requests ("what's the current status," "where did we leave off," "let's resume/continue") override that default and warrant fresh retrieval. Reads need no recording consent. Automatic curated findings, decisions and checkpoints require a valid checkout/project-matched .basic-memory-workflow.json grant and the current save-session skill; otherwise offer a save. A direct save request authorizes that save only; generic wrap-up language is not authorization. Recovery of another transcript and maintenance each need a separate explicit request. Host tool approvals still apply.

EOF

printf '%s%s%s\n' "$PREAMBLE" "$OPEN_EXCERPT_BLOCK" "$NONCANON_NOTICE"

check_status_note_bloat || true
check_session_log_bloat || true

exit 0
