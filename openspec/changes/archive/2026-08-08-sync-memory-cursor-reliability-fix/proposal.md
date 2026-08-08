## Why

A live `/sync-memory` session (2026-08-08, `private-hugo-theme` project) surfaced three
compounding reliability bugs, root-caused via direct filesystem inspection after the
session transcript was reviewed:

1. `sync-memory.py`'s cursor advanced unconditionally at the end of Step 1 — before the
   invoking Claude Code session had distilled anything or written to the vault (Steps
   2-3). When Step 3 hit an error and the session was interrupted, the cursor had
   already moved past both logs, so a subsequent `/sync-memory` run would report
   "No unsynced logs found." even though nothing was ever durably saved. Confirmed: the
   project's vault directory was empty and the state file's cursor covered both logs.
2. On a project's first-ever sync (no state file yet), the script silently fell back to
   a 1-day `--since-days` window instead of scanning full history. A real log with an
   mtime outside that window was dropped entirely and only caught because the user
   happened to remember writing it — without that, `--max-logs-per-run`'s existing
   per-run cap (designed for exactly this "bound a large backlog" case) never got the
   chance to do its job, because the backlog was invisible to begin with.
3. Both `sync-memory` and `save-session` skills' Step 0 call the bare, side-effect-free
   `resolve-project-name.sh` and assume the `SessionStart` hook has already registered
   the project with basic-memory. In the same session, the plugin had just been
   activated via `/reload-plugins` — which does not retroactively fire `SessionStart` —
   so registration never happened, and the first basic-memory MCP call failed with a
   confusing cloud-routing credentials error instead of a clean one.
4. Compounding #1-3: the agent's recovery attempt called `write_note` without an
   explicit `project` parameter, and the MCP tool silently defaulted to an unrelated
   shared vault (`main`) instead of erroring — a second silent-misfile failure mode
   layered on top of the first three.

All four fixes are implemented and manually verified in
`plugins/basic-memory-workflow/` (not yet committed); this change brings
`openspec/specs/sync-memory/spec.md` and `openspec/specs/setup-memory-workflow/spec.md`
back into sync with that implementation, matching the project's established practice of
never leaving spec and code drifted apart (see the 2026-08-08
`setup-memory-workflow-spec-sync` change for the same pattern applied to a related fix
earlier the same day).

## What Changes

- `sync-memory.py` default mode no longer advances the sync cursor itself. A new
  `--mark-synced <mtime>` flag is the sole way the cursor advances in default mode,
  invoked by a new Step 4 in the `sync-memory` skill only after Step 3's vault write is
  confirmed against the correct project. `--standalone` mode is unchanged — it still
  commits its own cursor immediately after writing, since it has no external
  confirmation step to wait for. **BREAKING** (internal-only): a `sync-memory.py`
  invocation with no state file no longer creates one on a bare default-mode run; the
  skill must call `--mark-synced` explicitly.
- `find_unsynced_logs` no longer falls back to a `--since-days` window when no cursor
  exists. With no cursor, it now scans the full `.specstory/history` backlog by default
  (still bounded per-run by the pre-existing `--max-logs-per-run`); `--since-days`
  becomes an optional explicit bound the caller may still pass, effective only when no
  cursor exists yet.
- `sync-memory` and `save-session` skills' Step 0/Step 1 now call
  `ensure-project-registered.sh` instead of the bare `resolve-project-name.sh`, so
  project registration is guaranteed on every invocation of either skill rather than
  assumed to have already happened via `SessionStart` — closing the gap where a plugin
  enabled mid-session (e.g. via `/reload-plugins`) never gets a `SessionStart` firing.
- `sync-memory` skill's Step 3 now requires passing `project="$PROJECT"` explicitly on
  every basic-memory MCP call and verifying the echoed `project:` in the tool result
  before treating a write as successful.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `sync-memory`: cursor-advancement timing (moves from "always, at end of a
  non-dry-run" to "only via explicit `--mark-synced` in default mode"), and first-run
  log discovery (moves from "always falls back to `--since-days`" to "full history by
  default, `--since-days` now optional").
- `setup-memory-workflow`: runtime project identity resolution requirement's
  description of which script `save-session`/`sync-memory`'s Step 0 call (moves from
  "`resolve-project-name.sh` directly, pure resolution only" to
  "`ensure-project-registered.sh`, resolution plus guaranteed registration").

## Impact

- `plugins/basic-memory-workflow/scripts/sync-memory.py` (already edited)
- `plugins/basic-memory-workflow/skills/sync-memory/SKILL.md` (already edited)
- `plugins/basic-memory-workflow/skills/save-session/SKILL.md` (already edited)
- `openspec/specs/sync-memory/spec.md`, `openspec/specs/setup-memory-workflow/spec.md`
  (this change)
- No chezmoi-managed dotfiles, scripts, or tags are affected — this plugin lives outside
  `home/` and is not chezmoi-templated. No secrets or SIP-relevant permissions involved.

## Non-goals

- Not adding a formal automated test suite (pytest/bats) for this plugin — this change
  follows the repo's existing verification convention for these scripts (scratch git
  repo scenarios), consistent with how prior fixes to this same plugin were verified.
- Not changing `--standalone` mode's cursor-commit behavior — it has no external
  confirmation step to defer to, so immediate self-commit after a successful write
  remains correct for that path.
- Not addressing the confusing "Cloud routing requested but no credentials found." error
  message itself — the fix here is to prevent hitting that state (defensive
  registration), not to improve the message basic-memory's own MCP server returns.
