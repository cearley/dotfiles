# shellcheck shell=bash
# Literal shell expressions below are hook command data, never evaluated here.
# shellcheck disable=SC2016
# Hook piece table and per-piece handler; sourced by check-drift.sh.
HOOK_PIECE_NAMES=(hook-config write-guard-hook crash-recovery-hook)
HOOK_PIECE_EVENTS=(SessionStart PreToolUse SessionStart)
HOOK_PIECE_MATCHERS=("" 'Bash|Edit|Write' "")
HOOK_PIECE_SCRIPTS=(session-reminder.sh basic-memory-write-guard.sh crash-recovery-hook.sh)
HOOK_BASE='${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/setup-memory-workflow/scripts/'
HOOK_PIECE_CMDS=("\"${HOOK_BASE}session-reminder.sh\"" "\"${HOOK_BASE}basic-memory-write-guard.sh\"" "\"${HOOK_BASE}crash-recovery-hook.sh\"")

hook_handle() {
    local mode="$1" i="$2" state file=.claude/settings.local.json
    state=$(hook_piece_status "$file" "${HOOK_PIECE_EVENTS[$i]}" "${HOOK_PIECE_MATCHERS[$i]}" "${HOOK_PIECE_SCRIPTS[$i]}" "${HOOK_PIECE_CMDS[$i]}")
    printf '%s: %s\n' "$state" "${HOOK_PIECE_NAMES[$i]}"
    if [ "$state" = INVALID ]; then return 1; fi
    if [ "$mode" != check ] && { [ "$state" = MISSING ] || { [ "$mode" = update ] && [ "$state" = DRIFT ]; }; }; then
        hook_piece_apply "$file" "${HOOK_PIECE_EVENTS[$i]}" "${HOOK_PIECE_MATCHERS[$i]}" "${HOOK_PIECE_SCRIPTS[$i]}" "${HOOK_PIECE_CMDS[$i]}"
    fi
    # Familiar names alone never establish ownership; surface retained ambiguity.
    if [ -f "$file" ] && jq -e --arg s "${HOOK_PIECE_SCRIPTS[$i]}" \
        --argjson owned "$(hook_owned_commands "${HOOK_PIECE_SCRIPTS[$i]}" "${HOOK_PIECE_CMDS[$i]}")" \
        '[.hooks[][]?.hooks[]?.command // empty | select(contains($s)) |
          select(. as $c | ($owned | index($c)) == null)] | length > 0' "$file" >/dev/null; then
        print_message warning "AMBIGUOUS: familiar ${HOOK_PIECE_SCRIPTS[$i]} text preserved."
    fi
}
