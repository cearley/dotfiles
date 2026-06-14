#!/bin/bash
# audit-packages.sh — List packages installed on this machine but not declared in packages.yaml.
# Read-only: never installs, removes, or modifies any package state.
# Usage: audit-packages [--strict] [--help]
#   --strict   Exit non-zero when at least one orphan is found
#   --help     Print this usage message

set -euo pipefail

# Resolve the real script path even when invoked through a symlink
_REAL_SCRIPT="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null || readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$_REAL_SCRIPT")" && pwd)"
unset _REAL_SCRIPT
# shellcheck source=./shared-utils.sh
source "${SCRIPT_DIR}/shared-utils.sh"

PACKAGES_YAML="${SCRIPT_DIR}/../.chezmoidata/packages.yaml"
STRICT=false
TOTAL_ORPHANS=0
MANAGERS_WITH_ORPHANS=0
ACTIVE_TAGS=()

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
for arg in "$@"; do
    case "$arg" in
        --strict) STRICT=true ;;
        --help|-h)
            echo "Usage: audit-packages [--strict] [--help]"
            echo ""
            echo "Lists packages installed on this machine but not declared in packages.yaml."
            echo "Read-only: never installs, removes, or modifies any package state."
            echo ""
            echo "Options:"
            echo "  --strict   Exit non-zero when at least one orphan is found"
            echo "  --help     Print this message"
            exit 0
            ;;
        *)
            print_message "error" "Unknown argument: $arg"
            exit 1
            ;;
    esac
done

# ---------------------------------------------------------------------------
# Prerequisites
# ---------------------------------------------------------------------------
require_yq() {
    if ! command_exists yq; then
        print_message "error" "yq is required but not found. Install it with: brew install yq"
        exit 1
    fi
}

require_chezmoi() {
    if ! command_exists chezmoi; then
        print_message "error" "chezmoi is required but not found in PATH"
        exit 1
    fi
    if [[ ! -f "$PACKAGES_YAML" ]]; then
        print_message "error" "packages.yaml not found at: $PACKAGES_YAML"
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# Read active tags from chezmoi config
# ---------------------------------------------------------------------------
read_active_tags() {
    local tags_json
    if ! tags_json=$(chezmoi data --format=json 2>/dev/null | jq -r '.tags // empty'); then
        print_message "error" "Failed to read chezmoi data. Is chezmoi initialized?"
        exit 1
    fi

    # core is always active (chezmoi installs it regardless of tag selection)
    ACTIVE_TAGS+=("core")

    while IFS= read -r tag; do
        [[ -n "$tag" ]] && ACTIVE_TAGS+=("$tag")
    done < <(echo "$tags_json" | jq -r '.[]? // empty' 2>/dev/null || echo "$tags_json" | tr ',' '\n' | tr -d '[]" ')
}

has_tag() {
    local needle="$1"
    for t in "${ACTIVE_TAGS[@]}"; do
        [[ "$t" == "$needle" ]] && return 0
    done
    return 1
}

# ---------------------------------------------------------------------------
# Collect the declared set for a given key across all active tags
# ---------------------------------------------------------------------------
declared_for() {
    local key="$1"
    local tmp
    tmp=$(mktemp)

    for tag in "${ACTIVE_TAGS[@]}"; do
        yq ".packages.darwin.${tag}.${key}[]?" "$PACKAGES_YAML" 2>/dev/null >> "$tmp" || true
    done

    sort -u "$tmp"
    rm -f "$tmp"
}

# ---------------------------------------------------------------------------
# Collect the declared set for a given key under a specific coding agent
# ---------------------------------------------------------------------------
declared_for_agent() {
    local agent="$1" key="$2"
    yq ".packages.darwin.ai.agents.${agent}.${key}[]?" "$PACKAGES_YAML" 2>/dev/null | sort -u
}

# ---------------------------------------------------------------------------
# Normalisation helpers — strip version/flag suffixes before comparison
# ---------------------------------------------------------------------------

# Normalize a UV tool spec to just the tool name:
#   "git+https://github.com/org/repo@latest"  → repo
#   "-p 3.13 package@latest --prerelease=..."  → package
#   "package@latest" / "package==1.0"          → package
normalize_uv_spec() {
    local spec="$1"
    # git+ URL: extract repo name (last path segment, strip @ref)
    if [[ "$spec" =~ ^git\+ ]]; then
        spec=$(echo "$spec" | sed -E 's|.*/([^/@]+)(@.*)?$|\1|')
        echo "$spec"; return
    fi
    # -p X.Y prefix
    spec=$(echo "$spec" | sed -E 's/^-p [0-9]+\.[0-9]+[[:space:]]*//')
    # trailing --flags
    spec=$(echo "$spec" | sed -E 's/[[:space:]]+--[[:space:]]*.*//')
    # @version or ==version suffix
    spec=$(echo "$spec" | sed -E 's/(@|==)[^[:space:]]*//')
    # trim whitespace, grab first word
    echo "$spec" | awk '{print $1}'
}

# Normalize a Bun package spec: strip @version suffix (handle scoped @org/pkg@ver)
normalize_bun_spec() {
    local spec="$1"
    # For scoped packages (@org/pkg@ver): strip the last @version
    # For normal packages (pkg@ver): strip @version
    echo "$spec" | sed -E 's/@[^@]+$//'
}

# Normalize a Cargo install spec to the crate name:
#   "--git https://... crate-name"  → crate-name (last word)
#   "crate-name"                    → crate-name
normalize_cargo_spec() {
    local spec="$1"
    if [[ "$spec" =~ ^--git ]]; then
        echo "$spec" | awk '{print $NF}'
    else
        echo "$spec" | awk '{print $1}'
    fi
}

# ---------------------------------------------------------------------------
# Core report helper — compare sorted installed vs declared; print orphans
# ---------------------------------------------------------------------------
report_orphans() {
    local label="$1"
    local installed_file="$2"   # sorted list of installed items
    local declared_file="$3"    # list of declared items (will be sorted internally)

    print_message "info" "=== ${label} ==="

    local sorted_declared orphans orphan_count
    sorted_declared=$(mktemp)
    sort "$declared_file" > "$sorted_declared"

    orphans=$(comm -23 "$installed_file" "$sorted_declared" || true)
    rm -f "$sorted_declared"

    if [[ -z "$orphans" ]]; then
        print_message "success" "No orphans"
    else
        echo "$orphans"
        orphan_count=$(echo "$orphans" | wc -l | tr -d '[:space:]')
        TOTAL_ORPHANS=$((TOTAL_ORPHANS + orphan_count))
        MANAGERS_WITH_ORPHANS=$((MANAGERS_WITH_ORPHANS + 1))
    fi
}

# ---------------------------------------------------------------------------
# Section 2: Homebrew
# ---------------------------------------------------------------------------
audit_brews() {
    local installed declared
    installed=$(mktemp)
    declared=$(mktemp)

    # Installed-on-request formulae; -r flag available since Homebrew 3.x
    if brew leaves -r &>/dev/null; then
        brew leaves -r 2>/dev/null | sort > "$installed"
    else
        brew list --installed-on-request 2>/dev/null | sort > "$installed"
    fi

    declared_for "brews" > "$declared"
    report_orphans "Homebrew Formulae" "$installed" "$declared"
    rm -f "$installed" "$declared"
}

audit_casks() {
    local installed declared
    installed=$(mktemp)
    declared=$(mktemp)

    brew list --cask -1 2>/dev/null | sort > "$installed"
    declared_for "casks" > "$declared"
    report_orphans "Homebrew Casks" "$installed" "$declared"
    rm -f "$installed" "$declared"
}

audit_taps() {
    local installed declared
    installed=$(mktemp)
    declared=$(mktemp)

    brew tap 2>/dev/null | sort > "$installed"

    # Union of top-level darwin taps plus per-tag taps
    {
        yq '.packages.darwin.taps[]?' "$PACKAGES_YAML" 2>/dev/null || true
        declared_for "taps"
    } | sort -u > "$declared"

    report_orphans "Homebrew Taps" "$installed" "$declared"
    rm -f "$installed" "$declared"
}

audit_homebrew() {
    if ! command_exists brew; then
        print_message "skip" "Homebrew not found — skipping brew sections"
        return
    fi
    audit_brews
    audit_casks
    audit_taps
}

# ---------------------------------------------------------------------------
# Section 3: Language ecosystems
# ---------------------------------------------------------------------------
audit_uv() {
    print_message "info" "=== UV Tools ==="
    if ! command_exists uv; then
        print_message "skip" "uv not found"
        return
    fi

    # Installed: first word of non-indented lines (tool names, not binary aliases)
    local installed declared_raw installed_file declared_file
    installed=$(uv tool list 2>/dev/null | grep -v '^\s*-' | awk '{print $1}' | sort)
    installed_file=$(mktemp)
    echo "$installed" > "$installed_file"

    # Declared: normalize each spec to tool name
    declared_raw=$(declared_for "uv")
    declared_file=$(mktemp)
    while IFS= read -r spec; do
        [[ -z "$spec" ]] && continue
        normalize_uv_spec "$spec"
    done <<< "$declared_raw" | sort -u > "$declared_file"

    local orphans orphan_count
    orphans=$(comm -23 "$installed_file" "$declared_file" || true)
    if [[ -z "$orphans" ]]; then
        print_message "success" "No orphans"
    else
        echo "$orphans"
        orphan_count=$(echo "$orphans" | wc -l | tr -d '[:space:]')
        TOTAL_ORPHANS=$((TOTAL_ORPHANS + orphan_count))
        MANAGERS_WITH_ORPHANS=$((MANAGERS_WITH_ORPHANS + 1))
    fi
    rm -f "$installed_file" "$declared_file"
}

audit_bun() {
    print_message "info" "=== Bun Global Packages ==="
    if ! command_exists bun; then
        print_message "skip" "bun not found"
        return
    fi

    # Installed: parse tree output (├── or └── pkg@ver → pkg)
    local installed declared_raw installed_file declared_file
    installed_file=$(mktemp)
    bun pm ls -g 2>/dev/null \
        | sed -nE 's/^[├└]── (.*)/\1/p' \
        | sed -E 's/@[^@]+$//' \
        | sort > "$installed_file"

    declared_raw=$(declared_for "bun")
    declared_file=$(mktemp)
    while IFS= read -r spec; do
        [[ -z "$spec" ]] && continue
        normalize_bun_spec "$spec"
    done <<< "$declared_raw" | sort -u > "$declared_file"

    local orphans orphan_count
    orphans=$(comm -23 "$installed_file" "$declared_file" || true)
    if [[ -z "$orphans" ]]; then
        print_message "success" "No orphans"
    else
        echo "$orphans"
        orphan_count=$(echo "$orphans" | wc -l | tr -d '[:space:]')
        TOTAL_ORPHANS=$((TOTAL_ORPHANS + orphan_count))
        MANAGERS_WITH_ORPHANS=$((MANAGERS_WITH_ORPHANS + 1))
    fi
    rm -f "$installed_file" "$declared_file"
}

audit_cargo() {
    if ! command_exists cargo; then
        print_message "info" "=== Cargo Crates ==="
        print_message "skip" "cargo not found"
        return
    fi

    # Installed: lines ending in ":" contain "crate vX.Y.Z [(...)]:"
    local installed_file declared_file
    installed_file=$(mktemp)
    cargo install --list 2>/dev/null \
        | grep ':$' \
        | awk '{print $1}' \
        | sort > "$installed_file"

    local declared_raw
    declared_raw=$(declared_for "cargo")
    declared_file=$(mktemp)
    while IFS= read -r spec; do
        [[ -z "$spec" ]] && continue
        normalize_cargo_spec "$spec"
    done <<< "$declared_raw" | sort -u > "$declared_file"

    report_orphans "Cargo Crates" "$installed_file" "$declared_file"
    rm -f "$installed_file" "$declared_file"
}

audit_sdkman() {
    print_message "info" "=== SDKMAN ==="
    if ! has_tag "dev"; then
        print_message "skip" "dev tag not active"
        return
    fi
    if [[ ! -d "${HOME}/.sdkman/candidates" ]]; then
        print_message "skip" "SDKMAN candidates directory not found"
        return
    fi

    # Declared: build a set of "candidate version" and bare "candidate" entries
    local declared_raw
    declared_raw=$(yq '.packages.darwin.dev.sdkman[]?' "$PACKAGES_YAML" 2>/dev/null || true)

    local orphan_count=0
    local has_orphans=false

    # Enumerate installed candidate/version pairs (skip "current" symlinks)
    for cand_dir in "${HOME}/.sdkman/candidates"/*/; do
        [[ -d "$cand_dir" ]] || continue
        local cand
        cand=$(basename "$cand_dir")
        for ver_dir in "${cand_dir}"*/; do
            [[ -d "$ver_dir" ]] || continue
            local ver
            ver=$(basename "$ver_dir")
            [[ "$ver" == "current" ]] && continue
            local item="${cand} ${ver}"

            # Check: declared as exact "candidate version"?
            if echo "$declared_raw" | grep -qxF "$item"; then
                continue
            fi
            # Check: declared as bare "candidate" (any version accepted)?
            if echo "$declared_raw" | grep -qxF "$cand"; then
                continue
            fi

            echo "$item"
            orphan_count=$((orphan_count + 1))
            has_orphans=true
        done
    done

    if [[ "$has_orphans" == "false" ]]; then
        print_message "success" "No orphans"
    else
        TOTAL_ORPHANS=$((TOTAL_ORPHANS + orphan_count))
        MANAGERS_WITH_ORPHANS=$((MANAGERS_WITH_ORPHANS + 1))
    fi
}

# ---------------------------------------------------------------------------
# Section 4: Claude Code
# ---------------------------------------------------------------------------
audit_claude_plugins() {
    local installed_file declared_file
    installed_file=$(mktemp)
    declared_file=$(mktemp)

    # Installed: .id field from JSON (e.g. "atlassian@claude-plugins-official")
    if claude plugins list --json 2>/dev/null | jq -r '.[].id' 2>/dev/null | sort > "$installed_file"; then
        : # JSON succeeded
    else
        # Fallback: parse text output (lines containing "@")
        claude plugins list 2>/dev/null \
            | grep -oE '[a-zA-Z0-9_-]+@[a-zA-Z0-9_-]+' \
            | sort > "$installed_file"
    fi

    declared_for_agent "claude_code" "plugins" | sort > "$declared_file"
    report_orphans "Claude Code Plugins" "$installed_file" "$declared_file"
    rm -f "$installed_file" "$declared_file"
}

audit_claude_marketplaces() {
    local installed_file declared_file
    installed_file=$(mktemp)
    declared_file=$(mktemp)

    # Installed: for github sources → repo field; for git sources → url field
    # Compare against declared entries (repo strings or URLs, stripping #ref)
    if claude plugins marketplace list --json 2>/dev/null | \
        jq -r '.[] | if .source == "github" then .repo else .url end' 2>/dev/null | \
        sort > "$installed_file"; then
        : # JSON succeeded
    else
        # Fallback: just list names from text output
        claude plugins marketplace list 2>/dev/null \
            | grep -E '^\s+❯' \
            | awk '{print $2}' \
            | sort > "$installed_file"
    fi

    # Declared: strip #ref from URL entries (e.g. "https://...#dev" → "https://...")
    declared_for_agent "claude_code" "plugin_marketplaces" \
        | sed 's/#[^#]*$//' \
        | sort > "$declared_file"

    report_orphans "Claude Code Plugin Marketplaces" "$installed_file" "$declared_file"
    rm -f "$installed_file" "$declared_file"
}

# Derive a skill-name prefix from a collection-wildcard spec:
#   extract the org component (before /) and strip known company suffixes,
#   then strip trailing hyphens/underscores.
#   e.g. "specstoryai/agent-skills -all" → "specstory"
_wildcard_prefix() {
    local spec="$1"
    local org
    org=$(echo "$spec" | cut -d'/' -f1)
    echo "$org" \
        | sed -E 's/(ai|hq|io|dev|co|labs|inc|app|apps|tech|ware|js|ly)$//' \
        | sed -E 's/[-_]+$//'
}

audit_claude_skills() {
    print_message "info" "=== Claude Code Skills ==="

    local skills_dir="${HOME}/.claude/skills"
    if [[ ! -d "$skills_dir" ]]; then
        print_message "skip" "No user-scope skills directory found at ${skills_dir}"
        return
    fi

    local declared_specs
    declared_specs=$(declared_for_agent "claude_code" "skills")

    # --- Pass 1: derive known skill names from deterministic specs ---
    # Deterministic rules:
    #   <owner>/skills/<name>    → skill name is the last path segment
    #   <spec> --skill <name>    → skill name from the flag value
    # Any spec that matches neither rule is a collection wildcard.
    local known_skills=""   # newline-delimited list
    local wildcards=""      # newline-delimited list

    while IFS= read -r spec; do
        [[ -z "$spec" ]] && continue
        local matched=false

        # Path-style: */skills/<name>
        if [[ "$spec" =~ ^[^[:space:]]*/skills/([^[:space:]/]+) ]]; then
            known_skills="${known_skills}${BASH_REMATCH[1]}"$'\n'
            matched=true
        fi

        # --skill <name> flag (may appear multiple times in one spec)
        local tmp="$spec"
        while [[ "$tmp" =~ --skill[[:space:]]+([^[:space:]]+) ]]; do
            known_skills="${known_skills}${BASH_REMATCH[1]}"$'\n'
            tmp="${tmp/"${BASH_REMATCH[0]}"/ }"
            matched=true
        done

        if [[ "$matched" == false ]]; then
            wildcards="${wildcards}${spec}"$'\n'
        fi
    done <<< "$declared_specs"

    # --- Pass 2: classify each installed skill ---
    # A skill is attributed to a wildcard only if its name starts with the prefix
    # derived from that wildcard's org (e.g. "specstoryai" → "specstory").
    # Skills that don't match any deterministic spec and don't start with any
    # wildcard prefix are orphans.
    local orphans=""        # newline-delimited list
    local wildcard_covered=false

    for skill_dir in "$skills_dir"/*/; do
        [[ -e "$skill_dir" ]] || continue
        local skill_name
        skill_name=$(basename "$skill_dir")

        if echo "$known_skills" | grep -qxF "$skill_name"; then
            : # directly matched by a deterministic spec
        else
            local attributed=false
            while IFS= read -r wc_spec; do
                [[ -z "$wc_spec" ]] && continue
                local prefix
                prefix=$(_wildcard_prefix "$wc_spec")
                if [[ -n "$prefix" && "$skill_name" == "${prefix}"* ]]; then
                    attributed=true
                    break
                fi
            done <<< "$wildcards"

            if [[ "$attributed" == true ]]; then
                wildcard_covered=true
            else
                orphans="${orphans}${skill_name}"$'\n'
            fi
        fi
    done

    # --- Output ---
    if [[ "$wildcard_covered" == true ]]; then
        local wc_note
        wc_note=$(printf '%s' "$wildcards" | tr '\n' ',' | sed 's/,*$//' | sed 's/,/, /g')
        print_message "info" "Skills not individually verified (covered by collection spec): ${wc_note}"
    fi

    if [[ -z "$orphans" ]]; then
        print_message "success" "No orphans"
    else
        echo "$orphans" | grep -v '^$'
        local orphan_count
        orphan_count=$(echo "$orphans" | grep -c '[^[:space:]]')
        TOTAL_ORPHANS=$((TOTAL_ORPHANS + orphan_count))
        MANAGERS_WITH_ORPHANS=$((MANAGERS_WITH_ORPHANS + 1))
    fi
}

audit_claude_mcp_servers() {
    local installed_file declared_file
    installed_file=$(mktemp)
    declared_file=$(mktemp)

    # Installed: user-scope MCP servers are stored in mcpServers key of each
    # Claude environment's settings.json.  Glob all ~/.claude*/settings.json to
    # cover personal, work, and default environments without needing chezmoi data.
    local found_any=false
    for settings_file in "${HOME}"/.claude*/settings.json; do
        [[ -f "$settings_file" ]] || continue
        found_any=true
        jq -r '.mcpServers // {} | keys[]' "$settings_file" 2>/dev/null >> "$installed_file" || true
    done

    if [[ "$found_any" == "false" ]]; then
        print_message "skip" "No Claude environment settings.json files found — skipping MCP audit"
        rm -f "$installed_file" "$declared_file"
        return
    fi

    sort -u "$installed_file" -o "$installed_file"

    # Declared: first token of each mcp_servers entry (the server name; strip command)
    declared_for_agent "claude_code" "mcp_servers" \
        | awk '{print $1}' \
        | sort > "$declared_file"

    report_orphans "Claude Code MCP Servers" "$installed_file" "$declared_file"
    rm -f "$installed_file" "$declared_file"
}

audit_claude() {
    if ! command_exists claude; then
        print_message "skip" "claude not found — skipping Claude Code sections"
        return
    fi
    if ! has_tag "ai"; then
        print_message "skip" "ai tag not active — skipping Claude Code sections"
        return
    fi
    audit_claude_mcp_servers
    audit_claude_plugins
    audit_claude_marketplaces
    audit_claude_skills
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    require_yq
    require_chezmoi

    print_message "info" "Reading active chezmoi tags..."
    read_active_tags

    if [[ ${#ACTIVE_TAGS[@]} -eq 0 ]]; then
        print_message "warning" "No tags found in chezmoi data — declared sets may be empty"
    else
        print_message "info" "Active tags: ${ACTIVE_TAGS[*]}"
    fi

    echo ""

    audit_homebrew
    echo ""
    audit_uv
    echo ""
    audit_bun
    echo ""
    audit_cargo
    echo ""
    audit_sdkman
    echo ""
    audit_claude

    echo ""
    print_message "info" "Audit complete: ${TOTAL_ORPHANS} orphan(s) across ${MANAGERS_WITH_ORPHANS} manager(s)"

    if [[ "$STRICT" == "true" && "$TOTAL_ORPHANS" -gt 0 ]]; then
        exit 1
    fi
    exit 0
}

main
