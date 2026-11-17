# shellcheck shell=bash
# lib-drift-warn.sh — sourced by both check-drift.sh and
# executable_session-reminder.sh. Holds the single SMW_VERSION marker and
# the drift-warn check, so SessionStart can run the check in-process instead
# of exec'ing check-drift.sh as a second subprocess that re-sources every
# library a second time (fix-save-session-redundancy).
#
# Contract: requires $PROJECT_ROOT and $PROJECT already set by the caller,
# and print_message (and, by the time check_drift_warn is called,
# consent_status from lib-consent.sh) already defined. Read-only, never
# errors. Add a CHANGELOG.md entry alongside any change here.

SMW_VERSION=23

# Warns when the installed save-session skill is older than this version, or
# when automatic recording is not GRANTED. Always exits 0; callers that want
# the pre-refactor hook behavior (no visible output) still need to redirect
# stderr themselves, same as the standalone `check-drift.sh drift-warn`
# caller always has.
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
