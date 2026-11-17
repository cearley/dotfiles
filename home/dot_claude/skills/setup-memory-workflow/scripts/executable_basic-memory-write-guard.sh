#!/usr/bin/env bash
# basic-memory-write-guard — PreToolUse hook (Bash|Edit|Write matcher): denies any
# write-shaped Bash command, or Edit/Write call, that targets basic-memory's notes
# store. Prefer indexed MCP writes (bm_write/bm_edit) instead; human Markdown edits
# are supported. Heuristic agent policy, not a security sandbox — it favors false
# positives (an unnecessary block) over false negatives, and a sufficiently creative
# command (e.g. a Python one-liner) can still slip through. Read is left unguarded.
#
# Deployed once, machine-wide by chezmoi, no __PROJECT__ substitution — every
# project's PreToolUse hook points at this same global path (see check-drift.sh's
# write-guard-hook piece).
set -euo pipefail

BASE="$HOME/.local/share/basic-memory"

payload=$(cat)
tool_name=$(jq -r '.tool_name // ""' <<<"$payload")

MESSAGE="This path is inside basic-memory's notes store ($BASE). Use indexed agent writes through bm_write or bm_edit with an explicit project and a fresh expected_checksum for edits; direct writes can cause stale revisions or indexing delay. Human Markdown editing is supported. This heuristic guard is agent policy, not a security sandbox."

emit_deny() {
    jq -n --arg reason "$MESSAGE" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
}

# Resolves symlinks (falling back to the parent's real path, then the raw path)
# before checking containment under $BASE.
under_base() {
    local path="$1" resolved="$1" real real_parent
    if real=$(realpath "$path" 2>/dev/null); then
        resolved="$real"
    elif real_parent=$(realpath "$(dirname -- "$path")" 2>/dev/null); then
        resolved="${real_parent}/$(basename -- "$path")"
    fi
    [[ "$resolved" == "$BASE"/* ]]
}

case "$tool_name" in
    Edit | Write)
        file_path=$(jq -r '.tool_input.file_path // ""' <<<"$payload")
        [[ -z "$file_path" ]] && exit 0
        if under_base "$file_path"; then
            emit_deny
        fi
        ;;
    Bash)
        command=$(jq -r '.tool_input.command // ""' <<<"$payload")
        [[ -z "$command" ]] && exit 0

        # Raw command text, not shell-evaluated — expand ~ and a literal $HOME manually.
        expanded="${command/#\~/$HOME}"
        expanded="${expanded//\$HOME/$HOME}"
        expanded="${expanded//\~\//$HOME/}"

        [[ "$expanded" == *"$BASE"* ]] || exit 0

        redirect_pattern='>{1,2}'
        word_pattern='(^|[;&|[:space:]])(rm|mv|cp|touch|mkdir|truncate|dd|install|tee)([[:space:]]|$)'
        sed_pattern='(^|[;&|[:space:]])sed[[:space:]]+-i'

        if [[ "$expanded" =~ $redirect_pattern ]] || [[ "$expanded" =~ $word_pattern ]] || [[ "$expanded" =~ $sed_pattern ]]; then
            emit_deny
        fi
        ;;
esac
