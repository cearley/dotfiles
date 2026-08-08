## Context

See proposal.md - Why, for the four bugs this fixes. This document covers the
implementation choices made while fixing them, all already applied in
`plugins/basic-memory-workflow/` and manually verified against scratch git repos.

## Goals / Non-Goals

**Goals:**
- Make the cursor advance only after a distillation is durably in the vault, in default
  (interactive) mode.
- Make a project's first-ever sync see its full backlog by default.
- Make project registration resilient to the plugin becoming active mid-session.
- Make a misfiled write into the wrong basic-memory project loud instead of silent.

**Non-Goals:**
- Changing `--standalone` mode's cursor-commit timing — see Decisions below for why it
  stays a single-step commit.
- Introducing a formal test framework for this plugin's scripts (see proposal.md -
  Non-goals).
- Fixing the underlying "Cloud routing requested but no credentials found." error
  message basic-memory's own MCP server returns for an unregistered project — the fix
  here prevents reaching that state, not the message itself.

## Decisions

**Two-phase cursor commit via an explicit `--mark-synced <mtime>` flag, not a pending-state file.**
Considered writing a `.sync-memory-state.pending.json` in Step 1 and promoting it in a
new Step 4, mirroring a write-ahead log. Rejected: it adds a second state file to reason
about (staleness, cleanup after an abandoned run) for no benefit over simply having the
caller pass the already-known `mtime` value back explicitly. The chosen design keeps
`sync-memory.py` stateless between Step 1 and the commit call — the skill (not the
script) is what tracks "did Step 3 actually succeed," which is exactly where that
knowledge already lives.

**`--mark-synced` refuses to move the cursor backward, rather than always overwriting it.**
A monotonic guard costs one comparison and prevents a stale or out-of-order
`--mark-synced` call (e.g. a retried Step 4 from an earlier, already-superseded Step 1
output) from erasing progress a later run already committed.

**`--standalone` mode keeps its original single-step commit-immediately-after-write behavior.**
The two-phase split exists to bridge the gap between "script prints logs" and "some
external process (a Claude Code session) confirms the write." `--standalone` has no such
gap — it performs the write itself, synchronously, inside `standalone_mode()` — so an
explicit second commit step would add ceremony without closing any real race.

**No cursor means full history by default, with `--since-days` demoted to an optional bound.**
The alternative — keeping the 1-day fallback as default and just documenting it better —
was rejected because it reproduces the exact failure mode this fix addresses (a real log
silently invisible on first sync) for anyone who doesn't happen to read the docs closely.
`--max-logs-per-run` (pre-existing) already exists specifically to bound a large first
scan; leaning on it instead of a silent age filter means the two mechanisms don't
fight each other, and a big backlog degrades to "processed over several runs" rather
than "some of it never surfaces at all."

**Both skills' Step 0 call `ensure-project-registered.sh` instead of `resolve-project-name.sh`, rather than making `resolve-project-name.sh` itself register.**
`resolve-project-name.sh`'s docstring and existing callers (including
`ensure-project-registered.sh` itself) depend on it staying a pure, side-effect-free
query — giving it a registration side effect would be a breaking change to an documented
contract and would create a circular call from `ensure-project-registered.sh` into
itself. Swapping which script the two skills' Step 0/Step 1 call is a drop-in change
(identical stdout contract, `basic-memory project add` is already idempotent per its own
comment) that closes the gap without touching the pure-resolution script at all.
`sync-memory.py`'s own internal `resolve_project_name()` (used by `--standalone` and
default vault-dir resolution) is intentionally left calling `resolve-project-name.sh`
directly — `--standalone` runs unattended (cron), where a mid-session `/reload-plugins`
scenario cannot occur, so the extra registration guarantee isn't needed there.

## Risks / Trade-offs

- [Risk] A user runs `sync-memory.py` (Step 1) manually, gets distracted, and never
  calls `--mark-synced` — the logs stay "unsynced" indefinitely, reprinting on every
  future run until someone commits them. → Mitigation: this is the deliberately safe
  failure direction (re-processing a log is idempotent and cheap; losing one silently is
  not), and the skill's Step 1 instructions tell the caller to remember the `<mtime>`
  value specifically so Step 4 isn't skipped.
- [Risk] `ensure-project-registered.sh` now runs on every `save-session`/`sync-memory`
  invocation instead of being fronted by `SessionStart`. → Mitigation: `basic-memory
  project add` is already documented and relied upon elsewhere as idempotent and cheap
  (exits 0 whether or not the project exists), so the extra calls are a no-op in the
  common case where `SessionStart` already did the work.
