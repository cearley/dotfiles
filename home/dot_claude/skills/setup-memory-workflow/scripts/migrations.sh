# shellcheck shell=bash
# Literal shell expressions below are hook command data, never evaluated here.
# shellcheck disable=SC2016
# Exact owned legacy shapes, invoked only inside explicit mutation dispatch.
# v1-v18 used echo of a SYSTEM REMINDER, with the workflow version marker.
# Single/double quote delimiters and the v17-v18 exact drift-warn tail are accepted.
legacy_reminder_owned() {
    local cmd="$1" body quote tail=""
    case "$cmd" in
        "echo '"*)
            quote="'"
            body=${cmd#"echo '"}
            ;;
        'echo "'*)
            quote='"'
            body=${cmd#'echo "'}
            ;;
        *) return 1 ;;
    esac
    case "$body" in
        *"$quote"';&'*) return 1 ;;
    esac
    # Split only at the known trailing shell wrapper, never execute the command.
    case "$body" in
        *"$quote"'; "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/setup-memory-workflow/scripts/check-drift.sh" drift-warn 2>/dev/null || true')
            tail='; "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/setup-memory-workflow/scripts/check-drift.sh" drift-warn 2>/dev/null || true'
            body=${body%"$tail"}
            ;;
    esac
    [ "${body%"$quote"}" != "$body" ] || return 1
    body=${body%"$quote"}
    case "$body" in
        'SYSTEM REMINDER: This is the '*" project."* | \
            'SYSTEM REMINDER (background context for the '*" project, tracked in basic-memory"*) ;;
        *) return 1 ;;
    esac
    [[ "$body" =~ \[setup-memory-workflow-version:[0-9]+\] ]] || return 1
    # Echo content is single quoted in actual legacy installs (escaped apostrophes
    # use the shell '\'' sequence). Refuse unrecognized executable suffixes.
    if [ "$quote" = "'" ]; then
        body=${body//"'\\''"/}
        [[ "$body" != *"'"* ]] || return 1
    else
        [[ "$body" != *'"'* ]] || return 1
    fi
}

migrate_reminder_hooks() {
    local file=.claude/settings.local.json commands encoded cmd owned='[]' tmp
    [ -f "$file" ] || return 0
    settings_valid "$file" || return 1
    commands=$(jq -c '[.hooks.SessionStart[]?.hooks[]?.command, .hooks.UserPromptSubmit[]?.hooks[]?.command] | map(select(type == "string"))' "$file")
    while IFS= read -r encoded; do
        cmd=$(jq -r . <<<"$encoded")
        if legacy_reminder_owned "$cmd"; then
            owned=$(jq --arg cmd "$cmd" '. + [$cmd]' <<<"$owned")
        fi
    done < <(jq -c '.[]' <<<"$commands")
    [ "$owned" != '[]' ] || return 0
    tmp=$(mktemp "$file.tmp.XXXXXX") || return 1
    if jq --argjson owned "$owned" '
        def ours: .command as $c | ($owned | index($c)) != null;
        .hooks |= with_entries(if (.key == "SessionStart" or .key == "UserPromptSubmit") then
          .value |= map(. as $before | .hooks |= map(select(ours | not)) |
            select((.hooks | length) > 0 or ($before.hooks | any(ours) | not)))
          else . end)' "$file" >"$tmp" && mv -f "$tmp" "$file"; then
        echo 'MIGRATED: recognized owned legacy reminder'
    else
        rm -f "$tmp"
        return 1
    fi
}

migrate_sync_memory() {
    local skill=.claude/skills/sync-memory/SKILL.md
    [ -e .claude/skills/sync-memory ] || return 0
    # A path alone is not ownership. Marker plus actual old skill name is required.
    if [ -f "$skill" ] && [ ! -L .claude/skills/sync-memory ] &&
        grep -qx 'name: sync-memory' "$skill" &&
        grep -Eq '^<!-- setup-memory-workflow-version:[0-9]+ -->$' "$skill"; then
        rm -rf .claude/skills/sync-memory
        rm -f .specstory/.sync-memory-state.json
        echo 'MIGRATED: owned retired sync-memory artifacts'
    else
        print_message warning 'Preserved ambiguous retired sync-memory content; review manually.'
    fi
}
