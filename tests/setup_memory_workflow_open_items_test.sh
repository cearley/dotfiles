#!/usr/bin/env bash
# bashunit coverage for lib-open-items.sh's check_open_section_overflow(),
# the SessionStart signal that fires when the status note's Open section
# has grown past OPEN_LINE_CAP live items.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL_DIR="$REPO_ROOT/home/dot_claude/skills/setup-memory-workflow/scripts"

function set_up() {
    SCRATCH="$(bashunit::temp_dir)"
    HOME="$SCRATCH"
    PROJECT="proj"
    STATUS_DIR="$SCRATCH/.local/share/basic-memory/proj/status"
    mkdir -p "$STATUS_DIR"
    NOTE="$STATUS_DIR/proj-current-status.md"
    # shellcheck source=home/dot_claude/skills/setup-memory-workflow/scripts/lib-status-note.sh
    source "$SKILL_DIR/lib-status-note.sh"
    # shellcheck source=home/dot_claude/skills/setup-memory-workflow/scripts/lib-open-items.sh
    source "$SKILL_DIR/lib-open-items.sh"
}

function write_open_section() {
    local n="$1"
    {
        printf '## Open\n\n'
        for ((i = 0; i < n; i++)); do printf -- '- [problem] item %d\n' "$i"; done
    } >"$NOTE"
}

function test_under_cap_prints_nothing() {
    write_open_section 10
    local out
    out=$(check_open_section_overflow)
    assert_empty "$out"
}

function test_at_cap_prints_nothing() {
    write_open_section 15
    local out
    out=$(check_open_section_overflow)
    assert_empty "$out"
}

function test_over_cap_prints_warning() {
    write_open_section 16
    local out
    out=$(check_open_section_overflow)
    assert_contains "16" "$out"
}

function test_no_status_note_prints_nothing() {
    rm -f "$NOTE"
    local out
    out=$(check_open_section_overflow)
    assert_empty "$out"
}
