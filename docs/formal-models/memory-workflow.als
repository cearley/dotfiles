/*
 * memory-workflow.als — structural invariants of the setup-memory-workflow skill.
 *
 * Scope: two sets of requirements, both traced back to source:
 *   (A) CURRENT spec   — openspec/specs/setup-memory-workflow/spec.md
 *   (B) PROPOSED delta — openspec/changes/memory-workflow-sessionstart-improvements/
 *                        specs/setup-memory-workflow/spec.md
 *
 * Deliberately NOT covered here: the crash-recovery hook's session-identity-vs-mtime
 * comparison. That requirement ("Crash-recovery hook detects a session that ended
 * without a completed save", spec.md line 72) was already modeled and verified in a
 * separate Alloy model earlier the same day:
 *   /private/tmp/claude-501/-Users-craig--local-share-chezmoi/9a4434d1-362e-4dd0-8448-f8ac4373f4e6/scratchpad/alloy-crash-recovery/crash_recovery.als
 * That model proved the shipped session-ID comparison correct and an earlier
 * mtime-based design unsound — exactly the history spec.md line 73 now documents
 * ("by session-ID identity, not transcript mtime — an earlier mtime-based design was
 * proven unsound"). Re-deriving it here would duplicate, not add, coverage.
 *
 * Method: for each invariant, model BOTH the spec-compliant policy and a plausible
 * "naive"/buggy alternative, then show (check) the compliant policy satisfies the
 * invariant and (run) the naive one does not. A `check` with no counterexample
 * prints nothing on the CLI (no "valid" line) — absence of output across a `-c`
 * run is the pass signal. A `run` is expected to find an instance (SAT).
 */

module memory_workflow

-- ============================================================================
-- PART A — current spec: the piece drift/lifecycle state machine
--
-- Traces to spec.md requirements:
--   "Skill is distributed as per-project rendered copies, not a shared reference"
--   "Version drift is unconditionally repairable via `update`"
--   "Identity mismatch always takes precedence over version drift and is never
--    auto-repaired" (incl. the "Simultaneous version drift and identity mismatch"
--    scenario this section is built around)
-- ============================================================================

sig Project {}

-- An installed piece (save-session skill, hook entry, etc.) always belongs to
-- exactly one project, and carries whatever project-identity its rendered
-- content currently has baked into it (identityBaked). These can differ when
-- a project directory has been renamed since the piece was last rendered —
-- that's exactly what NAME-MISMATCH detects.
sig Piece {
  owner: one Project,
  identityBaked: one Project
}

-- Pieces whose embedded VERSION marker is older than the skill's current
-- SMW_VERSION, independent of identity. (We don't need actual version numbers —
-- only "stale or not" matters to every requirement in scope.)
sig StaleVersion in Piece {}

pred isMismatch[p: Piece] { p.identityBaked != p.owner }
pred isDrift[p: Piece]     { p in StaleVersion and not isMismatch[p] }
pred isUpToDate[p: Piece]  { p not in StaleVersion and not isMismatch[p] }
pred isNameMismatch[p: Piece] { isMismatch[p] }

-- Sanity restatement of "Identity mismatch always takes precedence over version
-- drift": a piece that is both stale and mismatched is classified as
-- NAME-MISMATCH, never as DRIFT. True by construction of isDrift/isNameMismatch
-- above; checking it anyway catches a definition mistake, not just documents intent.
assert namemismatch_takes_precedence {
  all p: Piece | (isMismatch[p] and p in StaleVersion)
    implies (isNameMismatch[p] and not isDrift[p])
}
check namemismatch_takes_precedence for 6

-- Overwriting a piece (re-rendering it) bakes BOTH the current version and the
-- current owning-project identity in one pass — check-drift.sh's render() can't
-- fix one without fixing the other, because both come from the same sed
-- substitution over the same template. So "which pieces get overwritten" is the
-- one lever that determines whether identity ever gets silently fixed.
--
-- specTouches: the policy update.sh actually implements — overwrite only DRIFT
-- pieces (stale, not mismatched).
pred specTouches[p: Piece]  { isDrift[p] }
-- naiveTouches: a plausible bug — overwrite every stale piece, without checking
-- identity first. This is exactly the shortcut the spec's "Simultaneous version
-- drift and identity mismatch" scenario forbids.
pred naiveTouches[p: Piece] { p in StaleVersion }

-- A piece remains mismatched after an overwrite pass iff it was mismatched
-- before AND was not among the touched (overwritten) pieces — touching always
-- re-bakes the owner's identity, by the render()-does-both argument above.
fun postMismatched[touched: set Piece]: set Piece {
  { p: Piece | isMismatch[p] and p not in touched }
}

-- THE invariant: under the real `update` policy, every mismatched piece is
-- still mismatched afterward — update() never silently repairs identity.
-- Expect: holds (no counterexample).
assert spec_update_never_silently_fixes_identity {
  all p: Piece | isMismatch[p] implies p in postMismatched[{q: Piece | specTouches[q]}]
}
check spec_update_never_silently_fixes_identity for 6

-- The same claim under the naive policy should FAIL to hold in general — i.e.
-- there's a reachable instance where naive update DOES silently fix identity on
-- a piece that was both stale and mismatched. This is the counterexample the
-- spec's manual-confirmation gate (`apply`, after explicit user confirmation)
-- exists to prevent automatically.
run naive_update_silently_fixes_identity {
  some p: Piece |
    isMismatch[p] and p in StaleVersion
    and p not in postMismatched[{q: Piece | naiveTouches[q]}]
} for 4

-- Creating a previously-missing piece (no confirmation needed, per "Missing
-- piece is created unconditionally") always bakes the CURRENT owner identity,
-- so a freshly created piece is never NAME-MISMATCH and never DRIFT.
pred freshlyCreated[p: Piece] { p.identityBaked = p.owner and p not in StaleVersion }
assert create_is_always_safe {
  all p: Piece | freshlyCreated[p] implies (isUpToDate[p] and not isNameMismatch[p])
}
check create_is_always_safe for 6

-- Per-project independence ("Two projects have independent copies"): nothing in
-- this model forces one project's pieces to share identity/version state with
-- another's — demonstrate that fully independent combinations of states across
-- two distinct projects are simultaneously satisfiable (not accidentally
-- correlated by an under-constrained model).
run two_projects_fully_independent {
  some p1, p2: Piece | p1.owner != p2.owner
    and isUpToDate[p1]
    and isNameMismatch[p2]
} for 4

-- ============================================================================
-- PART B — proposed delta: SessionStart bounded excerpt must degrade safely
--
-- Traces to the proposed spec delta's new requirement "SessionStart reminder
-- hook includes a bounded status-note excerpt", specifically the
-- "Status note missing or unreadable" scenario, and design.md Decision 2
-- ("a read/parse failure degrades to today's message, never errors").
-- ============================================================================

-- One render-time context per SessionStart hook render: whether the
-- current-status note was readable at all, and (only meaningful if readable)
-- whether its Open-items section exceeds the excerpt's size cap.
sig RenderCtx {}
sig Unreadable in RenderCtx {}
sig OverCap in RenderCtx {}

-- Can't know a note is over the excerpt cap without having read it first.
fact overcap_implies_readable { OverCap in RenderCtx - Unreadable }

-- FIXED (spec-compliant) policy: always emits something. Baseline exactly when
-- unreadable; the bounded (possibly truncated) excerpt otherwise.
pred fixed_usesBaseline[c: RenderCtx] { c in Unreadable }
pred fixed_usesExcerpt[c: RenderCtx]  { c not in Unreadable }

assert fixed_always_emits_a_message {
  all c: RenderCtx | fixed_usesBaseline[c] or fixed_usesExcerpt[c]
}
check fixed_always_emits_a_message for 4

-- BUGGY policy under consideration and rejected in design.md Decision 2: the
-- excerpt-extraction step is NOT wrapped, so an unreadable note aborts the
-- whole render (set -euo pipefail propagates) instead of falling back —
-- producing no message at all for that case. (There is deliberately no
-- buggy_usesBaseline predicate: under this policy, an unreadable context never
-- gets any fallback message — that's the bug.)
pred buggy_usesExcerpt[c: RenderCtx] { c not in Unreadable }
pred buggy_noMessage[c: RenderCtx]   { c in Unreadable }

run buggy_can_produce_no_message {
  some c: RenderCtx | buggy_noMessage[c] and not buggy_usesExcerpt[c]
} for 3

-- ============================================================================
-- PART B (cont.) — drift-warn's two signals are independent
--
-- Traces to the proposed delta's "drift-warn surfaces current-status note
-- bloat, not just version drift" requirement: the note-bloat signal and the
-- pre-existing version-drift signal are checked and reported independently —
-- neither should be coupled to or suppress the other.
-- ============================================================================

sig VersionDrift in Project {}
sig NoteBloat in Project {}
-- Deliberately no fact relating VersionDrift and NoteBloat: independence is
-- exactly "no such fact exists". Demonstrate all four combinations are
-- reachable, which would NOT be possible if an (accidental) coupling fact
-- existed.
run drift_warn_signals_are_independent {
  some p1, p2, p3, p4: Project |
    p1 != p2 and p1 != p3 and p1 != p4 and p2 != p3 and p2 != p4 and p3 != p4
    and p1 in VersionDrift  and p1 in NoteBloat
    and p2 in VersionDrift  and p2 not in NoteBloat
    and p3 not in VersionDrift and p3 in NoteBloat
    and p4 not in VersionDrift and p4 not in NoteBloat
} for 4
