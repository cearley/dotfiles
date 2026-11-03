# Design

## Context

See proposal.md - Why. One constraint worth stating explicitly here: this skill is not
`chezmoi`-specific. `save-session-skill.md.template` is rendered, verbatim apart from
`__PROJECT__`/`__SMW_VERSION__` substitution, into every project that has run
`check-drift.sh check`. Whatever Step 1 does has to work generically, without assuming
`chezmoi`'s specific note titles (`Chezmoi Current Status`, `Chezmoi Session Notes`) or
its specific `Detail: [[...]]` link phrasing being universal — those are just this
project's convention for writing the status note, established by `save-session`'s own
Step 2 instructions, not something enforced elsewhere.

## Goals / Non-Goals

**Goals:**
- Make Step 1's note resolution deterministic: given the status note's content, there is
  exactly one correct answer for which note to append to, with no search ranking or
  timestamp heuristic involved.
- Keep the fix inside `save-session`'s own two steps — no new piece, no new basic-memory
  tool call beyond what Step 2 already makes.

**Non-Goals:**
- Guaranteeing correctness on a project whose status note was never written with this
  skill's own Step 2 conventions (e.g., a status note authored by hand with no `Detail:`
  links at all). See the fallback decision below for how that case degrades.
- Changing Step 2 itself, beyond reordering it ahead of Step 1.

## Decisions

**Step 2 runs before Step 1; Step 1 reads the pointer out of what Step 2 already
fetched.** The status note is already the one place `save-session` treats as
authoritative (its own description: "Authoritative source for open items, resolved
items, and environment facts"), and every dated entry's own convention — established by
Step 2's own instructions — is to end with a `Detail: [[<session-log-note>]]` link to
wherever that session's narrative lives. Reordering means Step 1 never re-derives
something Step 2 is about to fetch anyway, and removes the search call entirely for the
common case.
- *Alternative considered*: keep Step 1 first, but have it read the status note itself
  (a second, redundant read) just to extract the pointer. Rejected — two reads of the
  same note in one skill run is exactly the kind of duplicated-trust-the-wrong-copy risk
  this change is trying to remove, and reordering costs nothing (Step 2's read was always
  going to happen this run regardless).
- *Alternative considered*: keep the search, but make it stricter (e.g.
  `mode="title"`, exact title match only). Rejected as a primary fix — it would have
  prevented *today's specific* mistake (the first, title-mode search already found the
  right note), but does nothing to prevent a different ambiguous match in a different
  project, or a future model again preferring a broader search over a narrow one that
  already worked. Fixing the instruction to not need search judgment at all is more
  robust than tightening the judgment call.

**Pointer extraction: the last `Detail: [[...]]` (or equivalent wikilink) found in the
status note's Status Summary section, read literally as a note title/identifier, with no
project-specific parsing.** This generalizes beyond `chezmoi`'s exact phrasing by relying
only on wikilink syntax (`[[...]]`), which basic-memory notes already use pervasively,
rather than a fixed string like "Detail:". Scanning the Status Summary section specifically
(not the whole note) keeps it from picking up an unrelated wikilink from the Open/Resolved/
Environment-facts sections.
- *Alternative considered*: a dedicated, separately-maintained "pointer" field (e.g. a
  frontmatter key naming the active log). Rejected — it's a second place to keep in sync
  with reality, the exact failure mode this change exists to remove; the existing
  `Detail:` links are already kept correct as a side effect of every save, because a
  save that pointed at the wrong note would make its own next read look wrong
  immediately (self-correcting), where a separate frontmatter field would only be
  noticed stale much later.

**Fallback when no wikilink is found (new project, first-ever save, or a hand-authored
status note with no links yet): fall back to the existing `search_notes` behavior,
unchanged.** This keeps the fix additive rather than breaking cold-start — a project's
very first `/save-session` run has no prior status note content to point anywhere.
- *Alternative considered*: treat a missing pointer as an error and stop. Rejected -
  that would turn a one-time, expected cold-start case into a hard failure requiring
  user intervention on every fresh install, which is worse than the rare-ambiguity bug
  this change fixes.

**Version bump, not a migration script.** `SMW_VERSION` increments; existing installs are
flagged `DRIFT` on their next `check` and repaired via `update`/`apply`, exactly like
every other content-only template change in this skill's history (see CHANGELOG v13).
No `migrate_*` function is needed - nothing is left behind on disk that needs cleanup,
only rendered text that needs replacing.

## Risks / Trade-offs

- [Risk] A status note whose most recent dated entry's `Detail:` link uses different
  phrasing or no brackets at all (inconsistent manual edit) → Step 1 silently falls back
  to search, same as the cold-start case; no worse than today's behavior, and the
  underlying inconsistency is a status-note hygiene issue `save-session`'s Step 2 already
  owns (keep it accurate and tidy).
- [Risk] Multiple wikilinks in the most recent Status Summary entry (a session that
  references several other notes) → take the *last* one in that entry, matching this
  project's own established convention of placing the `Detail:` pointer at the end of
  each dated paragraph. Documented in the rendered Step 1 text so it's not a silent
  assumption.
- [Trade-off] This still depends on Step 2's own instruction ("this is the authoritative
  note, keep its Detail links accurate") being followed correctly every time, same as
  before - the fix removes the *search*-ranking risk, not all possible status-note
  inaccuracy. Accepted: that dependency already existed implicitly (Step 1's old search
  was trying to approximate what the status note already knew), this just makes it
  explicit and removes the redundant, failure-prone approximation step.

## Migration Plan

1. Edit the canonical template + bump `SMW_VERSION`.
2. Existing installs (including `chezmoi` itself) show `DRIFT` on next `check-drift.sh
   check`; `update` or `apply save-session-skill` repairs them - no action beyond the
   normal self-heal flow.
3. Separately (not gated on the above, no ordering dependency): mark `chezmoi`'s five
   stale `Session Log — *.md` notes as superseded. One-time, direct basic-memory MCP
   edits, not a chezmoi-repo change.
4. Rollback: revert the template edit and `SMW_VERSION` bump; installed projects pick up
   the reversion the same way they picked up the fix, via `update`.

## Open Questions

(none - the ambiguity that would have gone here, the fallback behavior for a missing
pointer, is resolved above rather than deferred.)
