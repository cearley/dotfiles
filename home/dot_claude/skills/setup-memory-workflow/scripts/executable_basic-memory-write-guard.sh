#!/usr/bin/env bash
# basic-memory-write-guard — PreToolUse hook (Bash|Edit|Write matcher). Denies any
# write-shaped Bash command, or any Edit/Write call, that targets a path under
# basic-memory's notes store. Prefer indexed MCP agent writes to avoid stale
# revisions and indexing delay. Human Markdown edits are supported by Basic Memory;
# this heuristic guard expresses agent policy, not a security sandbox.
#
# Deployed once, machine-wide, by chezmoi (like check-drift.sh itself) — this script
# takes no __PROJECT__ substitution, since the guard applies to the whole
# ~/.local/share/basic-memory/ tree, not just one project's subdirectory. Every
# project's .claude/settings.local.json just points its PreToolUse hook at this same
# global path; see check-drift.sh's write-guard-hook piece.
#
# Heuristic, not a sandbox: Bash detection matches common write-shaped constructs
# (redirects, tee/rm/mv/cp/touch/mkdir/sed -i/etc.) anywhere in a command that also
# references the base dir — deliberately favors false positives (an unnecessary block)
# over false negatives, same tradeoff as the blanket "any change is risky" Bash handling
# in home/dot_local/bin/executable_claude-tooling-write-guard.tmpl. A sufficiently
# creative command (e.g. a Python one-liner) can still slip through. Read is left
# unguarded — inspecting a note file directly is lower-risk and sometimes legitimate
# while debugging this workflow itself.
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

# Resolves symlinks where possible (falls back to the parent dir's real path, then the
# raw path) before checking whether it sits under $BASE — same approach as
# claude-tooling-write-guard's check_path().
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
