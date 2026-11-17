#!/usr/bin/env bash
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
