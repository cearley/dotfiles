# setup-memory-workflow changelog

Starts fresh at v8. Earlier versions (v1–v7) predate this file and are not backfilled —
reconstructing accurate detail for all of them isn't reliably possible, and fabricating
detail would be worse than omitting it.

## v11 (2026-08-17)
v10's Step 3b triage trigger (≥200 lines) was itself confirmed insufficient the same day
it shipped: running `/save-session` against a real status note found it broke
`read_note`/`read_content` outright at 70,270 characters while sitting at only ~117
lines — comfortably under the trigger. Inspecting the raw content (via the local temp
file the MCP server's own error message pointed to) showed the actual failure mode:
a single "Last updated" line had grown to 9,196 characters by having a new "(latest:
...)" paragraph prepended every session instead of ever being condensed, with several
Resolved bullets showing the same pattern at 1,500–3,300 characters each. Line count
never catches "a few entries growing forever" — only "many distinct entries."

Step 3b now checks three independent signals instead of one: a failed read itself
(treated as the strongest signal, since a note past the read ceiling can't be inspected
to check any threshold), total size at or over ~8,000 characters (a conservative margin
below the ~70K point observed to break reads), and any single line/paragraph over ~800
characters (the direct anti-pattern signal, independent of overall note size). Step 3
also now tells the agent to skip straight to Step 3b's read-failure handling rather than
retrying a failed read.

## v10 (2026-08-17)
`assets/save-session-skill.md.template`'s Step 3 (current status note) had a rollover
guard for the session log (Step 2, 300-line trigger) but nothing analogous for the status
note itself — it was edited in place forever with no size check, and one real install's
status note grew to 69,086 characters before a `read_note` call hit the MCP server's
output-token ceiling and failed outright. Adds Step 3b: at or over 200 lines, triage the
note instead of just editing it — delegate to the `memory-defrag` skill when installed
(its audit → plan → execute → verify → log workflow already targets exactly this failure
mode), falling back to manual reference/known-issues/archive triage otherwise, and prefer
the `memory-lifecycle` skill's `move_note`-based archive-never-delete pattern (preserves
permalinks, so existing `[[wiki-links]]` keep resolving) over copy-and-delete when moving
content out. Both are optional companion skills, not new hard dependencies — Step 3b
degrades to manual triage if neither is installed.

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
