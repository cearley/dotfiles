# setup-memory-workflow changelog

Starts fresh at v8. Earlier versions (v1–v7) predate this file and are not backfilled —
reconstructing accurate detail for all of them isn't reliably possible, and fabricating
detail would be worse than omitting it.

## v17 (2026-11-07)
Two independent additions, both responding to the same root cause: the `SessionStart`
reminder and `drift-warn` nudge were both purely instructional/mechanical with no visibility
into the status note's actual content or size, so a bloated note or a stale Open list could
sit unnoticed between sessions with nothing surfacing it.

Adds a new `extract_open_excerpt()` function plus `OPEN_EXCERPT_MAX_LINES=15` constant: a
cheap, best-effort local read of the current-status note's `## Open` section, truncated to 15
lines with a "N more open items" trailer when longer. `hook-message.txt.template` gains a new
`__OPEN_EXCERPT__` placeholder, filled by `render()` with this excerpt (or left empty,
rendering byte-identical to the no-excerpt message, on any missing file/section/read
failure) — so the `SessionStart` reminder now surfaces a size-bounded slice of open items
directly, rather than relying entirely on the model's own `search_notes`/`recent_activity`
retrieval judgment.

`cmd_drift_warn()` gains a second, independent signal alongside the existing save-session
version-drift line: it now also checks the current-status note itself for bloat, reusing the
same three thresholds `save-session-maintenance`'s own triage already documents (total size
≥8,000 chars, ≥200 lines, or any single line ≥800 chars) and prints
`[setup-memory-workflow] current-status note looks oversized — run /save-session-maintenance to triage it.`
when any is crossed. Closes the gap where drift and note-bloat could otherwise sit unnoticed
indefinitely between manual `/save-session-maintenance` runs, with nothing nudging a session
to check.

`SMW_VERSION` moves to 17 for both changes together — the rendered `hook-message.txt.template`
content changed (new placeholder), and `check-drift.sh` itself gained the second drift-warn
signal. No migration needed: this is additive/content-only, same as v13's staleness nudge.

## v16 (2026-11-06)
Retires `sync-memory` (the skill + script that distilled SpecStory session logs into a
separate basic-memory note via `--standalone` or cursor-tracked default mode) as a
capability entirely. Confirmed dormant for 3 months, it wrote to a note nobody read —
separate from the one `save-session` actually maintains — and never solved the real
"missed save" problem it was meant to mitigate; that's now addressed directly by the new
`crash-recovery-hook` piece (SessionStart-based, no external API calls) added separately.
`SMW_VERSION` moves to 16 since canonical content changed (one fewer rendered piece).

`check-drift.sh` no longer checks for, creates, repairs, or accepts `apply` for
`sync-memory-skill`/`sync-memory-script` in `cmd_check`/`cmd_update`/`cmd_apply`.
`assets/sync-memory-skill.md.template` and `scripts/executable_sync-memory.py.template`
are deleted outright.

For already-installed projects, no manual step is needed: a new `migrate_sync_memory()`
function in `migrations.sh`, wired in unconditionally alongside the existing
`migrate_hook_config()` call, removes `.claude/skills/sync-memory/` and
`.specstory/.sync-memory-state.json` automatically the next time `check-drift.sh`
runs `check`, `update`, or `apply` in that project.

## v15 (2026-11-02)
`save-session`'s Step 1 (now Step 2) used to find "the most recent session note" with a
fuzzy `search_notes` query. On a real project this just failed: several stale
`Session Log — DATE` notes from an earlier rotation scheme sat alongside the actually-
active session-log note, with nothing in the data or the instruction telling a search
apart from a false match. A title-mode search correctly found the right note; a
follow-up broader search plus an improvised `updated_at`-timestamp comparison across the
stale notes then picked the wrong one, and real content got appended to it before the
mistake was caught and undone.

Reorders the two steps and removes the search for the common case: the status note (now
read first, as Step 1) already ends every entry with a wikilink to wherever that
session's detail lives — Step 1 extracts the **last** wikilink in its most recent Status
Summary entry and hands that note name to Step 2 directly, with no `search_notes` call
at all. `search_notes` is now a fallback used only when the most recent entry has no
wikilink (a brand-new project's first-ever save, or a status note that predates this
convention). No migration needed — this is a content-only change to the rendered skill
body, not a schema/piece change, same as v13.

## v14 (2026-11-02)
Nothing previously stopped an agent from using Bash (or Edit/Write with an absolute
path) to write directly into `~/.local/share/basic-memory/<project>/`, bypassing the
basic-memory MCP server's SQLite index and the per-note checksums `bm_edit` relies on
for optimistic concurrency — a direct write there can make a later `bm_edit` silently
fail its checksum guard, or leave `bm_search`/`recent_activity` stale.

Adds a new `write-guard-hook` piece: a `PreToolUse` hook (matcher `Bash|Edit|Write`)
that denies any write-shaped call targeting the whole `~/.local/share/basic-memory/`
tree (not just the current project's subdirectory — the risk is identical regardless of
which project's notes are targeted) and points the model at `bm_write`/`bm_edit`
instead. Unlike every other managed piece, the guard script itself
(`scripts/executable_basic-memory-write-guard.sh`) is *not* `__PROJECT__`-templated —
it's a plain static script deployed machine-wide by chezmoi, exactly like
`check-drift.sh` itself, modeled directly on the existing
`home/dot_local/bin/executable_claude-tooling-write-guard.tmpl` hook's JSON contract and
Bash-detection heuristics. Only the hook *entry* pointing at its fixed global path is
managed per project (`canonical_write_guard_cmd()`, literal command-string comparison —
no version marker needed). No migration needed — purely additive, same as
`save-session-maintenance-skill` in v12.

## v13 (2026-10-22)
`save-session`'s Step 1/2 now explicitly tell the model to pass `project="__PROJECT__"` on
every basic-memory tool call and to check the result's own `project` field before the next
call. Root cause: basic-memory's `project` parameter is not session-sticky — the server
resolves it per call and silently falls back to a different project if it's omitted,
rather than erroring — so a model correctly passing `project` on earlier calls (e.g.
`search_notes`) can still drop it on a later `edit_note` call without any synchronous
signal beyond the (easily-missed) `project` field in that call's own result. This produced
a real incident: a `save-session` run created a duplicate "Chezmoi Session Notes" note in
the wrong project. No migration needed — this is a content-only change to the rendered
skill body, not a schema/piece change.

The SessionStart hook now also nudges on staleness. `check-drift.sh` gains a `drift-warn`
subcommand (silent and fast: one line if the installed `save-session` skill is behind this
script's own `SMW_VERSION`, nothing otherwise), and the rendered hook command — built by a
new shared `canonical_hook_cmd()` instead of duplicating the same `echo '...'` string in
three places — now calls it via `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/setup-memory-workflow/scripts/check-drift.sh
drift-warn`, redirected and `|| true`'d so a missing/broken script can never break the
primary reminder. Previously a project's deployed pieces could sit arbitrarily far behind
the canonical template with no discovery path short of someone remembering to re-run
`check` by hand.

## v12 (2026-08-27)
Split `save-session` into two skills with separate triggers.

`save-session` is now strictly append-only fast-path work: append to the session log, make a
targeted Open/Resolved edit to the status note, done. All size, rollover and triage logic moved
out into a new `save-session-maintenance` skill, invoked manually via
`/save-session-maintenance`. The two were previously one skill whose triage step (`Step 3b`)
ran opportunistically inside an ordinary save — mixing a mechanical append with a judgment-heavy
restructure of the same note, which is what caused the v8–v11 breakage.

`save-session` also gains two things. A project-root anchor: it resolves the repository root via
`git rev-parse` and verifies it before touching any `.claude/...` path, because Claude Code's
working directory can drift over a long session (an earlier `cd`, or entering a worktree) and
every relative path in the skill assumed the root. And an explicit Step 0 that lets the model run
it on its own initiative without asking for confirmation, gated on a cheap mechanical pre-filter
(non-trivial tool-call/exchange count) followed by judgment — deliberately not gated on whether
any file was edited, since a purely exploratory session can be entirely save-worthy while a
one-typo fix may not be.

`check-drift.sh` gains a sixth piece, `save-session-maintenance-skill`, managed exactly like its
siblings.

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
