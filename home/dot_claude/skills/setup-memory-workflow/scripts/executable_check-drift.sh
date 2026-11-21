#!/usr/bin/env bash
# Pure inspection; explicit installation, scoped repair, and project consent.
# Hook commands intentionally retain literal environment expressions.
# shellcheck disable=SC2016
set -euo pipefail
# Shared diagnostics inspect LANG; hooks and isolated clients may omit it.
LANG=${LANG:-C}
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
ASSETS_DIR="$SKILL_DIR/assets"
# shellcheck source=home/dot_claude/skills/setup-memory-workflow/scripts/lib-messaging.sh
source "$SKILL_DIR/scripts/lib-messaging.sh"
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$PROJECT_ROOT"
PROJECT_ROOT=$(pwd -P)
# shellcheck source=home/dot_claude/skills/setup-memory-workflow/scripts/lib-project.sh
source "$SKILL_DIR/scripts/lib-project.sh"
PROJECT=$(resolve_project)
# shellcheck source=home/dot_claude/skills/setup-memory-workflow/scripts/lib-consent.sh
source "$SKILL_DIR/scripts/lib-consent.sh"
# shellcheck source=home/dot_claude/skills/setup-memory-workflow/scripts/lib-drift-warn.sh
source "$SKILL_DIR/scripts/lib-drift-warn.sh"
# shellcheck source=home/dot_claude/skills/setup-memory-workflow/scripts/lib-status-note.sh
source "$SKILL_DIR/scripts/lib-status-note.sh"
# shellcheck source=home/dot_claude/skills/setup-memory-workflow/scripts/lib-open-items.sh
source "$SKILL_DIR/scripts/lib-open-items.sh"
# shellcheck source=home/dot_claude/skills/setup-memory-workflow/scripts/lib-pieces.sh
source "$SKILL_DIR/scripts/lib-pieces.sh"
# shellcheck source=home/dot_claude/skills/setup-memory-workflow/scripts/lib-runtime.sh
source "$SKILL_DIR/scripts/lib-runtime.sh"
# shellcheck source=home/dot_claude/skills/setup-memory-workflow/scripts/migrations.sh
source "$SKILL_DIR/scripts/migrations.sh"
TEMPLATED_PIECE_NAMES=(save-session-skill save-session-maintenance-skill)
TEMPLATED_PIECE_PATHS=(.claude/skills/save-session/SKILL.md .claude/skills/save-session-maintenance/SKILL.md)
TEMPLATED_PIECE_TEMPLATES=("$ASSETS_DIR/save-session-skill.md.template" "$ASSETS_DIR/save-session-maintenance-skill.md.template")
# shellcheck source=home/dot_claude/skills/setup-memory-workflow/scripts/lib-hooks.sh
source "$SKILL_DIR/scripts/lib-hooks.sh"

validate_project_name() {
    # This workflow stores local projects under one directory; reject path traversal.
    if [ -z "$PROJECT" ] || [[ "$PROJECT" == */* ]] || [ "$PROJECT" = . ] || [ "$PROJECT" = .. ] || [[ "$PROJECT" == *$'\n'* ]]; then
        print_message error 'Invalid local project identity; resolve the override explicitly.'
        return 1
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

cmd_status_bloat() {
    validate_project_name
    local warning
    warning=$(check_status_note_bloat)
    if [ -n "$warning" ]; then
        print_message warning "$warning"
        return 1
    fi
    return 0
}

cmd_open_staleness() {
    validate_project_name
    local stale
    stale=$(stale_open_items)
    if [ -n "$stale" ]; then
        printf '%s\n' "$stale"
        return 1
    fi
    return 0
}

case "${1:-}" in
    check | install | update) cmd_run "$1" ;;
    apply) cmd_apply "${2:?Expected piece}" ;;
    drift-warn) check_drift_warn || true ;;
    status-bloat) cmd_status_bloat ;;
    open-staleness) cmd_open_staleness ;;
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
        print_message error 'Usage: check-drift.sh check|install|update|apply PIECE|drift-warn|status-bloat|open-staleness|consent status|grant|revoke|authorize PROJECT auto|once'
        exit 1
        ;;
esac
