# migrations.sh — cleans up this skill's own prior-version artifacts.
#
# Sourced by check-drift.sh; never run standalone (no shebang, not chmod +x).
#
# Contract for every migrate_<piece> function:
#   - No arguments. Operates on the relevant file under $PROJECT_ROOT.
#   - Only ever removes or transforms known legacy state left by a prior
#     version of this skill. Never creates or manages the *current*
#     canonical shape of anything — that's check-drift.sh's job (directly,
#     or via check_templated_file()/apply_templated_file() for whole-file
#     pieces). A migration function has zero knowledge of what canonical
#     looks like today.
#   - MUST be idempotent: safe to call unconditionally, every time, forever.
#     No-ops silently once the legacy state it targets no longer exists.
#   - Called unconditionally, once, near the top of check-drift.sh — on
#     every invocation, both `check` and `apply`, regardless of which piece
#     is being checked or applied. Migrations are not gated behind a
#     specific `apply <piece>` confirmation step: they only ever touch this
#     skill's own previously-installed artifacts (matched by a literal
#     "basic-memory" substring or similarly unambiguous marker), never
#     anything a user might have added by hand.
#
# Add a CHANGELOG.md entry alongside any new or changed function here.

# Removes any legacy basic-memory hook left under UserPromptSubmit from
# before the v8 SessionStart migration (see CHANGELOG.md v8). Knows nothing
# about SessionStart — that's plain canonical-shape hook management living
# in check-drift.sh, not a migration concern.
migrate_hook_config() {
  [ -f .claude/settings.local.json ] || return 0
  jq -e '[.hooks.UserPromptSubmit[]?.hooks[]?.command // ""] | any(contains("basic-memory"))' \
    .claude/settings.local.json >/dev/null 2>&1 || return 0
  jq '
    .hooks.UserPromptSubmit |= map(.hooks |= map(select((.command // "" | contains("basic-memory")) | not)))
    | .hooks.UserPromptSubmit |= map(select((.hooks | length) > 0))
    | (if (.hooks.UserPromptSubmit | length) == 0 then del(.hooks.UserPromptSubmit) else . end)
  ' .claude/settings.local.json > .claude/settings.local.json.tmp \
    && mv .claude/settings.local.json.tmp .claude/settings.local.json
  echo "MIGRATED: removed legacy basic-memory hook from UserPromptSubmit"
}
