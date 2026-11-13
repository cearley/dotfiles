# shellcheck shell=bash
# Read/modify only this checkout's workflow consent, never BM knowledge.
consent_valid() {
    jq -se 'length == 1 and (.[0] | type == "object" and (keys | sort) ==
    (["version","project","repository_root","automatic_recording","granted_at"] | sort)
    and (.version | type == "number") and .version == 1
    and (.project | type == "string" and length > 0)
    and (.repository_root | type == "string" and startswith("/"))
    and (.automatic_recording | type == "boolean")
    and (.granted_at | type == "string" and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$")))' "$1" >/dev/null 2>&1
}

consent_status() {
    local file="$PROJECT_ROOT/.basic-memory-workflow.json"
    if [ ! -e "$file" ]; then
        echo MISSING
        return
    fi
    if [ -L "$file" ] || ! consent_valid "$file"; then
        echo INVALID
        return
    fi
    if ! jq -e --arg p "$PROJECT" --arg r "$PROJECT_ROOT" \
        '.project == $p and .repository_root == $r' "$file" >/dev/null; then
        echo NAME-MISMATCH
        return
    fi
    if jq -e '.automatic_recording' "$file" >/dev/null; then echo GRANTED; else echo REVOKED; fi
}

consent_change() {
    local action="$1" file="$PROJECT_ROOT/.basic-memory-workflow.json" state tmp
    state=$(consent_status)
    case "$state" in
        INVALID | NAME-MISMATCH)
            print_message error "Consent is $state; preserve it and resolve the record explicitly before granting."
            return 1
            ;;
    esac
    [ "$action" = grant ] || [ "$action" = revoke ] || return 1
    if [ "$action" = revoke ] && [ "$state" = MISSING ]; then
        echo 'CONSENT: MISSING (already disabled)'
        return
    fi
    tmp=$(mktemp "$file.tmp.XXXXXX") || return 1
    if [ "$action" = grant ]; then
        jq -n --arg p "$PROJECT" --arg r "$PROJECT_ROOT" --arg t "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
            '{version:1, project:$p, repository_root:$r, automatic_recording:true, granted_at:$t}' >"$tmp"
    else
        jq '.automatic_recording = false' "$file" >"$tmp"
    fi
    if ! consent_valid "$tmp" || ! chmod 600 "$tmp" || ! mv -f "$tmp" "$file"; then
        rm -f "$tmp"
        return 1
    fi
    printf 'CONSENT: %s — %s → %s (%s)\n' "$(consent_status)" "$PROJECT_ROOT" "$PROJECT" "$file"
}

authorize_save() {
    local expected="$1" mode="$2" installed=".claude/skills/save-session/SKILL.md" identity version
    [ "$mode" = auto ] || [ "$mode" = once ] || return 1
    if [ "$PROJECT" != "$expected" ] || [ ! -f "$installed" ]; then
        print_message error "Save scope does not match this installed project ($PROJECT_ROOT → $PROJECT)."
        return 1
    fi
    identity=$(sed -n 's/^<!-- setup-memory-workflow-project:\(.*\) -->$/\1/p' "$installed")
    version=$(sed -n 's/.*setup-memory-workflow-version:\([0-9]*\).*/\1/p' "$installed")
    if [ "$identity" != "$expected" ] || [ "$version" != "$SMW_VERSION" ]; then
        print_message error 'Installed skill identity is missing or mismatched; explicitly update it first.'
        return 1
    fi
    if [ "$mode" = auto ] && [ "$(consent_status)" != GRANTED ]; then
        print_message warning "Automatic recording denied: $(consent_status). Ask for a save or explicit project consent."
        return 1
    fi
    echo "AUTHORIZED: $mode ($PROJECT_ROOT → $PROJECT)"
}
