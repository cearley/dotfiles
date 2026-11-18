#!/usr/bin/env bash
# shellcheck disable=SC2016
# bashunit coverage guarding setup-memory-workflow's rendered skill
# templates against reintroducing the bm_edit/bm_read parameter-name bugs
# fixed by fix-save-session-redundancy: `content` (not `replace_text`) as
# bm_edit's find_replace replacement argument, and bm_read's real pagination
# arguments (start_line/end_line/max_tokens, no `page`). Pure grep against
# the template source; no MCP calls, no scratch HOME needed.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="$REPO_ROOT/home/dot_claude/skills/setup-memory-workflow/assets/save-session-skill.md.template"

function test_template_file_exists() {
    assert_file_exists "$TEMPLATE"
}

function test_template_has_no_replace_text_argument() {
    local found=0
    grep -q 'replace_text' "$TEMPLATE" && found=1
    assert_same "0" "$found"
}

function test_template_documents_find_replace_with_content_argument() {
    local found=0
    grep -q 'find_replace.*content=' "$TEMPLATE" && found=1
    assert_same "1" "$found"
}

function test_template_has_no_bm_read_page_argument() {
    local found=0
    grep -qE 'bm_read\([^)]*page' "$TEMPLATE" && found=1
    assert_same "0" "$found"
}

function test_template_documents_bm_read_pagination_arguments() {
    local found=0
    grep -q 'start_line.*end_line.*max_tokens' "$TEMPLATE" && found=1
    assert_same "1" "$found"
}

function test_save_session_template_documents_open_item_note_type() {
    local found=0
    grep -q 'type: open-item' "$TEMPLATE" && found=1
    assert_same "1" "$found"
}

function test_save_session_template_documents_open_pointer_line_format() {
    local found=0
    grep -q '\[\[Open: ' "$TEMPLATE" && found=1
    assert_same "1" "$found"
}

function test_save_session_template_is_forward_only_for_open_items() {
    local found=0
    grep -qi 'forward-only' "$TEMPLATE" && found=1
    assert_same "1" "$found"
}

function test_save_session_template_still_preserves_open_baseline() {
    # Guards against this task accidentally dropping the existing v-anything
    # rule that resolved items are the only thing ever removed from Open.
    local found=0
    grep -q 'Preserve the existing Open' "$TEMPLATE" && found=1
    assert_same "1" "$found"
}

function test_save_session_template_documents_touch_tracking() {
    local found=0
    grep -qi 'Touch tracking' "$TEMPLATE" && found=1
    assert_same "1" "$found"
}

function test_save_session_template_documents_resolving_pointer_items() {
    local found=0
    grep -qi 'resolving a pointer-ized item' "$TEMPLATE" && found=1
    assert_same "1" "$found"
}

TEMPLATE_MAINT="$REPO_ROOT/home/dot_claude/skills/setup-memory-workflow/assets/save-session-maintenance-skill.md.template"

function test_maintenance_template_exists() {
    assert_file_exists "$TEMPLATE_MAINT"
}

function test_maintenance_template_calls_open_staleness() {
    local found=0
    grep -q 'open-staleness' "$TEMPLATE_MAINT" && found=1
    assert_same "1" "$found"
}

function test_maintenance_template_documents_stale_index_title() {
    local found=0
    grep -q 'Stale Open Items Index' "$TEMPLATE_MAINT" && found=1
    assert_same "1" "$found"
}

function test_maintenance_template_runs_schema_validate() {
    local found=0
    grep -q 'bm_schema' "$TEMPLATE_MAINT" && found=1
    assert_same "1" "$found"
}

function test_maintenance_template_sets_status_stale_on_rollup() {
    # Without this, check-drift.sh open-staleness would re-report the same
    # already-indexed item on every later maintenance run (stale_open_items()
    # only skips items whose own status is "stale"). Matches the specific
    # transition instruction, not just "status" and "stale" appearing
    # anywhere in the file.
    local found=0
    grep -qF 'status` from `open` to `stale`' "$TEMPLATE_MAINT" && found=1
    assert_same "1" "$found"
}

function test_maintenance_template_documents_on_request_conversion() {
    local found=0
    grep -qi 'on-request' "$TEMPLATE_MAINT" && found=1
    assert_same "1" "$found"
}

function test_maintenance_template_conversion_is_not_bulk() {
    # Guards against this step regressing into an automatic sweep of every
    # legacy Open item.
    local found=0
    grep -qi 'never a bulk' "$TEMPLATE_MAINT" && found=1
    assert_same "1" "$found"
}
