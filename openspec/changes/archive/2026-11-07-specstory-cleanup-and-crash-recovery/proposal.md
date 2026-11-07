# Proposal

## Why

A `/research` pass on SpecStory utilization found its Stop-hook-based capture is genuinely
valuable — `.specstory/history/` is now the *only* surviving record of session content past
Claude Code's own transcript retention window — but surfaced two real problems: 39 of 173
tracked sessions (22.5%) have duplicate markdown files (~9.7MB wasted, caused by the Stop hook
resyncing on every session end and SpecStory renaming files when its inferred title changes), and
the Stop hook itself runs an undocumented `--providers` flag that `specstory sync --help` doesn't
list. Separately, discussion surfaced the actual pain point behind interest in `sync-memory`: a
session can terminate (crash, kill, closed terminal, context exhaustion) before `/save-session`
ever runs, leaving the basic-memory status/session-log notes stale with no record — and
`sync-memory`, even automated, doesn't fix that; it only writes to a side note nobody reads.

This supersedes the abandoned `memory-distiller` change (archived 2026-11-06,
`openspec/changes/archive/2026-11-06-memory-distiller/`), which tried to solve the missed-save
problem by removing SpecStory and polling native JSONL with a machine-level launchd worker. That
removal decision didn't hold up once SpecStory's raw-archive value was established, and a simpler
crash-recovery mechanism was found: the abandoned `autonomous-save-session` branch's detection
logic (find the latest prior session transcript, compare against a last-saved marker) is sound —
only its `spawn_headless()` / `claude -p` call was the problem (the literal cause of a fork-bomb
forced reboot, 2026-08-24). Feeding the same catch-up instruction back as hook **stdout** instead
of spawning a process lets the *already-starting* session do the catch-up itself inline, with no
new process and no recursion possible by construction.

## What Changes

- **New:** `specstory-dedupe-history`, a machine-wide CLI tool (`home/dot_local/bin/`) that finds
  every project's `.specstory/history/` via `fd`, groups files by embedded session UUID, and
  reports (dry-run by default) or removes (`--apply`) files that are an exact byte-prefix of a
  sibling duplicate. Non-prefix divergent pairs are always left for manual review.
- **Changed:** the Stop hook's `specstory sync` invocation moves from an undocumented
  `--providers claude` flag to a small wrapper (`specstory-sync-session`) that reads the hook's
  own `session_id` from stdin and scopes the sync to that one session (`specstory sync claude -s
  "$SESSION_ID"`), across all four persona settings files.
- **BREAKING — `sync-memory` is removed entirely** (skill, script, template, and its
  `check-drift.sh` pieces). Confirmed independently of `memory-distiller`'s reasoning: the note it
  produces is separate from the one `/save-session` actually maintains, and it sat unused for 3
  months. The existing distilled-insights basic-memory note is left in place as a historical
  artifact, not migrated.
- **New:** a `crash-recovery-hook` piece in `setup-memory-workflow`, adapted from the dead (but
  still-present-on-disk, unreferenced) `session-start-maintenance-check.sh.template`'s detection
  logic with `spawn_headless()` removed. At `SessionStart`, it compares the latest prior session
  transcript's mtime against `.claude/.last-saved-session`'s mtime and, if the prior session
  postdates it, emits a catch-up instruction to stdout for the current (already-starting) session
  to act on — never spawning a new process.
- **Changed:** `save-session`'s own "Step 0 — no-op" and "On success" paths now touch
  `.claude/.last-saved-session`, giving the crash-recovery hook an accurate signal of when a
  session's save decision was last evaluated.
- Deletes the two orphaned, unreferenced template files left over from the abandoned
  `autonomous-save-session` branch (`session-start-maintenance-check.sh.template`,
  `session-end-save-hook.sh.template`) after salvaging the detection logic above.

**Explicitly not changed:** the `save-session-maintenance` size/rollover trigger in the same dead
template is a separate, still-spawn-based mechanism and stays out of scope — only the
crash-recovery half is revived here.

## Capabilities

### New Capabilities
- `specstory-history-maintenance`: keeps SpecStory's `.specstory/history/` captures complete and
  deduplicated — the Stop hook's per-session sync scoping, and the standalone dedupe tool for
  cleaning up existing/future duplicate files across every project on the machine.

### Modified Capabilities
- `setup-memory-workflow`: the distributed-pieces requirement drops `sync-memory` from its piece
  list and gains the new `crash-recovery-hook` piece; a new requirement covers the
  marker-touch/crash-recovery contract between `save-session` and the new hook.
- `sync-memory`: all 11 requirements removed — the capability is retired.

## Impact

- **Affected scripts/templates:** `home/dot_local/bin/` (two new executables), all four
  `home/dot_claude*/.claude-settings.json` (Stop hook command change), `setup-memory-workflow`'s
  `scripts/executable_check-drift.sh` (piece registry), `assets/save-session-skill.md.template`
  (marker touch), a new `assets/crash-recovery-hook.sh.template`, and deletion of
  `assets/sync-memory-skill.md.template` + `scripts/executable_sync-memory.py.template`.
- **Affected tags:** none — these are global `dot_claude*`/`dot_local/bin` pieces, not
  tag-gated package installs. `fd` (used by `specstory-dedupe-history`) is already declared in
  `packages.yaml`'s `core` block.
- **Machines:** changes apply via `chezmoi apply` on every machine (this Mac and the Mac Studio);
  the dedupe tool's `--apply` backlog cleanup needs to be run by hand once per machine.
- **No security/secrets impact:** no new credentials; `crash-recovery-hook` reads only local
  transcript files already readable by the user, and never calls an external API.
