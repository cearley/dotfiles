# Proposal

## Why

`save-session`'s Step 1 locates "the most recent session note" with a fuzzy
`search_notes` call and trusts the ranking/metadata it gets back. On the `chezmoi`
project's own basic-memory data this just failed in practice: several stale
`Session Log — DATE` notes from an earlier rotation scheme sit alongside the actually-
active `Chezmoi Session Notes` note, and nothing in the data or the instruction tells a
search apart from a false match. During today's `/save-session` run, a title-mode search
correctly surfaced the active note, but a follow-up broader search plus an improvised
`updated_at`-timestamp comparison across the stale notes led to appending real content to
the wrong one. The mistake was caught and undone before it became part of the historical
record, but nothing structurally prevents the same failure on a future run, in this
project or any other project this skill is installed in.

## What Changes

- `save-session-skill.md.template`'s Step 1 no longer searches for the active session-log
  note by fuzzy query. It instead resolves it deterministically from the current status
  note's own most recent `Detail:` wikilink — the status note is already the project's
  authoritative source and, by construction, every entry in it points at the real active
  log. Step 2 (read the status note) now runs first; Step 1 reads the resolved note name
  out of what Step 2 already fetched instead of launching its own search.
- `check-drift.sh`'s `SMW_VERSION` bumps so every installed project is flagged for this
  fix on its next `check`/`update`.
- `CHANGELOG.md` and `SKILL.md` document the new Step 1/Step 2 ordering and the "why" (the
  incident above), matching the existing precedent of documenting a real incident that
  motivated a version bump (see v13's `project=` discipline fix).
- Separately, as a one-time basic-memory content cleanup (not a template/code change, and
  not part of the `setup-memory-workflow` capability delta below): the `chezmoi` project's
  stale `Session Log — 2026-06-03/07-15/08-01/08-12/08-19` notes get a visible
  "superseded by `[[Chezmoi Session Notes]]`" marker, consistent with how this project
  already marks superseded content (e.g. `Status Archive — 2026-08-17`). This makes the
  stale notes self-evidently wrong even to an unguided search or a human skimming them,
  as a defense-in-depth measure alongside the structural fix above.

## Non-goals

- Not changing how `save-session` picks which status note is authoritative — there is
  already exactly one per project, and that part already works.
- Not building a general-purpose "note freshness" or "canonical pointer" mechanism for
  basic-memory itself — this is scoped to `save-session`'s own two-note read/write
  pattern, not basic-memory's data model.
- Not rewriting `save-session-maintenance`'s separate rollover/triage logic (the 300-line
  trigger, archive-never-delete pattern) — that already produces a correctly-linked chain
  of notes; the bug here is in how `save-session` *finds* the end of that chain, not in
  how the chain itself is built.
- Not auto-detecting or fixing this class of drift on every other project this skill is
  installed in — the stale-note cleanup (task 2) is `chezmoi`-specific content; other
  projects are covered only by the structural template fix (task 1), which is generic.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `setup-memory-workflow`: the requirement governing how `save-session`'s Step 1 locates
  the active session-log note changes from a fuzzy search to deterministic resolution via
  the status note's own `Detail:` link, with Step 2 now running before Step 1.

## Impact

- `home/dot_claude/skills/setup-memory-workflow/assets/save-session-skill.md.template` —
  Step 1/Step 2 reordered and rewritten.
- `home/dot_claude/skills/setup-memory-workflow/scripts/executable_check-drift.sh` —
  `SMW_VERSION` bump.
- `home/dot_claude/skills/setup-memory-workflow/{SKILL.md,CHANGELOG.md}` — documentation
  of the new ordering and the incident that motivated it.
- `openspec/specs/setup-memory-workflow/spec.md` — delta for the changed requirement.
- Every project with `setup-memory-workflow` already installed picks up the fix via its
  own next `check-drift.sh check`/`update` — no immediate action needed elsewhere.
- Basic-memory content in the `chezmoi` project (`~/.local/share/basic-memory/chezmoi/`):
  five stale `sessions/Session Log — *.md` notes gain a superseded-by marker. This is data,
  not code — no chezmoi repo file changes for this part, and no tag/machine impact.
- No secrets, permissions, or SIP implications — this only touches a Claude Code skill
  template and basic-memory note content.
