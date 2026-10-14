#!/bin/bash
# audit-claude-code.sh — Claude Code orphan-detection logic (plugins, marketplaces, skills,
# MCP servers) shared by audit-packages and clean-claude-orphans.
#
# PLAIN BASH, ZERO CHEZMOI TEMPLATE SYNTAX. home/.chezmoiignore.tmpl lists `scripts/`, so
# chezmoi never renders or deploys anything under home/scripts/ — a `.tmpl` file here would be
# sourced with literal, uninterpreted `{{ }}` text and break immediately. Never add `{{ }}`
# anywhere in this file.
#
# This file is `source`d directly by two chezmoi-templated callers:
#   - home/dot_local/bin/executable_audit-packages.tmpl
#   - home/dot_claude/skills/clean-claude-orphans/scripts/executable_list-claude-orphans.sh.tmpl
# Each caller sets two plain shell variables from its own already-rendered template values
# BEFORE sourcing this file:
#   PACKAGES_YAML                — absolute path to .chezmoidata/packages.yaml
#   CHEZMOI_MANAGED_SKILLS_DIR    — absolute path to home/dot_claude/skills (source, not deployed)
#
# Deliberately does NOT source scripts/shared-utils.sh: that library is print_message /
# command_exists human-facing output, and this file is JSONL-only, no human-facing output at
# all. Preconditions (is `claude` on PATH, etc.) are the caller's job, not this file's.

# Single source of truth for the chezmoi-personal marketplace suffix test, referenced
# identically by claude_orphan_plugins_jsonl and claude_installed_plugins_jsonl.
CHEZMOI_PERSONAL_SUFFIX="@chezmoi-personal"

# ---------------------------------------------------------------------------
# Shared tail for the three orphan functions whose installed/declared sides are plain
# sorted files (plugins, marketplaces, MCP servers — skills builds its JSONL differently,
# since it also needs per-item skill_tag classification, not just a flat diff): diff them
# and emit one JSONL line per orphan.
# ---------------------------------------------------------------------------
_claude_emit_orphans_jsonl() {
    local category="$1" installed_file="$2" declared_file="$3"
    comm -23 "$installed_file" "$declared_file" 2>/dev/null | while IFS= read -r item; do
        [[ -z "$item" ]] && continue
        jq -cn --arg category "$category" --arg item "$item" '{category: $category, item: $item, skill_tag: null}'
    done || true
}

# ---------------------------------------------------------------------------
# Collect the declared set for a given key under a specific coding agent.
# Moved verbatim from audit-packages.tmpl.
# ---------------------------------------------------------------------------
declared_for_agent() {
    local agent="$1" key="$2"
    yq ".packages.darwin.ai.agents.${agent}.${key}[]?" "$PACKAGES_YAML" 2>/dev/null | sort -u
}

# ---------------------------------------------------------------------------
# List basenames of every directory under $CHEZMOI_MANAGED_SKILLS_DIR, one per line.
# Emits nothing (not an error) if the directory doesn't exist.
# ---------------------------------------------------------------------------
claude_chezmoi_managed_skill_names() {
    [[ -d "$CHEZMOI_MANAGED_SKILLS_DIR" ]] || return 0

    local dir name
    for dir in "$CHEZMOI_MANAGED_SKILLS_DIR"/*/; do
        [[ -e "$dir" ]] || continue
        name=$(basename "$dir")
        echo "$name"
    done
}

# ---------------------------------------------------------------------------
# Emit one compact JSON line per plugin declared in this repo's own
# chezmoi-personal marketplace: {"name":"<plugin-name>","skills":[...]}.
# Fixed path under $HOME, independent of sourceDir (the deployed copy, not the
# chezmoi source, which still has unrendered template syntax jq can't parse).
# ---------------------------------------------------------------------------
claude_chezmoi_personal_plugins_jsonl() {
    local marketplace_json="$HOME/.local/share/claude-plugins/.claude-plugin/marketplace.json"

    if [[ ! -f "$marketplace_json" ]]; then
        echo "error: marketplace.json not found at ${marketplace_json}" >&2
        return 0
    fi

    jq -c '.plugins[] | {name, skills: ((.skills // []) | map(sub("^\\./"; "")))}' "$marketplace_json" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Diff installed Claude Code plugin ids against declared ids. Declared side is
# the union of declared_for_agent "claude_code" "plugins" and every installed
# id ending in the literal @chezmoi-personal suffix (a direct id-suffix test —
# NOT a lookup against claude_chezmoi_personal_plugins_jsonl's marketplace
# names; those are two different checks).
# ---------------------------------------------------------------------------
claude_orphan_plugins_jsonl() {
    local installed_file declared_file
    installed_file=$(mktemp)
    declared_file=$(mktemp)

    # Installed: .id field from JSON. sort -u, not sort: the same id can
    # legitimately appear once per scope it's installed/enabled in.
    if claude plugins list --json 2>/dev/null | jq -r '.[].id' 2>/dev/null | sort -u > "$installed_file"; then
        :
    else
        # Fallback: parse text output for id@marketplace-shaped tokens.
        claude plugins list 2>/dev/null \
            | grep -oE '[a-zA-Z0-9_-]+@[a-zA-Z0-9_-]+' \
            | sort -u > "$installed_file" || true
    fi

    {
        declared_for_agent "claude_code" "plugins"
        grep -E "${CHEZMOI_PERSONAL_SUFFIX}\$" "$installed_file" 2>/dev/null || true
    } | sort -u > "$declared_file"

    _claude_emit_orphans_jsonl "plugin" "$installed_file" "$declared_file"

    rm -f "$installed_file" "$declared_file"
}

# ---------------------------------------------------------------------------
# Diff installed Claude Code plugin marketplaces against declared marketplaces.
# Ports audit_claude_marketplaces' exact installed-side and declared-side logic.
# ---------------------------------------------------------------------------
claude_orphan_marketplaces_jsonl() {
    local installed_file declared_file
    installed_file=$(mktemp)
    declared_file=$(mktemp)

    if claude plugins marketplace list --json 2>/dev/null | \
        jq -r '.[] | if .source == "github" then .repo elif .source == "directory" then .path else .url end' 2>/dev/null | \
        sort > "$installed_file"; then
        :
    else
        claude plugins marketplace list 2>/dev/null \
            | grep -E '^\s+❯' \
            | awk '{print $2}' \
            | sort > "$installed_file" || true
    fi

    declared_for_agent "claude_code" "plugin_marketplaces" \
        | sed 's/#[^#]*$//' \
        | sed "s|\$HOME|$HOME|" \
        | sort > "$declared_file"

    _claude_emit_orphans_jsonl "marketplace" "$installed_file" "$declared_file"

    rm -f "$installed_file" "$declared_file"
}

# ---------------------------------------------------------------------------
# Returns 0 if the user-scope skills directory exists, 1 otherwise. No output.
# ---------------------------------------------------------------------------
claude_skills_dir_present() {
    [[ -d "${HOME}/.claude/skills" ]]
}

# ---------------------------------------------------------------------------
# Derive a skill-name prefix from a collection-wildcard spec: the org
# component (before /) with known company suffixes and trailing separators
# stripped. e.g. "specstoryai/agent-skills -all" -> "specstory". Ported
# verbatim from audit-packages.tmpl's _wildcard_prefix.
# ---------------------------------------------------------------------------
_claude_wildcard_prefix() {
    local spec="$1"
    local org
    org=$(echo "$spec" | cut -d'/' -f1)
    echo "$org" \
        | sed -E 's/(ai|hq|io|dev|co|labs|inc|app|apps|tech|ware|js|ly)$//' \
        | sed -E 's/[-_]+$//'
}

# ---------------------------------------------------------------------------
# True if skill_name's name starts with the org-derived prefix of any wildcard spec in
# the newline-delimited $wildcards. Shared by claude_orphan_skills_jsonl (to skip an
# attributed skill) and claude_skills_wildcard_coverage_note (to decide whether to emit a
# note at all) — both need the identical attribution check.
# ---------------------------------------------------------------------------
_claude_skill_attributed_to_wildcard() {
    local skill_name="$1" wildcards="$2"
    local wc_spec prefix
    while IFS= read -r wc_spec; do
        [[ -z "$wc_spec" ]] && continue
        prefix=$(_claude_wildcard_prefix "$wc_spec")
        [[ -n "$prefix" && "$skill_name" == "${prefix}"* ]] && return 0
    done <<< "$wildcards"
    return 1
}

# ---------------------------------------------------------------------------
# Split declared "claude_code" "skills" specs into known-skill names
# (deterministic path-style and --skill-flag specs) and wildcard collection
# specs. Writes newline-delimited results into the caller's _known_out and
# _wildcards_out variable names (nameref-free portable approach: caller reads
# $__known_skills / $__wildcards after calling).
# ---------------------------------------------------------------------------
_claude_split_skill_specs() {
    local declared_specs
    declared_specs=$(declared_for_agent "claude_code" "skills")

    __known_skills=""
    __wildcards=""

    while IFS= read -r spec; do
        [[ -z "$spec" ]] && continue
        local matched=false

        # Path-style: */skills/<name>
        if [[ "$spec" =~ ^[^[:space:]]*/skills/([^[:space:]/]+) ]]; then
            __known_skills="${__known_skills}${BASH_REMATCH[1]}"$'\n'
            matched=true
        fi

        # --skill <name...> flag: variadic, one or more names before next -flag/end.
        local -a spec_toks
        read -ra spec_toks <<< "$spec"
        local ti=0
        while [[ $ti -lt ${#spec_toks[@]} ]]; do
            if [[ "${spec_toks[$ti]}" == "--skill" ]]; then
                matched=true
                ti=$((ti + 1))
                while [[ $ti -lt ${#spec_toks[@]} && "${spec_toks[$ti]}" != -* ]]; do
                    __known_skills="${__known_skills}${spec_toks[$ti]}"$'\n'
                    ti=$((ti + 1))
                done
            else
                ti=$((ti + 1))
            fi
        done

        if [[ "$matched" == false ]]; then
            __wildcards="${__wildcards}${spec}"$'\n'
        fi
    done <<< "$declared_specs"
}

# ---------------------------------------------------------------------------
# Orphan Claude Code skills: assumes the caller already checked
# claude_skills_dir_present. Ports audit_claude_skills' deterministic-mapping
# and wildcard-prefix-coverage logic exactly, additionally excluding names
# from claude_chezmoi_managed_skill_names, and tagging bundled-by-plugin
# duplicates via a jq lookup against claude_chezmoi_personal_plugins_jsonl.
# ---------------------------------------------------------------------------
claude_orphan_skills_jsonl() {
    local skills_dir="${HOME}/.claude/skills"

    local __known_skills __wildcards
    _claude_split_skill_specs
    local known_skills="$__known_skills"
    local wildcards="$__wildcards"

    local managed_skills
    managed_skills=$(claude_chezmoi_managed_skill_names)

    local orphans=""

    local skill_dir
    for skill_dir in "$skills_dir"/*/; do
        [[ -e "$skill_dir" ]] || continue
        local skill_name
        skill_name=$(basename "$skill_dir")

        # Directly matched by a deterministic spec.
        if echo "$known_skills" | grep -qxF "$skill_name"; then
            continue
        fi

        # Chezmoi-managed native skill — not an orphan of the external mechanism.
        if [[ -n "$managed_skills" ]] && echo "$managed_skills" | grep -qxF "$skill_name"; then
            continue
        fi

        if _claude_skill_attributed_to_wildcard "$skill_name" "$wildcards"; then
            continue
        fi

        local bundled_by
        bundled_by=$(claude_chezmoi_personal_plugins_jsonl 2>/dev/null \
            | jq -r --arg skill "$skill_name" 'select(.skills | index($skill)) | .name' 2>/dev/null \
            | head -n1)

        if [[ -n "$bundled_by" ]]; then
            orphans="${orphans}$(jq -cn --arg item "$skill_name" --arg tag "bundled-by:${bundled_by}" '{category: "skill", item: $item, skill_tag: $tag}')"$'\n'
        else
            orphans="${orphans}$(jq -cn --arg item "$skill_name" '{category: "skill", item: $item, skill_tag: null}')"$'\n'
        fi
    done

    printf '%s' "$orphans" | grep -v '^$' | sort || true
}

# ---------------------------------------------------------------------------
# Returns the "Skills not individually verified (covered by collection spec):
# ..." note text when at least one wildcard spec covered an installed skill,
# or nothing otherwise. Kept separate from claude_orphan_skills_jsonl's JSONL
# stream — no field is added to that stream for this.
# ---------------------------------------------------------------------------
claude_skills_wildcard_coverage_note() {
    local skills_dir="${HOME}/.claude/skills"

    local __known_skills __wildcards
    _claude_split_skill_specs
    local known_skills="$__known_skills"
    local wildcards="$__wildcards"

    local wildcard_covered=false

    local skill_dir
    for skill_dir in "$skills_dir"/*/; do
        [[ -e "$skill_dir" ]] || continue
        local skill_name
        skill_name=$(basename "$skill_dir")

        if echo "$known_skills" | grep -qxF "$skill_name"; then
            continue
        fi

        if _claude_skill_attributed_to_wildcard "$skill_name" "$wildcards"; then
            wildcard_covered=true
        fi
    done

    if [[ "$wildcard_covered" == true ]]; then
        local wc_note
        wc_note=$(printf '%s' "$wildcards" | tr '\n' ',' | sed 's/,*$//' | sed 's/,/, /g')
        echo "Skills not individually verified (covered by collection spec): ${wc_note}"
    fi
}

# ---------------------------------------------------------------------------
# Returns 0 if any ~/.claude*/settings.json file exists, 1 otherwise. No output.
# ---------------------------------------------------------------------------
claude_mcp_settings_present() {
    local settings_file
    for settings_file in "${HOME}"/.claude*/settings.json; do
        [[ -f "$settings_file" ]] && return 0
    done
    return 1
}

# ---------------------------------------------------------------------------
# Orphan Claude Code MCP servers: assumes the caller already checked
# claude_mcp_settings_present. Declared side MUST be a direct .name-extracting
# yq query — mcp_servers entries are structured maps ({name, scope, command}),
# not plain strings, so declared_for_agent's generic .key[]? query would
# return whole map objects here and never string-match an installed server
# name, making every declared MCP server show as a false orphan.
# ---------------------------------------------------------------------------
claude_orphan_mcp_servers_jsonl() {
    local installed_file declared_file
    installed_file=$(mktemp)
    declared_file=$(mktemp)

    local settings_file
    for settings_file in "${HOME}"/.claude*/settings.json; do
        [[ -f "$settings_file" ]] || continue
        jq -r '.mcpServers // {} | keys[]' "$settings_file" 2>/dev/null >> "$installed_file" || true
    done

    sort -u "$installed_file" -o "$installed_file"

    yq ".packages.darwin.ai.agents.claude_code.mcp_servers[]?.name" "$PACKAGES_YAML" 2>/dev/null \
        | sort -u > "$declared_file"

    _claude_emit_orphans_jsonl "mcp_server" "$installed_file" "$declared_file"

    rm -f "$installed_file" "$declared_file"
}

# ---------------------------------------------------------------------------
# One JSONL line per currently installed plugin: id, scope, projectPath,
# chezmoi_personal (same @chezmoi-personal suffix test as
# claude_orphan_plugins_jsonl, via $CHEZMOI_PERSONAL_SUFFIX), enabled.
# ---------------------------------------------------------------------------
claude_installed_plugins_jsonl() {
    local plugins_json
    plugins_json="$(claude plugins list --json 2>/dev/null)" || true
    [[ -n "$plugins_json" ]] || return 0

    echo "$plugins_json" | jq -c --arg suffix "$CHEZMOI_PERSONAL_SUFFIX" '.[] | {
        id,
        scope,
        projectPath: (.projectPath // null),
        chezmoi_personal: (.id | endswith($suffix)),
        enabled
    }' 2>/dev/null || true
}
