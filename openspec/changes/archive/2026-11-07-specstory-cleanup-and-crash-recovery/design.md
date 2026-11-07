# Design

## Context

See `proposal.md` - Why. Three independently-shippable pieces of implementation detail follow:
the dedupe tool's discovery/removal algorithm, the Stop-hook scoping fix, and the no-spawn
crash-recovery hook's architecture (reusing dead-but-present detection code at
`~/.claude-personal/skills/setup-memory-workflow/scripts/session-start-maintenance-check.sh.template`,
confirmed unreferenced by `check-drift.sh` or any live hook config).

## Goals / Non-Goals

**Goals:**
- Clear the existing ~9.7MB SpecStory duplicate backlog across every project on every machine,
  without risking data loss on the one confirmed non-prefix pair.
- Reduce (not necessarily eliminate) future duplicate production from the Stop hook.
- Close the "session ends before `/save-session` runs" gap without reintroducing the
  `claude -p`-from-a-hook recursion that caused the 2026-08-24 fork-bomb.

**Non-Goals:**
- Not attempting to fix SpecStory's own internal title/slug-renaming behavior — that's upstream,
  out of our control.
- Not reviving the `save-session-maintenance` size/rollover auto-trigger (the other half of the
  dead template) — still spawn-based, explicitly deferred.
- Not building a `specstory-organize`-style skill wrapper around the dedupe tool — a plain CLI
  tool is sufficient; the logic is fully mechanical (byte-prefix comparison), no judgment calls
  needed.

## Decisions

**1. `specstory-dedupe-history` is a global `dot_local/bin` script, not a skill or a one-off.**
Every project with SpecStory active can hit the same duplication, and the backlog needs clearing
on more than one machine. A skill would add an LLM-judgment layer this problem doesn't need (the
prefix-check is fully deterministic); a one-off script would need rewriting the next time this
recurs. Matches the existing `check-claude-overrides`/`claude-tooling-write-guard` distribution
pattern: one script, deployed machine-wide by `chezmoi apply`, invoked by bare name.
*Alternative considered:* a per-project script installed like `save-session` — rejected, since
nothing about this tool is project-specific (it already needs to scan every project from one
invocation).

**2. Safe-deletion test is byte-prefix, not heuristic similarity.**
Spot-checking confirmed the common case (SpecStory writes a new file when its inferred title
changes mid-sync) produces an exact byte-for-byte prefix relationship between the smaller and
larger file. One counter-example was found (`2026-10-08_13-31-30Z*`, differing by inserted
separator lines, not a strict subset) — proof that a size- or mtime-based heuristic alone would
occasionally choose wrong. Byte-prefix comparison is cheap (one linear scan) and has zero false
positives by construction: if it reports "safe," it is safe.
*Alternative considered:* content-similarity diffing (e.g. line-based diff ratio) — rejected as
more complex for no benefit, since the non-prefix cases need human review regardless of how
"close" the diff ratio says they are.

**3. The Stop hook fix scopes to session, but is not guaranteed to fully eliminate duplicates.**
`specstory sync claude -s "$SESSION_ID"` is the documented, targeted form (vs. the current
undocumented `--providers claude`). It should eliminate cross-session backlog-resync bursts (like
the 55-file burst on 2026-10-15), and reduces exposure to the title-change-triggered duplicate
within a single session's own resyncs. It cannot provably eliminate that pattern entirely, since
SpecStory's internal slug inference is opaque to us. This is why `specstory-dedupe-history` is
kept as a standing tool rather than deleted after the one-time backlog cleanup — it's the
fallback if the fix turns out to be partial.
*Verification note:* this cannot be exercised by actually running `specstory sync` during
planning (no real hook event to trigger); the first real Stop event after deployment is the
actual test (see tasks.md).

**4. Crash-recovery moves the work from a spawned process to hook stdout, not from SessionEnd to
SessionStart alone.** The memory note on the abandoned branch states the durable lesson plainly:
"the better answer is usually to make the worker something that isn't a Claude Code session,
which removes the recursion by construction." Hook stdout is already a proven mechanism in this
project — the existing `SessionStart` hook already injects a reminder this way, and the model
already reliably acts on it (observed at the start of this very conversation). Extending that
same channel with a second, conditional reminder needs no new primitive, no lock directory, no
`nohup`, and nothing that can itself become a Claude Code session.
*Alternative considered:* keep the `SessionEnd`-side detached worker but harden its locking
further (a fourth attempt, after three rounds already failed per the archived
`autonomous-save-session` change) — rejected: the lesson from that change is that a spawned
`claude -p` is categorically the wrong shape for this problem, not a shape that needs one more
careful lock.

**5. `crash-recovery-hook` is deployed as a single global static script (like
`basic-memory-write-guard.sh`), not a per-project template.** The detection logic needs no
`__PROJECT__` substitution — it only reads `session_id`/`transcript_path`/`cwd` from hook stdin
and compares local file mtimes. Templating it per-project like `save-session` would add
indirection with no payoff; only the `SessionStart` hook *entry* pointing at the fixed global path
needs to exist per project, matching the `write-guard-hook` precedent exactly.

**6. The marker (`.claude/.last-saved-session`) is touched by content, not just existence.**
`save-session` touches it on both "On success" and the Step 0 no-op/skip path — a session that's
correctly judged as having nothing worth saving still counts as "evaluated," and must advance the
signal, or the crash-recovery hook would misfire on every trivial session.

## Risks / Trade-offs

- **[Risk] The dedupe tool's byte-prefix check could still misjudge an edge case not seen in spot
  checks (e.g. two files that happen to share a long byte-identical prefix by coincidence, not
  because one is a resync of the other).** → Mitigation: the check also requires matching embedded
  session UUIDs before comparing bytes at all, making an unrelated-file false match effectively
  impossible; dry-run-by-default means every deletion is reviewable before `--apply`.
- **[Risk] Scoping the Stop hook to `-s "$SESSION_ID"` assumes SpecStory's session-ID format for
  the `claude` provider matches Claude Code's own `session_id` field verbatim.** → Mitigation:
  this is directly inferable from existing `.specstory/history/*.md` files, which already embed
  `<!-- Claude Code Session <uuid> -->` using exactly that UUID; first real post-deploy Stop event
  is the actual confirmation (tasks.md verification step).
- **[Risk] A double-crash (two sessions in a row both ending before any save evaluation) only
  surfaces the more recent gap — the older one is silently skipped.** → Mitigation: accepted as a
  known limitation; the common single-crash case is what this is built for, and engineering for
  the double-crash case adds complexity for a rare scenario with no reported incidents.
- **[Trade-off] `crash-recovery-hook`'s catch-up instruction runs inline in whatever session
  happens to start next, adding a few extra tool calls to that session before it gets to the
  user's actual request.** Accepted deliberately — it's bounded (one prior transcript, one
  save-session pass) and paid for by the session's own already-budgeted usage, not a new cost
  center.
- **[Risk] (2026-11-07) No liveness check: a session still genuinely running concurrently in the
  same project directory can be misidentified as the "latest prior" session and incorrectly
  flagged as crashed**, because the hook only compares *identity* (did the latest-by-mtime prior
  transcript's session ever save), never *is that session still alive*. A real liveness check is
  buildable — `$CLAUDE_PID` is confirmed exported to hook subprocesses and could back a
  `kill -0`-based check against a small session_id→PID registry — but was deliberately not built:
  it only matters when two sessions run in the exact same project directory at the exact same
  time (not just concurrently anywhere), and the failure mode is a spurious, harmless catch-up
  instruction (the next session re-reads a transcript that turns out to have nothing new to add),
  never data loss. Accepted as a known limitation, same posture as the double-crash gap above.

## Post-Implementation Finding (2026-11-06)

Task 1.3's real-world run against this repo's own `.specstory/history/` (173 sessions, 41 UUID
groups with 2+ files) found only **~382KB** safely reclaimable (5 pairs), not the ~9.7MB the
`/research` pass estimated — contradicting that pass's claim of having "confirmed by diffing
pairs" that the common case is a clean byte-prefix relationship. Root cause: SpecStory's own
`# <timestamp>` header line reflects the time of *that sync*, not session start, so it changes on
every resync — breaking a literal whole-file byte-prefix match even for genuine append-only
growth. Stripping the header and re-comparing recovers only 10 more pairs, all degenerate
empty-session stubs (~1.6KB total, not worth a tool change). The remaining 26 of 36 "conflict"
pairs in this repo have **genuinely reordered message content** between syncs (verified by direct
diff — e.g. `<local-command-stdout>` and `<local-command-caveat>` swap relative order), not pure
append growth. The byte-prefix safety check (Decision 2) is implemented correctly and is not a
defect; the `/research` session note's duplicate-count/size estimate for this repo was simply
too optimistic, extrapolated from a small sample. The dedupe tool is still worth keeping
machine-wide, since other projects' backlogs (observed: ~20.5MB safely reclaimable across all of
`$HOME`) are real even though this repo's own backlog is small.

## Migration Plan

1. Ship `specstory-dedupe-history` and run it (dry-run, then `--apply`) on this Mac to clear the
   existing backlog before relying on it anywhere else.
2. Ship the Stop-hook scoping fix across all four personas; observe the next few real Stop events
   for new duplicates before considering the fix validated.
3. Ship the `sync-memory` removal and `crash-recovery-hook` addition together (both are
   `setup-memory-workflow` piece-registry changes, naturally bundled in one `SMW_VERSION` bump).
4. **Mac Studio checklist (2026-11-07)** — `chezmoi apply`/`update` alone does not fully roll this
   change out; everything below was found by actually exercising each piece on this Mac during
   implementation, not assumed. Do these in order:
   1. `chezmoi update` (or `git pull` + `chezmoi apply -v`) to pull this change and deploy it.
      Expect no destructive prompts; a `.zshrc has changed since chezmoi last wrote it?`-style
      warning (if any) is non-fatal and was already seen harmlessly on this Mac.
   2. **Restart every already-open `claude` pane/session on the Mac Studio** (exit and relaunch).
      An already-running session — especially one launched through `hcom`, which snapshots a
      merged settings file per launch (`~/.hcom/integrations/claude/<hash>/settings.json`) — will
      keep using its pre-apply hook config until relaunched fresh. This was the actual root cause
      of two apparently-failed verification attempts on this Mac; a fresh pane picked up the fix
      immediately both times.
   3. For **every project on the Mac Studio that has `setup-memory-workflow` installed**
      (anywhere with a `.claude/skills/save-session/` directory), run
      `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/setup-memory-workflow/scripts/check-drift.sh
      update` inside that project. `chezmoi apply` only refreshes the *global* canonical
      templates/scripts under `~/.claude/skills/setup-memory-workflow/` — it does not touch any
      individual project's already-installed copy. This per-project `update` is what actually:
      - fires `migrate_sync_memory()`, removing that project's installed `.claude/skills/sync-memory/`
        and `.specstory/.sync-memory-state.json` if present (silent no-op if already clean)
      - creates the new `crash-recovery-hook` `SessionStart` entry in that project's
        `.claude/settings.local.json`, alongside the existing reminder entry (never replacing it)
      - refreshes `save-session`'s installed `SKILL.md` to `SMW_VERSION 16` (the reordered
        anchor-before-Step-0 fix, and the identity-based marker write)
      This can be skipped for now and left to the existing `drift-warn` nag (the `SessionStart`
      reminder hook already prints a one-line staleness warning once a project's installed
      `save-session` version falls behind) — but don't assume it already happened just because
      `chezmoi apply` ran.
   4. Run `specstory-dedupe-history` (dry-run, no flags) from `$HOME` on the Mac Studio and
      inspect the manifest before applying — this machine's backlog is independent of this one's
      and was never touched by this Mac's cleanup. Then run `specstory-dedupe-history --apply`
      for real once satisfied with the manifest.
   5. Task 5.2: check whether
      `~/.claude-personal/skills/setup-memory-workflow/scripts/session-start-maintenance-check.sh.template`
      and `.../session-end-save-hook.sh.template` exist on the Mac Studio at all (they may be
      specific to this Mac's abandoned `autonomous-save-session` branch history). If present,
      delete them directly — **not** via an agent/subagent: the `claude-tooling-write-guard` hook
      blocks a Claude Code session from writing/deleting inside a chezmoi-tracked skill directory
      by design, even for a file (like these) that was never actually chezmoi-managed. This was
      hit on this Mac and had to be done by hand for exactly that reason.
   6. Optional sanity check, mirroring how this Mac's fix was verified: start a fresh session in
      any project with the pieces installed, ask it "What system-reminder(s), if any, did you
      receive at the start of this session?", and confirm the reminder text matches what's
      expected (no stray crash-recovery catch-up unless a prior session on that Mac genuinely
      never evaluated).
5. Rollback, if needed: revert the `Stop`/`SessionStart` hook command strings to their prior
   values (recoverable from git history) and restore the deleted `sync-memory` templates from git
   history — no destructive migration step here has no revert path.
