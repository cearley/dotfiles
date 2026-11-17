#!/usr/bin/env bash
# shellcheck shell=bash
# H3a/H3b below single-quote a literal "$HOME"/"$CLAUDE_CONFIG_DIR" inside a JSON command
# string -- that's hook input data the guard must parse verbatim, not something this file
# should expand.
# shellcheck disable=SC2016
#
# bashunit suite for claude-tooling-write-guard's permission contract (openspec capability:
# claude-tooling-write-guard), scoped to this hook's one tier (chezmoi-managed-file
# protection). Profile-mismatch detection was a sibling hook here (tests formerly in
# tests/claude-profile-mismatch-guard_test.sh); retired 2026-11-17 in favor of the
# ccenv-profile-guard mod in the separate zsh-claude-env project.
#
# The guard is a chezmoi TEMPLATE: rendered once (set_up_before_script) via tests/run-template
# into a scratch file, then executed as a whole script per test (stdin->stdout contract,
# never sourced).
#
# Isolation:
#   - Session markers go to a fresh scratch TMPDIR per test, never the real one.
#   - The deployed ~/.local/bin copy is never run or modified.
#   - `chezmoi managed`/`source-path` calls are real and read-only, against this machine's
#     actual $HOME/.claude* profiles and this repo's real source tree -- nothing under $HOME
#     is ever written.
#   - CLAUDE_CONFIG_DIR is always passed explicitly, never inherited, so results don't depend
#     on which profile is active when the suite runs.
#
# Severity tags (H/M/L) label which regression each test guards against; not bashunit syntax.

function set_up_before_script() {
    TEST_FILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    REPO_ROOT="$(cd "$TEST_FILE_DIR/.." && pwd)"
    GUARD_RENDER_DIR="$(mktemp -d)"
    RENDERED_GUARD="$GUARD_RENDER_DIR/guard"
    "$TEST_FILE_DIR/run-template" \
        "$REPO_ROOT/home/dot_local/bin/executable_claude-tooling-write-guard.tmpl" \
        >"$RENDERED_GUARD"
    # No tear_down_after_script: deleting this shared fixture would race other tests under
    # --parallel. Small scratch dir, left for normal OS temp cleanup.
}

function set_up() {
    guard_tmp_dir="$(bashunit::temp_dir)"
}

# run_guard <session_id> <tool_name> <tool_input-json> [CLAUDE_CONFIG_DIR]
function run_guard() {
    local session="$1" tool="$2" tool_input="$3" config_dir="${4:-$HOME/.claude}"
    local payload
    payload=$(jq -n --arg s "$session" --arg t "$tool" --argjson i "$tool_input" \
        '{session_id: $s, tool_name: $t, tool_input: $i}')
    CLAUDE_CONFIG_DIR="$config_dir" TMPDIR="$guard_tmp_dir" bash "$RENDERED_GUARD" <<<"$payload"
}

# decision <guard-stdout>
function decision() {
    jq -r '.hookSpecificOutput.permissionDecision // "none"' <<<"${1:-{\}}"
}

function test_unclassified_bash_write_emits_note_without_permission_decision() {
    local out
    out=$(run_guard s1 Bash '{"command": "python3 -c \"import json\" ~/.claude/settings.json"}')

    assert_not_empty "$out"
    assert_same "none" "$(decision "$out")"
    assert_json_key_exists ".hookSpecificOutput.additionalContext" "$out"
}

function test_bash_read_of_managed_path_never_allows() {
    local out
    out=$(run_guard s2 Bash '{"command": "jq . ~/.claude/settings.json"}')

    assert_not_same "allow" "$(decision "$out")"
}

function test_informational_note_fires_once_per_session() {
    local first second
    first=$(run_guard s3 Bash '{"command": "cat ~/.claude/settings.json"}')
    second=$(run_guard s3 Bash '{"command": "cat ~/.claude/settings.json"}')

    assert_not_empty "$first"
    assert_empty "$second"
}

function test_edit_of_chezmoi_managed_file_is_denied() {
    local out
    out=$(run_guard s4 Edit "$(jq -n --arg p "$HOME/.claude/rules/global-preferences.md" \
        '{file_path: $p, old_string: "a", new_string: "b"}')")

    assert_same "deny" "$(decision "$out")"
}

# plugins/skills drift isn't this guard's job (clean-claude-orphans/check-claude-overrides),
# so a same-profile plugins/ write just falls through to the informational fallback.
function test_bash_redirect_into_plugins_dir_falls_to_informational_note() {
    local out
    out=$(run_guard s5 Bash '{"command": "echo x > ~/.claude/plugins/guard-test-x"}')

    assert_same "none" "$(decision "$out")"
    assert_json_key_exists ".hookSpecificOutput.additionalContext" "$out"
}

function test_unrelated_bash_command_produces_no_output() {
    local out
    out=$(run_guard s6 Bash '{"command": "ls /tmp"}')

    assert_empty "$out"
}

function test_chezmoi_add_force_of_profile_settings_is_denied() {
    local cmd out
    cmd="chezmoi add --force ~/.claude-personal/settings.json"
    out=$(run_guard s7a Bash "$(jq -n --arg c "$cmd" '{command: $c}')")

    assert_same "deny" "$(decision "$out")"
}

function test_chezmoi_readd_of_profile_settings_with_cd_prefix_is_denied() {
    local cmd out
    cmd="cd /tmp && chezmoi re-add ~/.claude/settings.json"
    out=$(run_guard s7b Bash "$(jq -n --arg c "$cmd" '{command: $c}')")

    assert_same "deny" "$(decision "$out")"
}

function test_chezmoi_status_of_settings_json_is_not_denied() {
    local out
    out=$(run_guard s8 Bash '{"command": "chezmoi status ~/.claude/settings.json"}')

    assert_not_same "deny" "$(decision "$out")"
}

# Sweep: re-runs a cross-section of the scenarios above/below and checks none ever emits
# "allow" -- the one invariant that must hold for every input.
function test_no_scenario_in_the_whole_suite_ever_returns_allow() {
    local all_output=""
    all_output+=$(run_guard sweep1 Bash '{"command": "python3 -c \"import json\" ~/.claude/settings.json"}')
    all_output+=$(run_guard sweep2 Bash '{"command": "jq . ~/.claude/settings.json"}')
    all_output+=$(run_guard sweep3 Edit "$(jq -n --arg p "$HOME/.claude/rules/global-preferences.md" '{file_path: $p, old_string: "a", new_string: "b"}')")
    all_output+=$(run_guard sweep4 Bash '{"command": "echo x > ~/.claude/plugins/guard-test-x"}')
    all_output+=$(run_guard sweep5 Bash '{"command": "ls /tmp"}')
    all_output+=$(run_guard sweep6 Bash '{"command": "chezmoi status ~/.claude/settings.json"}')
    all_output+=$(run_guard sweep7 Bash '{"command": "mv /tmp/new.json ~/.claude/settings.json && echo ok"}')

    local allow_count
    allow_count=$(grep -c '"allow"' <<<"$all_output" || true)
    assert_same "0" "$allow_count"
}

#
# --- H severity --------------------------------------------------------------
#

# mv target followed by a trailing && chain -- argument-list scoping must not swallow past it.
function test_h1_managed_write_via_mv_followed_by_chain_is_still_denied() {
    local out
    out=$(run_guard h1a Bash '{"command": "mv /tmp/new.json ~/.claude/settings.json && echo ok"}')

    assert_same "deny" "$(decision "$out")"
}

# Same shape as above, for sed -i's target.
function test_h1_managed_write_via_sed_inplace_followed_by_chain_is_still_denied() {
    local out
    out=$(run_guard h1b Bash '{"command": "sed -i \"\" -e s/a/b/ ~/.claude/settings.json && echo done"}')

    assert_same "deny" "$(decision "$out")"
}

# An earlier unrelated redirect (e.g. 2>/dev/null) must not hide a later real one.
function test_h2_earlier_unrelated_redirect_does_not_hide_later_managed_write() {
    local out
    out=$(run_guard h2 Bash '{"command": "rm -f /tmp/junk 2>/dev/null; cat /dev/null > ~/.claude/settings.json"}')

    assert_same "deny" "$(decision "$out")"
}

# A quoted managed path (e.g. "$HOME/.claude/...") must still resolve once quotes are stripped.
function test_h3a_quoted_managed_path_in_bash_command_is_still_denied() {
    local out
    out=$(run_guard h3a Bash '{"command": "cat /dev/null > \"$HOME/.claude/settings.json\""}')

    assert_same "deny" "$(decision "$out")"
}

# $CLAUDE_CONFIG_DIR is the generic way to reference the active profile and must be detected,
# not just a literal "~/.claude" path.
function test_h3b_claude_config_dir_variable_target_is_detected() {
    local out
    out=$(run_guard h3b Bash '{"command": "cat /dev/null > $CLAUDE_CONFIG_DIR/settings.json"}')

    assert_same "deny" "$(decision "$out")"
}

# A value nested under a managed key is denied even without the key's literal name appearing
# in the diff text.
function test_h4_edit_changing_nested_protected_value_without_key_literal_is_denied() {
    local out existing_entry old_string new_string
    # Derived from this machine's real settings.json rather than a hardcoded guess, which
    # could miss for a test-data reason unrelated to the guard (e.g. no colon in the entry).
    existing_entry=$(jq -r '(.permissions.ask // .permissions.allow // [])[0] // ""' "$HOME/.claude/settings.json")
    if [[ -z "$existing_entry" ]]; then
        bashunit::skip "no existing permissions.ask/allow entry on this machine to build a realistic edit from"
        return
    fi
    old_string=$(jq -nr --arg v "$existing_entry" '$v | tojson')
    new_string=$(jq -nr --arg v "$existing_entry" --arg extra "Bash(git push --force:*)" \
        '($v | tojson) + ",\n    " + ($extra | tojson)')
    out=$(run_guard h4 Edit "$(jq -n --arg p "$HOME/.claude/settings.json" --arg old "$old_string" --arg new "$new_string" \
        '{file_path: $p, old_string: $old, new_string: $new}')")

    assert_same "deny" "$(decision "$out")"
}

#
# --- M severity ---------------------------------------------------------------
# M1-M4 (profile mismatch) belonged to the retired claude-profile-mismatch-guard hook; see
# ccenv-profile-guard's own test suite in the separate zsh-claude-env project instead.
#

# Moving a managed file away is a mutation of its source location too, not just its
# destination.
function test_m5_mv_of_managed_file_away_is_flagged() {
    local out
    out=$(run_guard m5mv Bash '{"command": "mv ~/.claude/rules/global-preferences.md /tmp/out.md"}')

    assert_not_same "none" "$(decision "$out")"
}

# Contrast: cp's source is merely read, so only the destination matters.
function test_m5_cp_of_managed_file_only_flags_the_destination() {
    local out
    out=$(run_guard m5cp Bash '{"command": "cp ~/.claude/rules/global-preferences.md /tmp/out.md"}')

    assert_same "none" "$(decision "$out")"
}

# sed -i must be detected regardless of flag order (-E before -i, etc).
function test_m6a_sed_inplace_detected_regardless_of_flag_order() {
    local out
    out=$(run_guard m6a Bash '{"command": "sed -E -i \"\" -e s/a/b/ ~/.claude/settings.json"}')

    assert_same "deny" "$(decision "$out")"
}

# The long-form --in-place must be detected too, not just -i.
function test_m6b_sed_inplace_detected_with_long_form_flag() {
    local out
    out=$(run_guard m6b Bash '{"command": "sed --in-place -e s/a/b/ ~/.claude/settings.json"}')

    assert_same "deny" "$(decision "$out")"
}

#
# --- L severity -----------------------------------------------------------
#

# chezmoi unavailable must fail safe with ask, not silently treat the file as unmanaged.
function test_l1_chezmoi_unavailable_fails_safe_with_ask() {
    local no_chezmoi_path
    no_chezmoi_path="$(bashunit::temp_dir)"
    local tool
    for tool in bash jq grep mkdir find dirname basename touch cat realpath; do
        local real_path
        real_path="$(command -v "$tool")"
        ln -sf "$real_path" "$no_chezmoi_path/$tool"
    done

    local payload out
    payload=$(jq -n --arg s "l1" --arg t Edit --argjson i "$(jq -n --arg p "$HOME/.claude/rules/global-preferences.md" \
        '{file_path: $p, old_string: "a", new_string: "b"}')" \
        '{session_id: $s, tool_name: $t, tool_input: $i}')
    out=$(PATH="$no_chezmoi_path" CLAUDE_CONFIG_DIR="$HOME/.claude" TMPDIR="$guard_tmp_dir" bash "$RENDERED_GUARD" <<<"$payload")

    assert_same "ask" "$(decision "$out")"
}

# A literal "*" in the command text must not trigger real glob expansion against the
# filesystem.
function test_l2_literal_asterisk_does_not_trigger_real_glob_expansion() {
    local decoy_root decoy_dir
    decoy_root="$(bashunit::temp_dir)"
    decoy_dir="$decoy_root/evil-glob-hit-marker.claude-fake"
    mkdir -p "$decoy_dir"
    touch "$decoy_dir/placeholder"

    local cmd out
    cmd="rm $decoy_root/*/placeholder ~/.claude/settings.json"
    out=$(run_guard l2 Bash "$(jq -n --arg c "$cmd" '{command: $c}')")

    assert_same "deny" "$(decision "$out")"
    assert_not_contains "evil-glob-hit-marker" "$out"
}

# An earlier non-target ".claude"-looking candidate must not suppress a later real one.
function test_l3_earlier_claude_looking_non_target_does_not_suppress_later_real_one() {
    local out
    out=$(run_guard l3 Bash '{"command": "echo discard 2> ~/.claude/notarealtarget.txt > ~/.claude/settings.json"}')

    assert_same "deny" "$(decision "$out")"
}

# Closed by the verb-rule-table redesign: each became a one-line table entry.
function test_l4_install_target_is_denied() {
    local out
    out=$(run_guard l4install Bash '{"command": "install -m 644 x.md ~/.claude/settings.json"}')

    assert_same "deny" "$(decision "$out")"
}

function test_l4_ln_sf_target_is_denied() {
    local out
    out=$(run_guard l4lnsf Bash '{"command": "ln -sf /tmp/x ~/.claude/settings.json"}')

    assert_same "deny" "$(decision "$out")"
}

function test_l4_perl_dash_i_target_is_denied() {
    local out
    out=$(run_guard l4perl Bash "$(jq -n --arg c "perl -i -pe 's/a/b/' ~/.claude/settings.json" '{command: $c}')")

    assert_same "deny" "$(decision "$out")"
}

function test_l4_dd_of_target_is_denied() {
    local out
    out=$(run_guard l4dd Bash '{"command": "dd of=~/.claude/settings.json if=/tmp/x"}')

    assert_same "deny" "$(decision "$out")"
}

function test_l4_truncate_target_is_denied() {
    local out
    out=$(run_guard l4trunc Bash '{"command": "truncate -s 0 ~/.claude/settings.json"}')

    assert_same "deny" "$(decision "$out")"
}

function test_l4_sponge_pipeline_target_is_denied() {
    local out
    out=$(run_guard l4sponge Bash '{"command": "cat x.json | sponge ~/.claude/settings.json"}')

    assert_same "deny" "$(decision "$out")"
}

#
# --- Documented, accepted gaps (not defects) --------------------------------
# Both need computation the verb-rule table deliberately doesn't attempt (see the table's
# own comment in the guard script).
#

function test_l4_cp_dash_t_is_a_known_unrecognized_mutation_shape() {
    bashunit::todo "cp -t DIR (fan-in copy): the real target is DIR joined with each source's basename, which no rule shape computes -- the table's 'last' rule for cp instead picks the last SOURCE token, a false negative no worse than the old behavior. Example: cp -t ~/.claude x.md"
}

function test_l4_cd_then_relative_redirect_is_a_known_unrecognized_mutation_shape() {
    bashunit::todo "cd DIR && echo x > relative-file is invisible: this hook has no notion of an implied working directory carried across '&&', so a relative filename after a separate cd never resolves against it. Example: cd ~/.claude && echo x > settings.json"
}
