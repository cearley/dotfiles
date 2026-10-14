#!/bin/bash
# list-skills.sh — Enumerate every skill actually usable in this Claude Code
# environment: native/external skills (minus any disabled via skillOverrides),
# skills bundled in installed-AND-enabled plugins, and project-local skills.
# Read-only: lists only, never installs or modifies anything.
#
# Output: one skill per line, tab-separated: invoke, origin, description.
#   invoke — the ready-to-use id: bare name for native/project skills,
#            "<plugin>:<skill>" for plugin-bundled ones.
#   origin — native | project | plugin:<marketplace> (context, not for invoking)
set -euo pipefail

CLAUDE_HOME="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SETTINGS="$CLAUDE_HOME/settings.json"
INSTALLED="$CLAUDE_HOME/plugins/installed_plugins.json"

# Extracts name/description via a real YAML parser (yq) instead of regex, so
# quoted strings, escapes, and block scalars (">", "|", ">+", etc.) all parse
# correctly. One subprocess per file: a malformed/non-UTF-8 SKILL.md fails in
# isolation instead of taking the rest of the output down with it.
emit() {
    local file="$1" invoke="$2" origin="$3" fm
    fm="$(yq --front-matter=extract -o=json '.' "$file" 2>/dev/null)" || return 0
    jq -r --arg invoke "$invoke" --arg origin "$origin" '
        if type != "object" then empty else
            ((.description // "") | gsub("\\s+"; " ") | .[0:160]) as $desc
            | [$invoke, $origin, $desc] | @tsv
        end
    ' <<<"$fm" 2>/dev/null || true
}

is_overridden_off() {
    [[ -f "$SETTINGS" ]] || return 1
    jq -e --arg id "$1" '.skillOverrides[$id] == "off"' "$SETTINGS" >/dev/null 2>&1
}

# Same plugin id can resolve to the same installPath from more than one
# install scope (e.g. both "user" and "project" entries), which would
# otherwise print identical lines twice.
main() {

# ---------------------------------------------------------------------------
# Native + external skills (shared across every persona via symlink), minus
# anything toggled off with /skill in this persona's settings.json.
# ---------------------------------------------------------------------------
if [[ -d "$CLAUDE_HOME/skills" ]]; then
    for f in "$CLAUDE_HOME"/skills/*/SKILL.md; do
        [[ -e "$f" ]] || continue
        id="$(basename "$(dirname "$f")")"
        is_overridden_off "$id" && continue
        emit "$f" "$id" "native"
    done
fi

# ---------------------------------------------------------------------------
# Plugin-bundled skills — only plugins that are both installed
# (installed_plugins.json) and enabled (settings.json's enabledPlugins), not
# every version sitting in plugins/cache/. A plugin can have more than one
# installPath across install scopes; glob all of them (deduped) since there's
# no single "the" active version without per-project context.
# ---------------------------------------------------------------------------
if [[ -f "$INSTALLED" && -f "$SETTINGS" ]]; then
    while IFS=$'\t' read -r plugin_id install_path; do
        [[ -z "$plugin_id" ]] && continue
        plugin_name="${plugin_id%@*}"
        marketplace="${plugin_id#*@}"
        for f in "$install_path"/skills/*/SKILL.md; do
            [[ -e "$f" ]] || continue
            skill_id="$(basename "$(dirname "$f")")"
            emit "$f" "${plugin_name}:${skill_id}" "plugin:${marketplace}"
        done
    done < <(
        jq -r '.enabledPlugins // {} | to_entries[] | select(.value == true) | .key' "$SETTINGS" \
        | while IFS= read -r id; do
            jq -r --arg id "$id" '.plugins[$id] // [] | .[].installPath' "$INSTALLED" | sort -u \
            | while IFS= read -r path; do printf '%s\t%s\n' "$id" "$path"; done
          done
    )
fi

# ---------------------------------------------------------------------------
# Project-local skills — resolved from the repo root, not the literal cwd, so
# running from a subdirectory still finds them. Skipped entirely if that
# resolves to the same directory as the native skills dir (e.g. cwd is $HOME).
# ---------------------------------------------------------------------------
project_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
if [[ -d "$project_root/.claude/skills" ]]; then
    native_real=""
    [[ -d "$CLAUDE_HOME/skills" ]] && native_real="$(cd "$CLAUDE_HOME/skills" && pwd -P)"
    project_real="$(cd "$project_root/.claude/skills" && pwd -P)"
    if [[ "$project_real" != "$native_real" ]]; then
        for f in "$project_root"/.claude/skills/*/SKILL.md; do
            [[ -e "$f" ]] || continue
            id="$(basename "$(dirname "$f")")"
            emit "$f" "$id" "project"
        done
    fi
fi

}

main | awk '!seen[$0]++'
