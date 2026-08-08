#!/usr/bin/env bash
# Resolves the current project's identity (via resolve-project-name.sh) and guarantees
# it is registered with basic-memory, in local mode, before returning it. This is what
# bootstraps a brand-new project's basic-memory project on first use — without it, the
# SessionStart hook's reminder and sync-memory's Step 2/3 would call MCP tools (search_notes,
# recent_activity, write_note) against a project name basic-memory has never heard of, which
# falls back to cloud-mode routing and fails on missing credentials rather than erroring
# cleanly. Every consumer of resolve-project-name.sh that goes on to touch basic-memory MCP
# tools should call this instead.
#
# `basic-memory project add <name> <path>` is idempotent (exits 0 whether or not the
# project already exists) and creates <path> itself, so this is safe and cheap to call
# on every invocation.
#
# Prints the resolved project name on stdout and exits 0 on success. Exits non-zero with
# nothing on stdout if: not inside a git repository, or the `basic-memory` CLI isn't
# installed. Callers that want a user-facing "please install basic-memory" message should
# check for it themselves (see save-session Step 1) rather than relying on this script's
# stderr, since silent callers (the SessionStart hook) redirect stderr away entirely.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

project="$("$script_dir/resolve-project-name.sh")"

command -v basic-memory >/dev/null 2>&1

basic-memory project add "$project" "$HOME/.local/share/basic-memory/$project" >/dev/null

echo "$project"
