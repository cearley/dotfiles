#!/usr/bin/env bash
# SessionStart hook: reminds Claude to check basic-memory for prior context before
# responding. Silent no-op outside a git repo (resolve-project-name.sh's job to decide
# what "no project" means) - a session starting in a non-git directory shouldn't have
# this plugin enabled in the first place, but this must never make session start noisy
# or fail if it happens anyway.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

project="$("$script_dir/resolve-project-name.sh" 2>/dev/null)" || exit 0

echo "SYSTEM REMINDER: This is the ${project} project. Your FIRST action this session — before responding to the user and before executing any skill — is to call search_notes and recent_activity on basic-memory project \"${project}\" for prior session context, open issues, and next steps. Do not skip this even if the first message is a skill invocation."
