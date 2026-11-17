#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2016
#
# bashunit suite for claude-profile-mismatch-guard's permission contract (openspec
# capability: claude-profile-mismatch-guard). Split out of
# tests/claude-tooling-write-guard_test.sh -- a different concern (whose file is this)
# from that hook's (is this file safe to edit directly), with no shared state.
#
# The guard is a chezmoi TEMPLATE: rendered once (set_up_before_script) via
# tests/run-template into a scratch file, then executed as a whole script per test
# (never sourced).
#
# Isolation (same as the sibling suite):
#   - The deployed ~/.local/bin copy is never run or modified.
#   - `realpath` resolution is real and read-only, against this machine's actual
#     $HOME/.claude* profiles and this repo's real source tree -- nothing under $HOME
#     is ever written.
#   - CLAUDE_CONFIG_DIR is always passed explicitly, never inherited, so results don't
#     depend on which profile is active when the suite runs.
#
# Severity tags (M/L) label which regression each test guards against; not bashunit syntax.

function set_up_before_script() {
    TEST_FILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    REPO_ROOT="$(cd "$TEST_FILE_DIR/.." && pwd)"
    GUARD_RENDER_DIR="$(mktemp -d)"
    RENDERED_GUARD="$GUARD_RENDER_DIR/guard"
    "$TEST_FILE_DIR/run-template" \
        "$REPO_ROOT/home/dot_local/bin/executable_claude-profile-mismatch-guard.tmpl" \
        >"$RENDERED_GUARD"
    # No tear_down_after_script -- see the sibling suite's comment.
}

# run_guard <session_id> <tool_name> <tool_input-json> [CLAUDE_CONFIG_DIR]
function run_guard() {
    local session="$1" tool="$2" tool_input="$3" config_dir="${4:-$HOME/.claude}"
    local payload
    payload=$(jq -n --arg s "$session" --arg t "$tool" --argjson i "$tool_input" \
        '{session_id: $s, tool_name: $t, tool_input: $i}')
    CLAUDE_CONFIG_DIR="$config_dir" bash "$RENDERED_GUARD" <<<"$payload"
}

# decision <guard-stdout>
function decision() {
    jq -r '.hookSpecificOutput.permissionDecision // "none"' <<<"${1:-{\}}"
}

function test_unrelated_bash_command_produces_no_output() {
    local out
    out=$(run_guard s1 Bash '{"command": "ls /tmp"}')

    assert_empty "$out"
}

# This is the only thing this hook does for Read at all -- the sibling guard never covers it.
function test_read_of_other_profile_file_asks() {
    local out
    out=$(run_guard s2 Read "$(jq -n --arg p "$HOME/.claude-work/settings.json" \
        '{file_path: $p}')" "$HOME/.claude-personal")

    assert_same "ask" "$(decision "$out")"
}

# plugins/ isn't chezmoi-managed, but this hook only cares that the path belongs to a
# different profile than the active one.
function test_bash_write_into_other_profiles_plugins_dir_asks() {
    local out
    out=$(run_guard s3 Bash '{"command": "echo x > ~/.claude-work/plugins/guard-test-x"}' "$HOME/.claude-personal")

    assert_same "ask" "$(decision "$out")"
}

# Sweep: this hook's only possible decision is "ask" or nothing.
function test_no_scenario_in_the_whole_suite_ever_returns_allow_or_deny() {
    local all_output=""
    all_output+=$(run_guard sweep1 Bash '{"command": "ls /tmp"}')
    all_output+=$(run_guard sweep2 Edit "$(jq -n --arg p "$HOME/.claude-work/CLAUDE.md" '{file_path: $p, old_string: "a", new_string: "b"}')" "$HOME/.claude-personal")
    all_output+=$(run_guard sweep3 Bash '{"command": "echo x > ~/.claude-work/plugins/guard-test-x"}' "$HOME/.claude-personal")
    all_output+=$(run_guard sweep4 Read "$(jq -n --arg p "$HOME/.claude-work/settings.json" '{file_path: $p}')" "$HOME/.claude-personal")
    all_output+=$(run_guard sweep5 Edit "$(jq -n --arg p "$HOME/.claude/rules/global-preferences.md" '{file_path: $p, old_string: "a", new_string: "b"}')")

    local bad_count
    bad_count=$(grep -cE '"(allow|deny)"' <<<"$all_output" || true)
    assert_same "0" "$bad_count"
}

#
# --- M severity ----------------------------------------------------------------
#

# Baseline (already correct): a live deployed path belonging to another profile asks.
function test_m1_profile_mismatch_is_flagged_for_live_deployed_path() {
    local out
    out=$(run_guard m1live Edit "$(jq -n --arg p "$HOME/.claude-work/CLAUDE.md" \
        '{file_path: $p, old_string: "a", new_string: "b"}')" "$HOME/.claude-personal")

    assert_same "ask" "$(decision "$out")"
}

# A chezmoi SOURCE-tree path ("dot_claude-<name>", no escaped dot) must reach the same
# mismatch logic as a live path.
function test_m1_profile_mismatch_is_flagged_for_chezmoi_source_tree_path() {
    local out
    out=$(run_guard m1src Edit "$(jq -n --arg p "$REPO_ROOT/home/dot_claude-work/.claude-settings.json" \
        '{file_path: $p, old_string: "a", new_string: "b"}')")

    assert_same "ask" "$(decision "$out")"
}

# Scope decision, not a defect: .claude.json is never chezmoi-managed in any profile, so
# this hook excludes it from mismatch detection regardless of which profile is active.
function test_m2_claude_json_is_out_of_scope_regardless_of_active_profile() {
    local out
    out=$(run_guard m2 Edit "$(jq -n --arg p "$HOME/.claude.json" \
        '{file_path: $p, old_string: "a", new_string: "b"}')" "$HOME/.claude-work")

    assert_empty "$out"
}

# An unrelated project's own .claude/ dir elsewhere on disk must not be mistaken for a
# profile dir.
function test_m3_unrelated_claude_substring_elsewhere_produces_no_output() {
    local out
    out=$(run_guard m3 Edit "$(jq -n --arg p "/tmp/guard-explore-m3/someproject/.claude/config.json" \
        '{file_path: $p, old_string: "a", new_string: "b"}')" "$HOME/.claude-work")

    assert_empty "$out"
}

# A trailing slash on CLAUDE_CONFIG_DIR must not false-flag a profile as mismatched against
# itself.
function test_m4_trailing_slash_on_claude_config_dir_does_not_false_flag_own_profile() {
    local out
    out=$(run_guard m4 Edit "$(jq -n --arg p "$HOME/.claude-personal/CLAUDE.md" \
        '{file_path: $p, old_string: "a", new_string: "b"}')" "$HOME/.claude-personal/")

    assert_empty "$out"
}
