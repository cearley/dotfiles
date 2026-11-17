# Design

## Context

See `proposal.md` - Why for the evidenced friction this addresses. Relevant current-state facts
that shape the approach:

- `check-drift.sh` already exposes separate subcommands (`check`, `drift-warn`, `authorize`,
  `install`/`update`/`apply`), each sourcing the same four library files
  (`lib-consent.sh`, `lib-project.sh`, `lib-runtime.sh`, `lib-session-log.sh`) plus
  `lib-status-note.sh` independently per invocation.
- `authorize_save()` (in `lib-consent.sh`) already independently re-derives and checks the
  installed skill's version marker and resolved project identity for the save path - the same
  ground `check`'s broader piece-by-piece report covers, just narrower in scope.
- `lib-status-note.sh`'s `check_status_note_bloat()` already implements the exact three-signal
  oversized check (chars/lines/longest-line) as a cheap, read-only, local filesystem read (no
  MCP round trip). It's currently only called from the `SessionStart` hook path
  (`session-reminder.sh`), never from the save path itself.
- `SessionStart` currently chains two separate script invocations
  (`session-reminder.sh`, then `check-drift.sh drift-warn`), each independently sourcing all
  five library files and re-deriving `$PROJECT`.
- Existing Status Summary entries are written as a single long prose paragraph per session with
  no internal line breaks, which is why a "line count" cap only becomes meaningful once new
  entries are also required to be written as several short, explicit lines rather than one
  flowing paragraph.

## Goals / Non-Goals

**Goals:**
- Make the Status Summary entry-length cap and oversized-gate mechanically checkable, not just
  a prose instruction the model might skip - by reusing the existing, already-tested
  `check_status_note_bloat()` logic as a real precondition check, not a self-reported judgment.
- Remove one redundant subprocess invocation and one redundant library-sourcing pass from both
  the save path and the `SessionStart` path, without changing what either path reports.
- Keep every change inside `setup-memory-workflow`'s existing script/template architecture
  (shared `lib-*.sh` files, `SMW_VERSION` marker, `check-drift.sh` as the one CLI entry point) -
  no new scripts, no new tools, no new dependencies.

**Non-Goals:**
- Not building a mechanical, enforced-at-the-MCP-layer block on writing to the status note (e.g.
  extending `basic-memory-write-guard.sh`). The gate is enforced by `/save-session`'s own
  instructions plus a deterministic shell precheck it must consult - not a hook that can refuse
  the `bm_edit` call itself. See proposal.md - Non-goals for the broader reasoning (no
  automation of judgment-heavy restructuring).
- Not changing `check-drift.sh check`'s own behavior, scope, or output - only removing the one
  call site in `/save-session`'s Preflight.

## Decisions

**1. The Status Summary cap is 5 physical lines per entry, written as explicit short lines, not
one paragraph.** A pure character cap (matching the existing 800-char single-line anti-pattern
signal) would be simplest to enforce, but doesn't change the model's writing style - it would
still produce one long paragraph until it happened to hit the character ceiling. Pairing a line
cap with an explicit instruction to write the entry as several short lines (a date line, 1-3
short content lines/bullets, a `Detail: [[...]]` line) makes "line count" an actually meaningful,
checkable signal, consistent with how the Open section's items are already written one bullet
per line. 5 lines is enough for a date, a one-to-two-sentence summary, and the detail link;
anything requiring more belongs in the session log, which every entry already links to.
Alternative considered: a pure character ceiling with no line-count requirement - rejected
because it doesn't fix the actual anti-pattern (one ever-growing paragraph), it just moves the
ceiling.

**2. The oversized-gate check is a real shell precondition, not a model self-assessment.**
`/save-session`'s Step 1 calls a new, tiny read-only `check-drift.sh` subcommand that wraps the
existing `check_status_note_bloat()` function and returns a clear boolean-style result (e.g.
exit 0 = under threshold, exit 1 = oversized) before the model drafts the new entry. This reuses
already-tested logic instead of asking the model to count characters/lines in a note it may not
even have read in full. Alternative considered: have the model infer size from the `bm_read`
receipt it already has (e.g. content length) - rejected because Step 1's `bm_read` may return a
truncated/sectioned view (per BM 1.x `max_tokens` truncation), so the model's own view of "how
big is this note" cannot be trusted as the oversized signal; the shell check reads the whole
file directly, the same way the `SessionStart` hook already does.

**3. `SessionStart`'s double library-sourcing is fixed by extracting `drift-warn`'s check into a
shared function, not by merging the two scripts into one file.** `check-drift.sh drift-warn`'s
logic moves into a small function in a library file (alongside `check_status_note_bloat()` and
`check_session_log_bloat()` in `lib-status-note.sh`/`lib-session-log.sh`, or a new
`lib-drift-warn.sh` if it doesn't fit either), sourced by both `check-drift.sh` (so the
standalone `check-drift.sh drift-warn` command keeps working unchanged for manual use) and
`session-reminder.sh` (which calls the function directly, in-process, instead of exec'ing
`check-drift.sh` as a second subprocess). Alternative considered: merge `session-reminder.sh`
and `check-drift.sh drift-warn` into one combined hook script - rejected because it would
retire `check-drift.sh drift-warn` as an independently runnable command, which is used outside
the `SessionStart` path (e.g. by `bulk-update-memory-workflow`-style manual sweeps) and has its
own bashunit suite.

**4. Removing `check-drift.sh check` from Preflight is a scope cut, not a behavior swap.**
`/save-session`'s Preflight keeps only the `authorize` call. No replacement logic is added,
because `authorize_save()` already covers the version/identity ground that matters for a save;
`check`'s additional piece-by-piece hook/skill/MCP-tool-contract report was never actually acted
on by the save path even when it ran. `/setup-memory-workflow` and
`save-session-maintenance`'s Step 0 remain the places that broader report still runs.

## Risks / Trade-offs

- **[Risk]** A genuinely complex session might not fit in a 5-line Status Summary entry. →
  **Mitigation**: no information is lost - the full narrative stays in the session log, linked
  via `Detail: [[...]]`, which is already the de facto authoritative detail source today (nearly
  every existing entry already links out this way).
- **[Risk]** The gate could still be skipped if the model doesn't call the new check-drift
  subcommand (a prose instruction can be ignored, which is the exact failure mode motivating
  this change in the first place). → **Mitigation**: unlike the maintenance nag, this check is
  cheap, synchronous, and sits directly in the one path the model is already executing (Step 1
  of `/save-session`, not a separate skill invocation the user has to remember) - closer to how
  the existing consent check (`authorize`) is already reliably exercised every save, since it's
  inline rather than a reminder to act on separately.
- **[Risk]** Extracting `drift-warn` into a shared function could regress the standalone
  `check-drift.sh drift-warn` command. → **Mitigation**: pure refactor, no output change; its
  existing bashunit suite must pass unchanged before this is considered done.
- **[Risk]** Removing `check-drift.sh check` from the save path could theoretically miss a
  drift signal `authorize` doesn't independently catch. → **Mitigation**: confirmed by reading
  `authorize_save()` that it already re-derives and checks the same version/project-identity
  markers; `check`'s broader scope (all templated/hook pieces, not just the save-relevant ones)
  remains available on demand via `/setup-memory-workflow` and `save-session-maintenance`'s
  Step 0.
- **[Risk]** A future model could still guess wrong `bm_edit`/`bm_read` parameter names even
  with a corrected example present. → **Mitigation**: inherent to prompt-based correctness: this
  change at least ensures one concrete, correct example exists where none did before, which is
  the direct, evidenced cause of both live bugs found.

## Migration Plan

- Bump `SMW_VERSION` to the next integer (current latest is v22, 2026-11-13); add the
  corresponding `CHANGELOG.md` entry describing all four changes in this proposal.
- Add/extend bashunit coverage: the new oversized-check subcommand, the extracted
  `drift-warn` function (asserting parity with its pre-refactor output), and the Step 1
  entry-format/gate behavior described by the new spec requirements.
- No data migration needed - the live oversized note is deliberately left untouched (see
  proposal.md - Non-goals); a separate, explicit `/save-session-maintenance` run handles it.
- Roll out through the existing `check-drift.sh update` mechanism; every project with
  `setup-memory-workflow` installed picks up the new version on its own next update or
  `bulk-update-memory-workflow` sweep - no special migration step beyond the normal version
  bump.
- Rollback: revert the commit and re-run `check-drift.sh update` to redeploy the prior version,
  same as any other `setup-memory-workflow` version regression.

## Open Questions

- Exact name/placement of the new read-only `check-drift.sh` subcommand that exposes
  `check_status_note_bloat()` to the save path (e.g. a new `status-bloat` subcommand vs. a flag
  on an existing one). Safely deferrable to implementation - it doesn't change the spec
  requirements, the chosen approach, or the task breakdown, only the exact CLI surface.
