# setup-memory-workflow changelog

Starts fresh at v8. Earlier versions (v1–v7) predate this file and are not backfilled —
reconstructing accurate detail for all of them isn't reliably possible, and fabricating
detail would be worse than omitting it.

## v8 (2026-08-06)
Hook trigger moved from `UserPromptSubmit` to `SessionStart`. The prior hook fired
alongside the user's first message, so when that message was a skill invocation the
skill's instruction text outcompeted the one-line basic-memory reminder for context
attention. SessionStart fires before the first message, giving the reminder clean
context. The new `SessionStart` hook itself is managed as ordinary canonical-shape
content in `check-drift.sh` (create/update via version marker, same as every other
piece). Separately, `migrate_hook_config` in `scripts/migrations.sh` cleans up any
leftover `basic-memory` hook still sitting under `UserPromptSubmit` from a pre-v8
install — this runs unconditionally on every `check-drift.sh` invocation, silently,
with no user confirmation needed, since it only ever removes this skill's own
prior artifact.
