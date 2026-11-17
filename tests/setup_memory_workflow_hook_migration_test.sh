#!/usr/bin/env bash
# Fixture command strings below are literal hook data, never evaluated here.
# shellcheck disable=SC2016
# bashunit coverage for lib-pieces.sh's hook_owned_commands()/hook_piece_apply(),
# guarding the migration that collapses the old two-part SessionStart hook
# command into the new single-script one (fix-save-session-redundancy).
#
# Regression: hook_owned_commands()'s "old" signature for session-reminder.sh
# was built from unquoted path segments, but the actually-deployed v20-v22
# combined command quotes each path segment individually. Dogfooding this
# change on a real installation left BOTH the old and new commands in
# settings.local.json (session-reminder.sh firing twice) because the old
# string was never recognized as "ours" to remove. Fixed by also recognizing
# the quoted form. These tests exercise hook_piece_apply() directly against
# a fixture settings file carrying that real historical string.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS_DIR="$REPO_ROOT/home/dot_claude/skills/setup-memory-workflow/scripts"

function set_up_before_script() {
    # hook_piece_apply only calls print_message on failure paths this suite
    # never exercises, but it must exist in scope for lib-pieces.sh to source.
    # shellcheck disable=SC2329
    print_message() { :; }
    # shellcheck source=home/dot_claude/skills/setup-memory-workflow/scripts/lib-pieces.sh
    source "$SCRIPTS_DIR/lib-pieces.sh"
}

HOOK_BASE='${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/setup-memory-workflow/scripts/'
NEW_CMD="\"${HOOK_BASE}session-reminder.sh\""
OLD_QUOTED_COMBINED_CMD="\"${HOOK_BASE}session-reminder.sh\"; \"${HOOK_BASE}check-drift.sh\" drift-warn 2>/dev/null || true"

function set_up() {
    SCRATCH="$(bashunit::temp_dir)"
    SETTINGS="$SCRATCH/settings.local.json"
}

function write_fixture_with_old_combined_hook() {
    jq -n --arg old "$OLD_QUOTED_COMBINED_CMD" '{
    hooks: {
      SessionStart: [
        {matcher: "", hooks: [{type: "command", command: $old}]},
        {matcher: "", hooks: [{type: "command", command: "\"${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/setup-memory-workflow/scripts/crash-recovery-hook.sh\""}]}
      ]
    }
  }' >"$SETTINGS"
}

function test_hook_owned_commands_recognizes_the_real_old_combined_string() {
    local owned
    owned=$(hook_owned_commands session-reminder.sh "$NEW_CMD")
    local found=0
    jq -e --arg c "$OLD_QUOTED_COMBINED_CMD" 'index($c) != null' <<<"$owned" >/dev/null && found=1
    assert_same "1" "$found"
}

function test_apply_replaces_old_combined_hook_with_single_new_command() {
    write_fixture_with_old_combined_hook
    hook_piece_apply "$SETTINGS" SessionStart "" session-reminder.sh "$NEW_CMD"
    local reminder_hits
    reminder_hits=$(jq '[.hooks.SessionStart[].hooks[] | select(.command | contains("session-reminder.sh"))] | length' "$SETTINGS")
    assert_same "1" "$reminder_hits"
    local reminder_cmd
    reminder_cmd=$(jq -r '.hooks.SessionStart[].hooks[] | select(.command | contains("session-reminder.sh")) | .command' "$SETTINGS")
    assert_same "$NEW_CMD" "$reminder_cmd"
}

function test_apply_preserves_unrelated_crash_recovery_hook() {
    write_fixture_with_old_combined_hook
    hook_piece_apply "$SETTINGS" SessionStart "" session-reminder.sh "$NEW_CMD"
    local crash_hits
    crash_hits=$(jq '[.hooks.SessionStart[].hooks[] | select(.command | contains("crash-recovery-hook.sh"))] | length' "$SETTINGS")
    assert_same "1" "$crash_hits"
}

function test_status_after_migration_is_up_to_date_not_ambiguous() {
    write_fixture_with_old_combined_hook
    hook_piece_apply "$SETTINGS" SessionStart "" session-reminder.sh "$NEW_CMD"
    local state
    state=$(hook_piece_status "$SETTINGS" SessionStart "" session-reminder.sh "$NEW_CMD")
    assert_same "UP-TO-DATE" "$state"
}
