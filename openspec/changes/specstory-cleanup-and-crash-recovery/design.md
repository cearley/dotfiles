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

## Migration Plan

1. Ship `specstory-dedupe-history` and run it (dry-run, then `--apply`) on this Mac to clear the
   existing backlog before relying on it anywhere else.
2. Ship the Stop-hook scoping fix across all four personas; observe the next few real Stop events
   for new duplicates before considering the fix validated.
3. Ship the `sync-memory` removal and `crash-recovery-hook` addition together (both are
   `setup-memory-workflow` piece-registry changes, naturally bundled in one `SMW_VERSION` bump).
4. Run `chezmoi apply` on the Mac Studio; re-run `specstory-dedupe-history --apply` there for its
   own backlog.
5. Rollback, if needed: revert the `Stop`/`SessionStart` hook command strings to their prior
   values (recoverable from git history) and restore the deleted `sync-memory` templates from git
   history — no destructive migration step here has no revert path.
