# shellcheck shell=bash
# Literal shell expressions below are hook command data, never evaluated here.
# shellcheck disable=SC2016
# Pure status functions; only explicit apply functions write.
render() {
    local content
    content=$(cat "$1")
    content=${content//__PROJECT__/$PROJECT}
    content=${content//__SMW_VERSION__/$SMW_VERSION}
    printf '%s\n' "$content"
}

piece_status() {
    local installed="$1" marker identity
    [ -f "$installed" ] || {
        echo MISSING
        return
    }
    marker=$(sed -n 's/.*setup-memory-workflow-version:\([0-9]*\).*/\1/p' "$installed")
    identity=$(sed -n 's/^<!-- setup-memory-workflow-project:\(.*\) -->$/\1/p' "$installed")
    # Pre-v20 pieces have no identity marker: accept only exact known project arguments.
    if [ -z "$identity" ]; then
        if grep -qF "project=\"$PROJECT\"" "$installed" || grep -qF "project: \"$PROJECT\"" "$installed"; then
            identity="$PROJECT"
        fi
    fi
    if [ "$identity" != "$PROJECT" ]; then
        echo NAME-MISMATCH
    elif [ "$marker" = "$SMW_VERSION" ]; then
        echo UP-TO-DATE
    else echo DRIFT; fi
}

apply_templated_file() {
    local installed="$1" template="$2" tmp
    mkdir -p "$(dirname "$installed")"
    tmp=$(mktemp "$installed.tmp.XXXXXX") || return 1
    if render "$template" >"$tmp" && mv -f "$tmp" "$installed"; then
        echo "APPLIED: $installed"
    else
        rm -f "$tmp"
        return 1
    fi
}

report_templated_piece() {
    local state
    state=$(piece_status "$1")
    printf '%s: %s\n' "$state" "$1"
    case "$state" in
        DRIFT) echo '  repair with explicit update' ;;
        MISSING) echo '  create with explicit install' ;;
        NAME-MISMATCH) echo '  never auto-repaired; confirm identity before apply' ;;
    esac
}

update_templated_piece() {
    local name="$1" installed="$2" template="$3" mode="${4:-update}" state
    state=$(piece_status "$installed")
    case "$state:$mode" in
        MISSING:install | MISSING:update | DRIFT:update) apply_templated_file "$installed" "$template" ;;
        *) printf '%s: %s\n' "$state" "$name" ;;
    esac
}

settings_valid() {
    [ -e "$1" ] || return 0
    jq -se 'length == 1 and (.[0] | type == "object" and
      ((.hooks // {}) | type == "object" and all(.[]; type == "array" and
        all(.[]; type == "object" and (.hooks | type == "array" and
          all(.[]; type == "object"))))))' "$1" >/dev/null 2>&1
}

# Exact known script invocations, not filename/product-name substring matches.
# The canonical command is quoted; v19's unquoted invocation is explicitly recognized.
hook_owned_commands() {
    local script="$1" canonical="$2" base literal old quoted
    base='${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/setup-memory-workflow/scripts/'
    literal="$base$script"
    quoted="\"$literal\""
    old="$literal"
    if [ "$script" = session-reminder.sh ]; then
        old="$literal; ${base}check-drift.sh drift-warn 2>/dev/null || true"
    fi
    printf '%s\n' "$canonical" "$old" "$literal" "$quoted" \
        "$HOME/.claude/skills/setup-memory-workflow/scripts/$script" \
        "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/setup-memory-workflow/scripts/$script" |
        jq -Rs 'split("\n") | map(select(length > 0)) | unique'
}

hook_piece_status() {
    local file="$1" event="$2" matcher="$3" script="$4" cmd="$5" owned
    [ -f "$file" ] || {
        echo MISSING
        return
    }
    settings_valid "$file" || {
        echo INVALID
        return
    }
    owned=$(hook_owned_commands "$script" "$cmd")
    jq -r --argjson owned "$owned" --arg ev "$event" --arg mt "$matcher" --arg cmd "$cmd" '
      [(.hooks // {} | to_entries[]) as $e | $e.value[] as $g | $g.hooks[] |
        select(.command as $c | $owned | index($c)) |
        {event:$e.key, matcher:($g.matcher // ""), hook:.}] as $hits |
      if ($hits | length) == 0 then "MISSING"
      elif ($hits | length) == 1 and $hits[0].event == $ev and
        $hits[0].matcher == $mt and $hits[0].hook.type == "command" and
        $hits[0].hook.command == $cmd then "UP-TO-DATE"
      else "DRIFT" end' "$file"
}

hook_piece_apply() {
    local file="$1" event="$2" matcher="$3" script="$4" cmd="$5" owned tmp
    settings_valid "$file" || {
        print_message error "Invalid hook settings: $file"
        return 1
    }
    [ "$(hook_piece_status "$file" "$event" "$matcher" "$script" "$cmd")" = UP-TO-DATE ] && return 0
    owned=$(hook_owned_commands "$script" "$cmd")
    mkdir -p "$(dirname "$file")"
    tmp=$(mktemp "$file.tmp.XXXXXX") || return 1
    # Drop only owned hooks. Keep foreign siblings, group metadata, and relative order.
    if jq -n --argjson data "$(cat "$file" 2>/dev/null || echo '{}')" \
        --argjson owned "$owned" --arg ev "$event" --arg mt "$matcher" --arg cmd "$cmd" '
      def ours: .command as $c | ($owned | index($c)) != null;
      $data | .hooks = ((.hooks // {}) | with_entries(.value |= map(
        . as $before | .hooks |= map(select(ours | not)) |
        select((.hooks | length) > 0 or ($before.hooks | any(ours) | not))))) |
      .hooks[$ev] = ((.hooks[$ev] // []) + [{matcher:$mt, hooks:[{type:"command", command:$cmd}]}])' >"$tmp" &&
        mv -f "$tmp" "$file"; then
        echo "APPLIED: $script"
    else
        rm -f "$tmp"
        return 1
    fi
}
