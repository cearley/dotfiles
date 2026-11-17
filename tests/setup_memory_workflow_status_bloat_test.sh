#!/usr/bin/env bash
# bashunit coverage for executable_check-drift.sh's `status-bloat`
# subcommand (fix-save-session-redundancy), which wraps
# lib-status-note.sh's check_status_note_bloat() so /save-session's Step 1
# can gate new entries on a real shell precondition instead of a model
# self-assessment. Each test runs the real script against a scratch
# HOME/project so nothing touches a real basic-memory install.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK_DRIFT="$REPO_ROOT/home/dot_claude/skills/setup-memory-workflow/scripts/executable_check-drift.sh"

function set_up() {
    SCRATCH="$(bashunit::temp_dir)"
    PROJECT_DIR="$SCRATCH/proj"
    mkdir -p "$PROJECT_DIR"
    STATUS_DIR="$SCRATCH/.local/share/basic-memory/proj/status"
    mkdir -p "$STATUS_DIR"
    NOTE="$STATUS_DIR/proj-current-status.md"
}

function run_status_bloat() {
    (cd "$PROJECT_DIR" && HOME="$SCRATCH" bash "$CHECK_DRIFT" status-bloat)
}

function test_under_all_thresholds_exits_zero() {
    printf '# Status\n\nshort note\n' >"$NOTE"
    local ec=0
    run_status_bloat >/dev/null 2>&1 || ec=$?
    assert_same "0" "$ec"
}

function test_at_character_threshold_exits_one() {
    # 150 lines of 59 chars (incl. newline) = 8,850 total chars: over the
    # 8,000-char signal while staying under the 200-line and 800-char-line
    # signals, so this fixture isolates the character threshold.
    awk 'BEGIN { for (i = 0; i < 150; i++) { s = ""; for (j = 0; j < 58; j++) s = s "x"; print s } }' >"$NOTE"
    local ec=0
    run_status_bloat >/dev/null 2>&1 || ec=$?
    assert_same "1" "$ec"
}

function test_at_line_threshold_exits_one() {
    # 210 one-char lines: over the 200-line signal, well under the char and
    # single-line-length signals.
    awk 'BEGIN { for (i = 0; i < 210; i++) print "x" }' >"$NOTE"
    local ec=0
    run_status_bloat >/dev/null 2>&1 || ec=$?
    assert_same "1" "$ec"
}

function test_at_single_line_length_threshold_exits_one() {
    # One 800-char line: over the single-line-length signal, well under the
    # char and line-count signals.
    awk 'BEGIN { s = ""; for (j = 0; j < 800; j++) s = s "a"; print s }' >"$NOTE"
    local ec=0
    run_status_bloat >/dev/null 2>&1 || ec=$?
    assert_same "1" "$ec"
}
