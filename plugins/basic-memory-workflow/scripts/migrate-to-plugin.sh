#!/usr/bin/env bash
# migrate-to-plugin.sh — one-time cleanup of a project's pre-plugin setup-memory-workflow
# artifacts, then enables the basic-memory-workflow plugin for that project.
#
# Mirrors check-drift.sh's check/apply, never-silently-overwrite discipline: `check`
# only reports what it finds, `apply` only acts on confirmation. Unlike check-drift.sh
# this is not meant to run forever — it exists to migrate projects off the old
# copy-based install, once, and is safe to re-run afterward (a no-op on an
# already-migrated project).
#
# Usage:
#   migrate-to-plugin.sh check
#   migrate-to-plugin.sh apply

set -euo pipefail

MARKETPLACE_NAME="chezmoi-personal"
PLUGIN_NAME="basic-memory-workflow"
PLUGIN_KEY="${PLUGIN_NAME}@${MARKETPLACE_NAME}"

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$PROJECT_ROOT"

OLD_SAVE_SESSION=".claude/skills/save-session"
OLD_SYNC_MEMORY=".claude/skills/sync-memory"
SETTINGS_LOCAL=".claude/settings.local.json"
GIT_EXCLUDE=".git/info/exclude"

# Two legacy hook shapes exist in the wild: the v8+ SessionStart hook (this repo's own
# vintage), and the pre-v8 UserPromptSubmit hook (some projects were never re-run through
# check-drift.sh after that migration and are still on it — confirmed empirically against
# a real project during rollout, setup-memory-workflow-version:2). Both are checked and
# cleaned up independently; neither assumes the other is present.
_has_legacy_session_start_hook() {
  [ -f "$SETTINGS_LOCAL" ] || return 1
  jq -e '[.hooks.SessionStart[]?.hooks[]?.command // ""] | any(contains("basic-memory"))' \
    "$SETTINGS_LOCAL" >/dev/null 2>&1
}

_has_legacy_user_prompt_submit_hook() {
  [ -f "$SETTINGS_LOCAL" ] || return 1
  jq -e '[.hooks.UserPromptSubmit[]?.hooks[]?.command // ""] | any(contains("basic-memory"))' \
    "$SETTINGS_LOCAL" >/dev/null 2>&1
}

_has_legacy_hook() {
  _has_legacy_session_start_hook || _has_legacy_user_prompt_submit_hook
}

_has_stale_exclude() {
  [ -f "$GIT_EXCLUDE" ] || return 1
  grep -qE '\.claude/skills/(save-session|sync-memory)/?$' "$GIT_EXCLUDE" 2>/dev/null
}

_plugin_enabled() {
  [ -f "$SETTINGS_LOCAL" ] || return 1
  jq -e --arg key "$PLUGIN_KEY" '.enabledPlugins[$key] == true' "$SETTINGS_LOCAL" >/dev/null 2>&1
}

cmd_check() {
  local found_any=no

  echo "== old save-session skill =="
  if [ -d "$OLD_SAVE_SESSION" ]; then
    echo "FOUND: $OLD_SAVE_SESSION"
    found_any=yes
  else
    echo "ABSENT"
  fi

  echo
  echo "== old sync-memory skill =="
  if [ -d "$OLD_SYNC_MEMORY" ]; then
    echo "FOUND: $OLD_SYNC_MEMORY"
    found_any=yes
  else
    echo "ABSENT"
  fi

  echo
  echo "== legacy hooks in $SETTINGS_LOCAL =="
  local any_hook=no
  if _has_legacy_session_start_hook; then
    echo "FOUND: SessionStart (v8+ shape)"
    found_any=yes
    any_hook=yes
  fi
  if _has_legacy_user_prompt_submit_hook; then
    echo "FOUND: UserPromptSubmit (pre-v8 shape)"
    found_any=yes
    any_hook=yes
  fi
  [ "$any_hook" = "no" ] && echo "ABSENT"

  echo
  echo "== stale .git/info/exclude entries =="
  if _has_stale_exclude; then
    echo "FOUND:"
    grep -E '\.claude/skills/(save-session|sync-memory)/?$' "$GIT_EXCLUDE"
    found_any=yes
  else
    echo "ABSENT"
  fi

  echo
  echo "== plugin enabled ($PLUGIN_KEY) =="
  if _plugin_enabled; then
    echo "ALREADY ENABLED"
  else
    echo "NOT ENABLED"
    found_any=yes
  fi

  echo
  if [ "$found_any" = "no" ]; then
    echo "Nothing to migrate — this project is already on the plugin."
  else
    echo "Run 'migrate-to-plugin.sh apply' after confirming with the user to act on the above."
  fi
}

cmd_apply() {
  if [ -d "$OLD_SAVE_SESSION" ]; then
    rm -rf "$OLD_SAVE_SESSION"
    echo "REMOVED: $OLD_SAVE_SESSION"
  fi

  if [ -d "$OLD_SYNC_MEMORY" ]; then
    rm -rf "$OLD_SYNC_MEMORY"
    echo "REMOVED: $OLD_SYNC_MEMORY"
  fi

  if _has_legacy_session_start_hook; then
    jq '
      .hooks.SessionStart |= map(.hooks |= map(select((.command // "" | contains("basic-memory")) | not)))
      | .hooks.SessionStart |= map(select((.hooks | length) > 0))
      | (if (.hooks.SessionStart | length) == 0 then del(.hooks.SessionStart) else . end)
    ' "$SETTINGS_LOCAL" > "$SETTINGS_LOCAL.tmp" && mv "$SETTINGS_LOCAL.tmp" "$SETTINGS_LOCAL"
    echo "REMOVED: legacy SessionStart hook from $SETTINGS_LOCAL"
  fi

  if _has_legacy_user_prompt_submit_hook; then
    jq '
      .hooks.UserPromptSubmit |= map(.hooks |= map(select((.command // "" | contains("basic-memory")) | not)))
      | .hooks.UserPromptSubmit |= map(select((.hooks | length) > 0))
      | (if (.hooks.UserPromptSubmit | length) == 0 then del(.hooks.UserPromptSubmit) else . end)
    ' "$SETTINGS_LOCAL" > "$SETTINGS_LOCAL.tmp" && mv "$SETTINGS_LOCAL.tmp" "$SETTINGS_LOCAL"
    echo "REMOVED: legacy UserPromptSubmit hook from $SETTINGS_LOCAL"
  fi

  if _has_stale_exclude; then
    grep -vE '\.claude/skills/(save-session|sync-memory)/?$' "$GIT_EXCLUDE" > "$GIT_EXCLUDE.tmp" \
      && mv "$GIT_EXCLUDE.tmp" "$GIT_EXCLUDE"
    echo "REMOVED: stale entries from $GIT_EXCLUDE"
  fi

  if ! _plugin_enabled; then
    # Goes through the real CLI, not a raw jq write: `claude plugin install` both sets
    # enabledPlugins in settings.local.json AND materializes the plugin into this
    # machine's cache (~/.claude*/plugins/cache/...) plus installed_plugins.json — a
    # hand-written enabledPlugins entry alone would leave nothing for Claude Code to
    # actually load.
    if claude plugin install "$PLUGIN_KEY" --scope local 2>&1; then
      echo "ENABLED: $PLUGIN_KEY (scope: local)"
    else
      echo "ERROR: failed to install $PLUGIN_KEY — is the marketplace registered? (see the claude-plugin-marketplace capability)" >&2
      exit 1
    fi
  fi

  echo
  echo "Migration complete."
}

case "${1:-}" in
  check) cmd_check ;;
  apply) cmd_apply ;;
  *) echo "Usage: migrate-to-plugin.sh <check|apply>" >&2; exit 1 ;;
esac
