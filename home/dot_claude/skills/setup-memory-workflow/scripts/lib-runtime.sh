# shellcheck shell=bash
# Read persisted config directly: BM CLI discovery can initialize/migrate state.
bm_version_check() {
    local version
    if ! command_exists basic-memory; then
        print_message error "MISSING: install with uv tool install 'basic-memory>=1,<2'"
        return 1
    fi
    version=$(basic-memory --version 2>/dev/null) || return 1
    if ! [[ "$version" =~ (^|[[:space:]])1\.[0-9]+\.[0-9]+([[:space:]]|$) ]]; then
        print_message error "INCOMPATIBLE: $version; require stable BM 1.x (uv tool install 'basic-memory>=1,<2')."
        return 1
    fi
    printf 'BM: %s\n' "$version"
}

bm_registration() {
    local file data entry path mode
    if [ -n "${BASIC_MEMORY_PROJECT_ROOT:-}" ]; then
        echo UNKNOWN
        return
    fi
    file="${BASIC_MEMORY_CONFIG_DIR:-${XDG_CONFIG_HOME:+$XDG_CONFIG_HOME/basic-memory}}/config.json"
    [ "$file" != /config.json ] || file="$HOME/.basic-memory/config.json"
    if [ -n "${BASIC_MEMORY_PROJECTS:-}" ]; then
        data=$(jq -nc --argjson p "$BASIC_MEMORY_PROJECTS" '{projects:$p}' 2>/dev/null) || {
            echo INVALID
            return
        }
    elif [ -e "$file" ]; then
        data=$(cat "$file")
    else
        echo MISSING
        return
    fi
    jq -se 'length == 1 and (.[0] | type == "object" and ((.projects // {}) | type == "object"))' >/dev/null 2>&1 <<<"$data" || {
        echo INVALID
        return
    }
    entry=$(jq -c --arg p "$PROJECT" '.projects[$p] // null' <<<"$data")
    [ "$entry" != null ] || {
        echo MISSING
        return
    }
    path=$(jq -r 'if type == "string" then . else .path // empty end' <<<"$entry" 2>/dev/null) || {
        echo INVALID
        return
    }
    mode=$(jq -r 'if type == "object" then .mode // "local" else "local" end' <<<"$entry")
    if [ -z "$path" ] || { [ "$mode" != local ] && [ "$mode" != cloud ]; }; then
        echo INVALID
        return
    fi
    if [ "$mode" = cloud ]; then
        echo 'CUSTOM: cloud routing preserved'
    elif [ "$path" != "$HOME/.local/share/basic-memory/$PROJECT" ]; then
        printf 'CUSTOM: %s (default-path excerpt may be unavailable)\n' "$path"
    else echo REGISTERED; fi
}

ensure_registration() {
    local state
    state=$(bm_registration)
    case "$state" in
        MISSING) basic-memory project add "$PROJECT" "$HOME/.local/share/basic-memory/$PROJECT" ;;
        INVALID | UNKNOWN)
            print_message error "Registration $state; resolve configuration explicitly before install."
            return 1
            ;;
        *) printf 'REGISTRATION: %s\n' "$state" ;;
    esac
}

# Honor effective scope without running `claude mcp list` or probing network servers.
# A custom registration is preserved and reported, never assumed compatible.
mcp_location() {
    local profile file entry scope
    profile="${CLAUDE_CONFIG_DIR:+$CLAUDE_CONFIG_DIR/.claude.json}"
    profile="${profile:-$HOME/.claude.json}"
    MCP_FILE=.mcp.json
    MCP_VALUE=''
    MCP_SCOPE=missing
    for file in "$profile" .mcp.json; do
        [ -e "$file" ] || continue
        jq -se 'length == 1 and (.[0] | type == "object" and
          ((.mcpServers // {}) | type == "object"))' "$file" >/dev/null 2>&1 || {
            MCP_SCOPE=invalid
            MCP_FILE="$file"
            return
        }
    done
    # Claude CLI precedence is local (profile.projects[root]), project, user.
    # Project configuration cannot override a local-scope entry.
    for scope in local project user; do
        if [ "$scope" = project ]; then file=.mcp.json; else file="$profile"; fi
        [ -f "$file" ] || continue
        case "$scope" in
            local) entry=$(jq -c --arg r "$PROJECT_ROOT" '.projects[$r].mcpServers["basic-memory"] // empty' "$file") || {
                MCP_SCOPE=invalid
                return
            } ;;
            project | user) entry=$(jq -c '.mcpServers["basic-memory"] // empty' "$file") ;;
        esac
        if [ -n "$entry" ]; then
            MCP_FILE="$file"
            MCP_VALUE="$entry"
            MCP_SCOPE="$scope"
            return
        fi
    done
}

apply_mcp_piece() {
    local file=.mcp.json tmp
    if [ -f "$file" ]; then
        jq -se 'length == 1 and (.[0] | type == "object" and ((.mcpServers // {}) | type == "object"))' "$file" >/dev/null || return 1
    fi
    tmp=$(mktemp "$file.tmp.XXXXXX") || return 1
    if jq -n --argjson data "$(cat "$file" 2>/dev/null || echo '{}')" \
        '$data | .mcpServers["basic-memory"] = {command:"basic-memory",args:["mcp"]}' >"$tmp" && mv -f "$tmp" "$file"; then
        echo 'APPLIED: .mcp.json'
    else
        rm -f "$tmp"
        return 1
    fi
}

mcp_piece_handle() {
    local mode="$1"
    mcp_location
    case "$MCP_SCOPE" in
        invalid)
            print_message error "INVALID: $MCP_FILE"
            return 1
            ;;
        missing)
            if [ "$mode" = check ]; then
                echo 'MISSING: MCP configuration (explicit install to create)'
            else apply_mcp_piece; fi
            ;;
        *)
            if jq -e '. == {command:"basic-memory",args:["mcp"]}' >/dev/null <<<"$MCP_VALUE"; then
                echo "UP-TO-DATE: MCP ($MCP_SCOPE: $MCP_FILE; verify connected tools in agent)"
            else
                echo "CUSTOM: MCP ($MCP_SCOPE: $MCP_FILE) preserved; verify connected BM 1.x tools; review the winning scope explicitly; apply mcp-config only replaces the project entry (local scope still wins)."
            fi
            ;;
    esac
}
