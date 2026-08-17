# setup-memory-workflow changelog

Starts fresh at v8. Earlier versions (v1–v7) predate this file and are not backfilled —
reconstructing accurate detail for all of them isn't reliably possible, and fabricating
detail would be worse than omitting it.

## v9 (2026-08-17)
This skill briefly went dormant while a Claude Code plugin (`basic-memory-workflow`)
distributed this workflow instead — that plugin is now deprecated in favor of this
skill again (see `openspec/changes/deprecate-basic-memory-workflow-plugin`). The plugin
era's runtime `$PROJECT` resolution turned out to be silently skippable: a `SessionStart`
hook already announced the project name in prose before `save-session`/`sync-memory` ran,
so re-deriving it a second time read as redundant even though it was the only step that
also applied the identity override file. v9 restores apply-time resolution but keeps that
one genuine improvement from the plugin era — the `<project-root>/.claude/basic-memory-project.txt`
override file (introduced during the plugin's runtime-resolution design, in response to a
real basic-memory project mixup) is now consulted once, at apply-time, instead of on every
invocation. `check-drift.sh` gains a new `update` subcommand: unconditionally repairs every
piece currently reporting version-only `DRIFT` (OpenSpec's `openspec update` pattern —
no per-piece confirmation), while `NAME-MISMATCH` (an identity change, not just a version
change) stays confirm-gated via `apply <piece>` exactly as before — and now takes
precedence over version drift, closing a latent bug where a piece that was simultaneously
version-stale and identity-mismatched would have been silently auto-correctable as if it
were only a version issue. Project registration (`basic-memory project add`) stays a
`check`-time-only action, matching v8's original behavior — the plugin's move to an
idempotent per-invocation check inside `save-session`/`sync-memory` is not carried back,
since removing the plugin restores the one natural place (this skill's own check/apply
step) for it to live. `assets/save-session-skill.md.template` gains the session-log
auto-rollover logic (past 300 lines) added during the plugin era; `assets/sync-memory-skill.md.template`
and `scripts/sync-memory.py.template` gain the plugin era's cursor-data-loss fix (an
explicit two-phase `--mark-synced` commit, replacing an auto-advance-on-print cursor) and
the explicit `project=` MCP-call warnings — all ported forward so migrating off the plugin
doesn't regress functionality gained while it was active.

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
