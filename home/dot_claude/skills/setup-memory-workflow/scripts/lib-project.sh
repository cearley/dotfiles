# shellcheck shell=bash
# lib-project.sh — sourced by check-drift.sh. Resolves $PROJECT once, at
# apply-time (every installed piece bakes the value in via render() in
# lib-pieces.sh; no runtime script re-derives it). Requires $PROJECT_ROOT
# already set by the caller.
#
# Resolution order:
#   1. <project-root>/.claude/basic-memory-project.txt, if present and
#      non-blank (escape hatch for when identity must diverge from the
#      directory name)
#   2. basename of `git rev-parse --show-toplevel`
resolve_project() {
    local override_file="$PROJECT_ROOT/.claude/basic-memory-project.txt"
    if [ -f "$override_file" ]; then
        local override
        override=$(tr -d '[:space:]' <"$override_file" 2>/dev/null || true)
        if [ -n "$override" ]; then
            # Use the file's actual first line, not the whitespace-stripped
            # value above (which only tests for blankness).
            head -n1 "$override_file" | tr -d '\r\n'
            return
        fi
    fi
    basename "$PROJECT_ROOT"
}
