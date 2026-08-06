#!/usr/bin/env bash
# Resolves the current project's basic-memory identity. Sole source of truth for this
# across the whole basic-memory-workflow plugin (the SessionStart hook, sync-memory.py,
# and save-session's own instructions all call this instead of each deriving it their
# own way) - resolved fresh on every invocation, never baked in at install time.
#
# Resolution order:
#   1. <project-root>/.claude/basic-memory-project.txt, if present and non-blank
#   2. basename of `git rev-parse --show-toplevel`
#
# Exits non-zero with a message on stderr if not inside a git repository.

set -euo pipefail

project_root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "resolve-project-name.sh: not inside a git repository" >&2
  exit 1
}

override_file="$project_root/.claude/basic-memory-project.txt"

if [[ -f "$override_file" ]]; then
  override="$(tr -d '[:space:]' <"$override_file" 2>/dev/null || true)"
  if [[ -n "$override" ]]; then
    # Print the file's actual (untrimmed-of-internal-content) first line, not the
    # whitespace-stripped value used only to test for blankness above.
    head -n1 "$override_file" | tr -d '\r\n'
    exit 0
  fi
fi

basename "$project_root"
