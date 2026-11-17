# shellcheck shell=bash
# lib-drift-warn.sh — sourced by check-drift.sh and session-reminder.sh.
# Holds the single SMW_VERSION marker and the drift-warn check, so
# SessionStart can run it in-process instead of exec'ing check-drift.sh as
# a second subprocess.
#
# Contract: requires $PROJECT_ROOT, $PROJECT, print_message, and (by call
# time) lib-consent.sh's consent_status already in scope. Read-only, never
# errors. Add a CHANGELOG.md entry alongside any change here.

SMW_VERSION=24

# Warns when the installed skill is outdated or recording isn't GRANTED.
# Always exits 0; silence requires redirecting stderr, same as the
# standalone `check-drift.sh drift-warn` command.
check_drift_warn() {
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
