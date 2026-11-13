#!/usr/bin/env bash
# Pure inspection; explicit installation, scoped repair, and project consent.
# Hook commands intentionally retain literal environment expressions.
# shellcheck disable=SC2016
set -euo pipefail
# Shared diagnostics inspect LANG; hooks and isolated clients may omit it.
LANG=${LANG:-C}
SMW_VERSION=20
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
ASSETS_DIR="$SKILL_DIR/assets"
# shellcheck source=home/scripts/shared-utils.sh
source "$SKILL_DIR/../../../scripts/shared-utils.sh"
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$PROJECT_ROOT"
PROJECT_ROOT=$(pwd -P)
# shellcheck source=home/dot_claude/skills/setup-memory-workflow/scripts/lib-project.sh
source "$SKILL_DIR/scripts/lib-project.sh"
PROJECT=$(resolve_project)
# shellcheck source=home/dot_claude/skills/setup-memory-workflow/scripts/lib-consent.sh
source "$SKILL_DIR/scripts/lib-consent.sh"
# shellcheck source=home/dot_claude/skills/setup-memory-workflow/scripts/lib-pieces.sh
source "$SKILL_DIR/scripts/lib-pieces.sh"
# shellcheck source=home/dot_claude/skills/setup-memory-workflow/scripts/lib-runtime.sh
source "$SKILL_DIR/scripts/lib-runtime.sh"
# shellcheck source=home/dot_claude/skills/setup-memory-workflow/scripts/migrations.sh
source "$SKILL_DIR/scripts/migrations.sh"
TEMPLATED_PIECE_NAMES=(save-session-skill save-session-maintenance-skill)
TEMPLATED_PIECE_PATHS=(.claude/skills/save-session/SKILL.md .claude/skills/save-session-maintenance/SKILL.md)
TEMPLATED_PIECE_TEMPLATES=("$ASSETS_DIR/save-session-skill.md.template" "$ASSETS_DIR/save-session-maintenance-skill.md.template")
HOOK_PIECE_NAMES=(hook-config write-guard-hook crash-recovery-hook)
HOOK_PIECE_EVENTS=(SessionStart PreToolUse SessionStart)
HOOK_PIECE_MATCHERS=("" 'Bash|Edit|Write' "")
HOOK_PIECE_SCRIPTS=(session-reminder.sh basic-memory-write-guard.sh crash-recovery-hook.sh)
HOOK_BASE='${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/setup-memory-workflow/scripts/'
HOOK_PIECE_CMDS=("\"${HOOK_BASE}session-reminder.sh\"; \"${HOOK_BASE}check-drift.sh\" drift-warn 2>/dev/null || true" "\"${HOOK_BASE}basic-memory-write-guard.sh\"" "\"${HOOK_BASE}crash-recovery-hook.sh\"")

validate_project_name() {
    # This workflow stores local projects under one directory; reject path traversal.
    if [ -z "$PROJECT" ] || [[ "$PROJECT" == */* ]] || [ "$PROJECT" = . ] || [ "$PROJECT" = .. ] || [[ "$PROJECT" == *$'\n'* ]]; then
        print_message error 'Invalid local project identity; resolve the override explicitly.'
        return 1
    fi
}

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

cmd_run() {
    local mode="$1" i
    validate_project_name
    settings_valid .claude/settings.local.json || {
        print_message error 'INVALID: .claude/settings.local.json'
        return 1
    }
    if [ "$mode" = check ]; then
        bm_version_check || true
        printf 'REGISTRATION: %s\n' "$(bm_registration)"
    else
        bm_version_check
        if [ "$mode" = install ]; then ensure_registration; fi
        migrate_reminder_hooks
        migrate_sync_memory
    fi
    for i in "${!TEMPLATED_PIECE_NAMES[@]}"; do
        if [ "$mode" = check ]; then
            report_templated_piece "${TEMPLATED_PIECE_PATHS[$i]}"
        else update_templated_piece "${TEMPLATED_PIECE_NAMES[$i]}" "${TEMPLATED_PIECE_PATHS[$i]}" "${TEMPLATED_PIECE_TEMPLATES[$i]}" "$mode"; fi
    done
    mcp_piece_handle "$mode"
    for i in "${!HOOK_PIECE_NAMES[@]}"; do hook_handle "$mode" "$i"; done
    printf 'CONSENT: %s (install/update never grant recording)\n' "$(consent_status)"
}

cmd_apply() {
    local piece="$1" i
    validate_project_name
    bm_version_check
    for i in "${!TEMPLATED_PIECE_NAMES[@]}"; do
        if [ "$piece" = "${TEMPLATED_PIECE_NAMES[$i]}" ]; then
            apply_templated_file "${TEMPLATED_PIECE_PATHS[$i]}" "${TEMPLATED_PIECE_TEMPLATES[$i]}"
            return
        fi
    done
    for i in "${!HOOK_PIECE_NAMES[@]}"; do
        if [ "$piece" = "${HOOK_PIECE_NAMES[$i]}" ]; then
            settings_valid .claude/settings.local.json || return 1
            if [ "$piece" = hook-config ]; then migrate_reminder_hooks; fi
            hook_piece_apply .claude/settings.local.json "${HOOK_PIECE_EVENTS[$i]}" "${HOOK_PIECE_MATCHERS[$i]}" "${HOOK_PIECE_SCRIPTS[$i]}" "${HOOK_PIECE_CMDS[$i]}"
            return
        fi
    done
    if [ "$piece" = mcp-config ]; then
        apply_mcp_piece
        return
    fi
    print_message error "Unknown piece: $piece"
    return 1
}

cmd_drift_warn() {
    local file=.claude/skills/save-session/SKILL.md version
    [ -f "$file" ] || return 0
    version=$(sed -n 's/.*setup-memory-workflow-version:\([0-9]*\).*/\1/p' "$file")
    if [[ "$version" =~ ^[0-9]+$ ]] && [ "$version" -lt "$SMW_VERSION" ]; then
        print_message warning "save-session v$version < v$SMW_VERSION; inspect with check before explicit update."
    fi
    if [ "$(consent_status)" != GRANTED ]; then
        print_message warning "Automatic recording disabled: $(consent_status). Explicit save or project consent required."
    fi
}

case "${1:-}" in
    check | install | update) cmd_run "$1" ;;
    apply) cmd_apply "${2:?Expected piece}" ;;
    drift-warn) cmd_drift_warn || true ;;
    consent)
        validate_project_name
        case "${2:-status}" in
            status) printf 'CONSENT: %s\n' "$(consent_status)" ;;
            grant | revoke) consent_change "$2" ;;
            *) exit 1 ;;
        esac
        ;;
    authorize)
        validate_project_name
        authorize_save "${2:?Expected project}" "${3:?Expected auto or once}"
        ;;
    *)
        print_message error 'Usage: check-drift.sh check|install|update|apply PIECE|drift-warn|consent status|grant|revoke|authorize PROJECT auto|once'
        exit 1
        ;;
esac
