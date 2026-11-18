#!/usr/bin/env bash
# bashunit coverage for lib-open-items.sh: check_open_section_overflow(),
# the SessionStart signal that fires when the status note's Open section
# has grown past OPEN_LINE_CAP live items, and stale_open_items() /
# `check-drift.sh open-staleness`, which flags open-items/ notes that have
# gone STALE_SESSION_THRESHOLD or more status-note sessions untouched.

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

function write_mixed_open_section() {
    # args: legacy count, pointer count
    local legacy="$1" pointer="$2"
    {
        printf '## Open\n\n'
        for ((i = 0; i < legacy; i++)); do printf -- '- [problem] legacy item %d\n' "$i"; done
        for ((i = 0; i < pointer; i++)); do printf -- '- [problem] item %d — [[Open: slug-%d]]\n' "$i" "$i"; done
    } >"$NOTE"
}

function test_overflow_dominated_by_legacy_points_at_conversion() {
    write_mixed_open_section 12 4
    local out
    out=$(check_open_section_overflow)
    assert_contains "legacy" "$out"
    assert_contains "conversion" "$out"
}

function test_overflow_dominated_by_pointers_points_at_rollup() {
    write_mixed_open_section 4 12
    local out
    out=$(check_open_section_overflow)
    assert_contains "save-session-maintenance" "$out"
    assert_not_contains "legacy" "$out"
}

CHECK_DRIFT="$REPO_ROOT/home/dot_claude/skills/setup-memory-workflow/scripts/executable_check-drift.sh"

function write_status_summary() {
    # args: one or more dates, newest first, written as separate dated entries
    {
        printf '## Status Summary\n\n'
        for d in "$@"; do printf '**%s**\nentry\n\n' "$d"; done
        printf '## Open\n'
    } >"$NOTE"
}

function write_open_item() {
    # args: slug, status, last_touched_session
    mkdir -p "$SCRATCH/.local/share/basic-memory/proj/open-items"
    cat >"$SCRATCH/.local/share/basic-memory/proj/open-items/$1.md" <<EOF
---
type: open-item
status: $2
last_touched_session: $3
---
EOF
}

function run_open_staleness() {
    (cd "$PROJECT_DIR" && HOME="$SCRATCH" bash "$CHECK_DRIFT" open-staleness)
}

function set_up_project_dir() {
    # Named "proj" (not e.g. "repo") because `check-drift.sh` resolves
    # $PROJECT from this directory's basename when it isn't a git repo
    # (lib-project.sh's resolve_project() fallback) — it must match the
    # "proj" used in every fixture path below, or PROJECT mismatches and
    # every fixture note resolves as missing.
    PROJECT_DIR="$SCRATCH/proj"
    mkdir -p "$PROJECT_DIR"
}

function test_no_open_items_dir_exits_zero() {
    set_up_project_dir
    write_status_summary 2026-11-17
    local ec=0
    run_open_staleness >/dev/null 2>&1 || ec=$?
    assert_same "0" "$ec"
}

function test_below_threshold_not_stale() {
    set_up_project_dir
    write_status_summary 2026-11-17 2026-11-16 2026-11-15 2026-11-14
    write_open_item itemA open 2026-11-15
    local out ec=0
    out=$(run_open_staleness) || ec=$?
    assert_same "0" "$ec"
    assert_empty "$out"
}

function test_at_threshold_is_stale() {
    set_up_project_dir
    write_status_summary 2026-11-17 2026-11-16 2026-11-15 2026-11-14 2026-11-13
    write_open_item itemA open 2026-11-12
    local out ec=0
    out=$(run_open_staleness) || ec=$?
    assert_same "1" "$ec"
    assert_contains "itemA" "$out"
}

function test_same_day_entries_each_count() {
    set_up_project_dir
    write_status_summary 2026-11-17 2026-11-17 2026-11-17 2026-11-17 2026-11-17
    write_open_item itemA open 2026-11-16
    local ec=0
    run_open_staleness >/dev/null 2>&1 || ec=$?
    assert_same "1" "$ec"
}

function test_last_touched_not_found_is_conservatively_stale() {
    set_up_project_dir
    # 5 dates, item's last_touched_session (2026-01-01) is older than all
    # of them, so it never matches a collected date and the conservative
    # fallback counts = total = 5 — update this fixture's date count
    # alongside STALE_SESSION_THRESHOLD if it changes.
    write_status_summary 2026-11-17 2026-11-16 2026-11-15 2026-11-14 2026-11-13
    write_open_item itemA open 2026-01-01
    local out ec=0
    out=$(run_open_staleness) || ec=$?
    assert_contains "itemA" "$out"
}

function test_quoted_frontmatter_values_are_stripped() {
    # Pins Important 8: Basic Memory can re-serialize frontmatter values as
    # YAML-quoted strings (e.g. 'open', "2026-11-17"). Without stripping
    # quotes, a quoted status never matches "open" (never counted as
    # stale) and a quoted date sorts below every unquoted date (falsely
    # maximally stale) — this fixture uses a quoted status AND a quoted
    # last_touched_session that should legitimately be at-threshold stale.
    set_up_project_dir
    write_status_summary 2026-11-17 2026-11-16 2026-11-15 2026-11-14 2026-11-13
    mkdir -p "$SCRATCH/.local/share/basic-memory/proj/open-items"
    cat >"$SCRATCH/.local/share/basic-memory/proj/open-items/itemA.md" <<'EOF'
---
type: open-item
status: 'open'
last_touched_session: "2026-11-12"
---
EOF
    local out ec=0
    out=$(run_open_staleness) || ec=$?
    assert_same "1" "$ec"
    assert_contains "itemA" "$out"
}

function test_resolved_item_never_counted() {
    set_up_project_dir
    write_status_summary 2026-11-17 2026-11-16 2026-11-15 2026-11-14 2026-11-13
    write_open_item itemA resolved 2026-01-01
    local ec=0
    run_open_staleness >/dev/null 2>&1 || ec=$?
    assert_same "0" "$ec"
}

function test_already_stale_item_never_recounted() {
    # Pins the fix for the bug this exact fixture would otherwise expose:
    # an item Task 4 already rolled into the index keeps status "stale",
    # not "open" — if it were left "open", this item would incorrectly
    # reappear here on every later run.
    set_up_project_dir
    write_status_summary 2026-11-17 2026-11-16 2026-11-15 2026-11-14 2026-11-13
    write_open_item itemA stale 2026-01-01
    local ec=0
    run_open_staleness >/dev/null 2>&1 || ec=$?
    assert_same "0" "$ec"
}
