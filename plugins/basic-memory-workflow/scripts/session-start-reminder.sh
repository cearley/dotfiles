#!/usr/bin/env bash
# SessionStart hook: bootstraps the basic-memory project (if needed) and reminds Claude
# to check it for prior context before responding. This is the one guaranteed place that
# runs before anything else in a session, so it's also where a brand-new project's
# basic-memory project gets created — save-session and sync-memory both rely on this
# having already happened by the time they run, rather than each registering it
# themselves. Silent no-op outside a git repo or without basic-memory installed
# (ensure-project-registered.sh's job to decide that) - this must never make session
# start noisy or fail if either is missing.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

project="$("$script_dir/ensure-project-registered.sh" 2>/dev/null)" || exit 0

echo "SYSTEM REMINDER: This is the ${project} project. Your FIRST action this session — before responding to the user and before executing any skill — is to call search_notes and recent_activity on basic-memory project \"${project}\" for prior session context, open issues, and next steps. Do not skip this even if the first message is a skill invocation."
