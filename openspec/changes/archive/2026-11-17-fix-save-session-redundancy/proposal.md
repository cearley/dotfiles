# Proposal

## Why

An audit of the `setup-memory-workflow`/`save-session` workflow (research fork, 2026-11-17,
covering session transcripts since 2026-11-13) found concrete, evidenced friction in the single
most frequently run skill in this repo: two live bugs cause wasted round-trips on every save
that hits them (malformed `bm_edit`/`bm_read` calls get retried unchanged instead of corrected);
the save path runs two overlapping version/identity checks back to back (`check-drift.sh check`
then `authorize`) plus a full transcript rescan just to advance one checkpoint marker; the
`SessionStart` hook chain re-sources the same shell libraries twice per session start; and the
current-status note has re-bloated to roughly 54,000 characters / 315 lines — about 6.8x over
its own 8,000-character oversized threshold — because the "run `/save-session-maintenance`" nag
has fired and been ignored every session for more than four days straight, with zero cost to
ignoring it. Now is a good time because each of these is independently evidenced (session IDs,
exact error text, and a direct read of the live note), not speculative.

## What Changes

- Fix `save-session-skill.md.template`'s BM tool-call guidance: add a concrete, correctly-shaped
  `bm_edit(command="find_replace")` example (`find_text` + `content` — the replacement argument
  is named `content`, not `replace_text`, which the model guessed wrong twice in one live
  session) and remove/correct the nonexistent `bm_read(page=...)` pattern (`bm_read` paginates
  via `start_line`/`end_line`/`max_tokens`; it has no `page` argument at all).
- Drop the standalone `check-drift.sh check` call from `/save-session`'s Preflight. `authorize`
  (run immediately after it today) already re-derives and checks the same version/project-identity
  markers for the save path, making `check`'s broader report redundant there. `check` remains the
  entry point for `/setup-memory-workflow` health checks and for `save-session-maintenance`'s own
  Step 0, where its broader report is actually used.
- Collapse the `SessionStart` hook chain (`session-reminder.sh` followed by
  `check-drift.sh drift-warn`) into a single invocation that sources the shared libraries once
  instead of twice, with no change to what either piece reports.
- Cap each new `## Status Summary` entry in the current-status note to a fixed hard line limit,
  with full narrative detail moved exclusively to the session log — which almost every existing
  entry already links to via `Detail: [[...]]`, so this removes duplication rather than losing
  information. Add a hard gate to `/save-session`'s Step 1: once the note's existing 3-signal
  oversized check (≥8,000 chars / ≥200 lines / any single line ≥800 chars) fires, Step 1 writes
  only a short pointer entry and stops adding further narrative growth until
  `/save-session-maintenance` actually runs.

## Capabilities

### Modified Capabilities
- `setup-memory-workflow`: corrects `bm_edit`/`bm_read` call guidance; removes the duplicate
  `check-drift.sh check` call from the save path's Preflight; collapses the `SessionStart` hook
  chain to one library-sourcing pass; caps new Status Summary entries at a fixed hard line limit
  and adds a hard write-gate once the current-status note is already oversized.

## Impact

- `home/dot_claude/skills/setup-memory-workflow/assets/save-session-skill.md.template` —
  tool-call examples, Preflight step, Step 1 entry format and oversized-gate behavior.
- `home/dot_claude/skills/setup-memory-workflow/scripts/executable_session-reminder.sh` and
  `executable_check-drift.sh` — hook-chain collapse.
- `home/dot_claude/skills/setup-memory-workflow/scripts/lib-status-note.sh` (and/or a new
  lib function) — the hard-cap/gate check shared between the live hook and the template's
  instructions.
- `SMW_VERSION` bump (next available number) and a new `CHANGELOG.md` entry.
- Every project with `setup-memory-workflow` already installed picks this up on its own next
  `check-drift.sh update` (or the `bulk-update-memory-workflow` sweep) — no immediate action
  needed elsewhere.
- No new dependencies, no new MCP tools, no change to the consent/write-guard model.

## Non-goals

- Not automating `/save-session-maintenance` itself — no spawning a session, no autonomous
  triage/restructuring. Explicitly ruled out by the `autonomous-save-session` abandonment
  (2026-08-27 fork-bomb) and the v12 lesson against blending mechanical append work with
  judgment-heavy restructuring of the same note.
- Not changing the consent/write-guard model (`lib-consent.sh`,
  `executable_basic-memory-write-guard.sh`) — the audit found this has no upstream basic-memory
  analog and isn't redundant with it; left untouched.
- Not swapping the session-log-discovery fallback from `bm_search` to `bm_project(recent)` — a
  real but low-impact, cold-start-only optimization the audit noted; deferred to a separate,
  smaller change if wanted later.
- Not retroactively re-triaging the already-oversized live note as part of implementing this
  change. That is a separate, explicit `/save-session-maintenance` run the user does afterward,
  not a side effect of shipping this proposal.

## Security implications

None directly — no secrets, permissions, or SIP-restricted paths are involved. The hard gate
changes *when* the model may add new narrative content to the status note; it does not change
or weaken the existing checksum-guarded-edit or recording-consent requirements, which remain
exactly as specced.
