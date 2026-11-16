#!/usr/bin/env bash
# shellcheck shell=bash
# Several payloads below deliberately single-quote a literal "$HOME" or
# "$CLAUDE_CONFIG_DIR" inside a JSON command string (H3a/H3b) -- that text is
# hook input data describing what the guard must parse verbatim, never
# something this test file itself should expand.
# shellcheck disable=SC2016
#
# bashunit suite for claude-tooling-write-guard's permission contract
# (openspec capability: claude-tooling-write-guard). Replaces the hand-rolled
# tests/test-claude-tooling-write-guard.sh.
#
# The guard is a chezmoi TEMPLATE, not a plain script, so it is rendered once
# per file (set_up_before_script) via tests/run-template into a scratch file
# and then executed as a whole script per test (never sourced -- it has no
# functions worth unit-testing in isolation, just a stdin->stdout contract).
#
# Isolation properties preserved from the suite this replaces:
#   - Session markers go to a fresh scratch TMPDIR per test (bashunit::temp_dir
#     in set_up), never the real $TMPDIR/claude-tooling-write-guard.
#   - The deployed ~/.local/bin copy of the guard is never run or modified.
#   - `chezmoi managed` / `chezmoi source-path` calls are real and read-only,
#     exactly as the guard itself performs them -- this deliberately runs
#     against this machine's real $HOME/.claude* profiles (all of which exist
#     here: default, bedrock, personal, work) and this repo's real source
#     tree, the same way the guard behaves for a real user. Nothing under
#     $HOME is ever written.
#   - CLAUDE_CONFIG_DIR is always passed explicitly (defaulting to
#     "$HOME/.claude" when a test doesn't care about profile), never
#     inherited from this shell's own environment, so results don't depend on
#     which profile happens to be active when the suite runs.
#
# Every test below was empirically verified against the CURRENT (unfixed)
# rendered guard before being written, per the bashunit skill's "verifying
# your own work" guidance. Tests tagged "known defect" in a comment are
# EXPECTED TO FAIL right now -- that is the correct, intended outcome: they
# assert the behavior the guard's own header documents as intended, not the
# bug. Do not weaken them to pass. Severity tags (H/M/L) match the review
# that produced them; they are not bashunit syntax.

function set_up_before_script() {
    TEST_FILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    REPO_ROOT="$(cd "$TEST_FILE_DIR/.." && pwd)"
    GUARD_RENDER_DIR="$(mktemp -d)"
    RENDERED_GUARD="$GUARD_RENDER_DIR/guard"
    "$TEST_FILE_DIR/run-template" \
        "$REPO_ROOT/home/dot_local/bin/executable_claude-tooling-write-guard.tmpl" \
        >"$RENDERED_GUARD"
    # Deliberately no tear_down_after_script: deleting this shared, read-only
    # fixture there would race other tests in this file under --parallel (see
    # the bashunit skill's "Traps" section). The scratch dir is small and left
    # for normal OS temp cleanup.
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

#
# --- Ported from the hand-rolled suite -------------------------------------
#

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

function test_bash_redirect_into_plugins_dir_asks() {
    local out
    out=$(run_guard s5 Bash '{"command": "echo x > ~/.claude/plugins/guard-test-x"}')

    assert_same "ask" "$(decision "$out")"
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

# Sweep invariant: re-runs a representative cross-section of the scenarios
# above and below and checks none of them ever emits an "allow" decision --
# the one invariant the guard's own header says must hold for every input.
function test_no_scenario_in_the_whole_suite_ever_returns_allow() {
    local all_output=""
    all_output+=$(run_guard sweep1 Bash '{"command": "python3 -c \"import json\" ~/.claude/settings.json"}')
    all_output+=$(run_guard sweep2 Bash '{"command": "jq . ~/.claude/settings.json"}')
    all_output+=$(run_guard sweep3 Edit "$(jq -n --arg p "$HOME/.claude/rules/global-preferences.md" '{file_path: $p, old_string: "a", new_string: "b"}')")
    all_output+=$(run_guard sweep4 Bash '{"command": "echo x > ~/.claude/plugins/guard-test-x"}')
    all_output+=$(run_guard sweep5 Bash '{"command": "ls /tmp"}')
    all_output+=$(run_guard sweep6 Bash '{"command": "chezmoi status ~/.claude/settings.json"}')
    all_output+=$(run_guard sweep7 Bash '{"command": "mv /tmp/new.json ~/.claude/settings.json && echo ok"}')
    all_output+=$(run_guard sweep8 Read "$(jq -n --arg p "$HOME/.claude-work/settings.json" '{file_path: $p}')")

    local allow_count
    allow_count=$(grep -c '"allow"' <<<"$all_output" || true)
    assert_same "0" "$allow_count"
}

#
# --- New: from code review (H severity) -------------------------------------
#

# H1a: mv's destination-extraction uses "${args##* }" (strip to the last
# space), but the regex that captures mv's own argument list keeps the space
# right before a trailing "&& ..." -- so the "last token" ends up being that
# trailing empty string, not the real destination, and the managed-file
# mutation is missed entirely. Known defect: currently falls through to the
# once-per-session informational note instead of denying.
function test_h1_managed_write_via_mv_followed_by_chain_is_still_denied() {
    local out
    out=$(run_guard h1a Bash '{"command": "mv /tmp/new.json ~/.claude/settings.json && echo ok"}')

    assert_same "deny" "$(decision "$out")"
}

# H1b: same root cause as H1a, in sed's destination extraction.
function test_h1_managed_write_via_sed_inplace_followed_by_chain_is_still_denied() {
    local out
    out=$(run_guard h1b Bash '{"command": "sed -i \"\" -e s/a/b/ ~/.claude/settings.json && echo done"}')

    assert_same "deny" "$(decision "$out")"
}

# H2: extract_bash_target's redirect check matches the FIRST ">" in the whole
# command and gives up if that one isn't a managed path, instead of
# continuing to look for a later ">" that is. Known defect: the real write to
# settings.json is never found because "2>/dev/null" is considered first.
function test_h2_earlier_unrelated_redirect_does_not_hide_later_managed_write() {
    local out
    out=$(run_guard h2 Bash '{"command": "rm -f /tmp/junk 2>/dev/null; cat /dev/null > ~/.claude/settings.json"}')

    assert_same "deny" "$(decision "$out")"
}

# H3a: a managed path wrapped in double quotes (e.g. "$HOME/.claude/...") is
# extracted WITH the quote characters attached, so realpath/chezmoi managed
# resolve against a path that doesn't exist and the write is classified as
# unmanaged. Known defect: falls through to the informational note.
function test_h3a_quoted_managed_path_in_bash_command_is_still_denied() {
    local out
    out=$(run_guard h3a Bash '{"command": "cat /dev/null > \"$HOME/.claude/settings.json\""}')

    assert_same "deny" "$(decision "$out")"
}

# H3b: the broad_pattern gate requires a literal ".claude" substring in the
# command text, so a write via $CLAUDE_CONFIG_DIR -- the generic way to refer
# to whichever profile is active -- is invisible to the guard from the very
# first check. Known defect: completely silent, not even an informational note.
function test_h3b_claude_config_dir_variable_target_is_detected() {
    local out
    out=$(run_guard h3b Bash '{"command": "cat /dev/null > $CLAUDE_CONFIG_DIR/settings.json"}')

    assert_same "deny" "$(decision "$out")"
}

# H4: check_path's Edit branch for settings.json only denies when old_string
# or new_string literally contains one of the protected key NAMES
# (permissions, hooks, etc). An edit that changes a value nested under
# "permissions" without the word "permissions" appearing anywhere in the
# diff text falls through every branch and produces no output at all. Known
# defect: completely silent.
function test_h4_edit_changing_nested_protected_value_without_key_literal_is_denied() {
    local out existing_entry old_string new_string
    # Derived from whatever this machine's own live settings.json actually
    # contains, rather than a hardcoded guess -- a literal string assumed
    # present (e.g. "Bash(git push:*)") can easily not match this machine's
    # real entry (e.g. "Bash(git push *)", no colon), which would make the
    # value-containment check correctly find nothing to flag for the WRONG
    # reason (a test data mismatch, not a guard defect).
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
# --- New: from code review (M severity) -------------------------------------
#

# M1 contrast (baseline, already correct): a LIVE deployed path belonging to
# another profile is flagged as a mismatch.
function test_m1_profile_mismatch_is_flagged_for_live_deployed_path() {
    local out
    out=$(run_guard m1live Edit "$(jq -n --arg p "$HOME/.claude-work/CLAUDE.md" \
        '{file_path: $p, old_string: "a", new_string: "b"}')" "$HOME/.claude-personal")

    assert_same "ask" "$(decision "$out")"
}

# M1: check_path's own entry gate requires a literal "/.claude.../" (an
# escaped dot) immediately in the path, which a chezmoi SOURCE-tree path
# never has -- it's "dot_claude-<name>", not ".claude-<name>". So a source
# path never even reaches the mismatch logic that path_profile() already
# supports for it. Known defect: completely silent instead of asking.
function test_m1_profile_mismatch_is_flagged_for_chezmoi_source_tree_path() {
    local out
    out=$(run_guard m1src Edit "$(jq -n --arg p "$REPO_ROOT/home/dot_claude-work/.claude-settings.json" \
        '{file_path: $p, old_string: "a", new_string: "b"}')")

    assert_same "ask" "$(decision "$out")"
}

# M2: ~/.claude.json has no trailing-slash form of ".claude/" or ".claude-x/"
# in it at all, so neither check_path's entry gate nor path_profile() ever
# recognizes it as belonging to the default profile. Known defect:
# completely silent instead of asking when another profile is active.
function test_m2_default_profile_claude_json_is_covered_by_mismatch_detection() {
    local out
    out=$(run_guard m2 Edit "$(jq -n --arg p "$HOME/.claude.json" \
        '{file_path: $p, old_string: "a", new_string: "b"}')" "$HOME/.claude-work")

    assert_same "ask" "$(decision "$out")"
}

# M3: path_profile()'s generic "/\.claude/" branch matches ANY path
# containing a ".claude/" directory anywhere, not just under $HOME -- so an
# unrelated project's own .claude/ dir under /tmp is wrongly classified as
# the "default" profile. Known defect: falsely asks about a profile mismatch
# for a path that has nothing to do with this machine's Claude Code profiles.
function test_m3_unrelated_claude_substring_elsewhere_produces_no_output() {
    local out
    out=$(run_guard m3 Edit "$(jq -n --arg p "/tmp/guard-explore-m3/someproject/.claude/config.json" \
        '{file_path: $p, old_string: "a", new_string: "b"}')" "$HOME/.claude-work")

    assert_empty "$out"
}

# M4: active_profile()'s regex capture for CLAUDE_CONFIG_DIR is greedy and
# includes a trailing slash in the captured name (e.g. "personal/" instead of
# "personal"), so it never string-equals path_profile()'s clean "personal"
# and a profile is falsely flagged as mismatched against itself. Known
# defect: falsely asks even though active and target are the same profile.
function test_m4_trailing_slash_on_claude_config_dir_does_not_false_flag_own_profile() {
    local out
    out=$(run_guard m4 Edit "$(jq -n --arg p "$HOME/.claude-personal/CLAUDE.md" \
        '{file_path: $p, old_string: "a", new_string: "b"}')" "$HOME/.claude-personal/")

    assert_empty "$out"
}

# M5: extract_bash_target's mv/cp handling only ever inspects the LAST
# argument (the destination), on the theory that cp's source is "merely
# read". For mv that's wrong: moving a managed file away is a mutation of
# its source location too. Known defect: a managed file moved away with an
# unmanaged destination produces no permission decision at all.
function test_m5_mv_of_managed_file_away_is_flagged() {
    local out
    out=$(run_guard m5mv Bash '{"command": "mv ~/.claude/rules/global-preferences.md /tmp/out.md"}')

    assert_not_same "none" "$(decision "$out")"
}

# M5 contrast (intended, already correct): cp's source is only read, so only
# the destination matters -- an unmanaged destination correctly produces no
# permission decision (just the informational fallback).
function test_m5_cp_of_managed_file_only_flags_the_destination() {
    local out
    out=$(run_guard m5cp Bash '{"command": "cp ~/.claude/rules/global-preferences.md /tmp/out.md"}')

    assert_same "none" "$(decision "$out")"
}

# M6a: the sed-target regex requires "-i" to be the literal first flag after
# "sed ", so "-E" (or any other flag) appearing before "-i" defeats it. Known
# defect: no permission decision.
function test_m6a_sed_inplace_detected_regardless_of_flag_order() {
    local out
    out=$(run_guard m6a Bash '{"command": "sed -E -i \"\" -e s/a/b/ ~/.claude/settings.json"}')

    assert_same "deny" "$(decision "$out")"
}

# M6b: the same regex only recognizes the short "-i" form, never
# "--in-place". Known defect: no permission decision.
function test_m6b_sed_inplace_detected_with_long_form_flag() {
    local out
    out=$(run_guard m6b Bash '{"command": "sed --in-place -e s/a/b/ ~/.claude/settings.json"}')

    assert_same "deny" "$(decision "$out")"
}

#
# --- New: from code review (L severity, real defects) -----------------------
#

# L1: when `chezmoi` isn't on PATH, `chezmoi managed ... 2>/dev/null` fails
# silently and check_path treats the file as unmanaged rather than failing
# safe. Known defect: a normally chezmoi-managed Edit produces no output at
# all instead of "ask".
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

# L2: extract_bash_target's tee/rm handling does `for tok in $args` on an
# UNQUOTED variable, which performs real pathname (glob) expansion against
# whatever files happen to exist on disk -- not just word splitting. A
# literal "*" elsewhere in the command can expand to an unrelated real
# filesystem entry that gets returned as "the" target, before the actual
# literal managed path later in the same command is ever examined. Known
# defect: the real settings.json write is missed because an unrelated decoy
# directory (planted purely to prove the point, matched only by accident of
# a glob) is returned first.
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

# L3: when a Bash command contains more than one ".claude"-looking candidate,
# extract_bash_target's redirect check returns the FIRST ">" match and stops
# even when that candidate isn't a real/consequential target (checked
# empirically against the current, unfixed guard -- this is NOT already
# fixed by anything else in this suite, so it is asserted as a real,
# currently-failing test rather than recorded as a todo). Known defect: the
# real settings.json write after it is never examined.
function test_l3_earlier_claude_looking_non_target_does_not_suppress_later_real_one() {
    local out
    out=$(run_guard l3 Bash '{"command": "echo discard 2> ~/.claude/notarealtarget.txt > ~/.claude/settings.json"}')

    assert_same "deny" "$(decision "$out")"
}

#
# --- Documented, accepted gaps (not defects) --------------------------------
#
# Each of these mutation shapes is knowingly NOT recognized by this
# best-effort heuristic guard. They are recorded here (via bashunit::todo)
# so the suite itself documents the guard's accepted boundary instead of
# silently omitting these cases. None is asserted to pass or fail.
#

function test_l4_cp_dash_t_is_a_known_unrecognized_mutation_shape() {
    bashunit::todo "cp -t DIR (fan-in copy) is not recognized; broad_pattern itself never matches this shape, so the guard is silent. Example: cp -t ~/.claude x.md"
}

function test_l4_install_is_a_known_unrecognized_mutation_shape() {
    bashunit::todo "install(1) writing a managed path is not recognized; falls to the informational fallback only. Example: install -m 644 x.md ~/.claude/settings.json"
}

function test_l4_ln_sf_is_a_known_unrecognized_mutation_shape() {
    bashunit::todo "ln -sf replacing a managed path is not recognized; falls to the informational fallback only. Example: ln -sf /tmp/x ~/.claude/settings.json"
}

function test_l4_perl_dash_i_is_a_known_unrecognized_mutation_shape() {
    bashunit::todo "perl -i in-place edit is not recognized; falls to the informational fallback only. Example: perl -i -pe 's/a/b/' ~/.claude/settings.json"
}

function test_l4_dd_of_is_a_known_unrecognized_mutation_shape() {
    bashunit::todo "dd of=TARGET is not recognized at all by extract_bash_target. Example: dd of=~/.claude/settings.json if=/tmp/x"
}

function test_l4_truncate_is_a_known_unrecognized_mutation_shape() {
    bashunit::todo "truncate is not recognized; falls to the informational fallback only. Example: truncate -s 0 ~/.claude/settings.json"
}

function test_l4_pipeline_ending_in_sponge_is_a_known_unrecognized_mutation_shape() {
    bashunit::todo "a pipeline ending in sponge(1) is not recognized by any of the mutation regexes. Example: cat x.json | sponge ~/.claude/settings.json"
}

function test_l4_cd_then_relative_redirect_is_a_known_unrecognized_mutation_shape() {
    bashunit::todo "cd DIR && echo x > relative-file is invisible: broad_pattern requires a literal '.claude' immediately adjacent to the write target, which a relative filename after a separate cd never has. Example: cd ~/.claude && echo x > settings.json"
}
