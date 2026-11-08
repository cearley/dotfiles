# shellcheck shell=bash
# lib-project.sh — sourced by check-drift.sh. Resolves the current project's
# basic-memory identity once, at apply-time.
#
# $PROJECT resolution (apply-time only — no runtime script ships in any
# installed piece):
#   1. <project-root>/.claude/basic-memory-project.txt, if present and
#      non-blank (a deliberately narrow escape hatch for when a project's
#      basic-memory identity needs to diverge from its directory name)
#   2. basename of `git rev-parse --show-toplevel`
#
# Requires $PROJECT_ROOT to already be set by the caller.

# Resolves $PROJECT once, at apply-time. No runtime script — every installed
# piece gets this value baked in via render() in lib-pieces.sh, not
# re-derived later.
resolve_project() {
  local override_file="$PROJECT_ROOT/.claude/basic-memory-project.txt"
  if [ -f "$override_file" ]; then
    local override
    override=$(tr -d '[:space:]' <"$override_file" 2>/dev/null || true)
    if [ -n "$override" ]; then
      # Print the file's actual (untrimmed-of-internal-content) first line, not
      # the whitespace-stripped value used only to test for blankness above.
      head -n1 "$override_file" | tr -d '\r\n'
      return
    fi
  fi
  basename "$PROJECT_ROOT"
}
