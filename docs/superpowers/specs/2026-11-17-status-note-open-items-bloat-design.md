# Bound Open-item growth in the setup-memory-workflow status note

## Intent and why

A `/oh-my-claudecode:review` of the setup-memory-workflow skill (its functions, hooks,
guards, and guidance) found that the skill accomplishes accurate **detection** of an
oversized current-status note and session log, plus one real but partial **throttle**
(v23's status-note write-gate, which caps new Status Summary narrative once the note is
already oversized). It does not accomplish actual **mitigation**: the only remediation
path is the manually-invoked `/save-session-maintenance`, and the Open section of the
status note is explicitly exempt from any shrink mechanism today ("preserve Open items
and task-tracker authority" in both `save-session-skill.md.template` and
`save-session-maintenance-skill.md.template`).

Live evidence from this repo's own `chezmoi` basic-memory project, read during this
investigation: the status note was defragged via `/save-session-maintenance` on
2026-11-17 — the same day — and the oversized signal is still firing. The Status Summary
section is behaving (recent entries are short pointer lines, exactly what the v23 gate
produces). The actual weight is the Open section: roughly 30 items, most of them
multi-sentence prose paragraphs, which current policy never shrinks. This design targets
that specific, confirmed bottleneck.

## Goals

- Bound the live status note's size contribution from the Open section, regardless of
  how many open items exist in total.
- Never let a still-unresolved item become invisible by default. The note must always
  surface at least *that backlog exists and how big it is*, even when per-item detail is
  compressed out of the live view.
- Measure staleness in **sessions untouched**, not calendar time — the user may leave a
  project for weeks and return, and that gap must not look like neglect.
- Avoid new tracking infrastructure beyond what the workflow already produces each
  session (dated Status Summary entries / session-log entries).

## Non-goals

- Replacing or integrating with `bd`/beads or OpenSpec as a backlog store. Beads is not
  installed in this repo, and OpenSpec is for formal proposed changes, not ad hoc
  backlog items — this stays entirely inside the memory workflow.
- Changing how the existing v23 Status Summary growth gate works. It's already correct
  and out of scope; this design is additive to it.
- Any calendar/date-based decay or escalation of Open items.

## Anti-goals

- Must not silently reduce visibility of a still-open, unresolved problem. This is the
  specific failure mode that ruled out a plain age-based (calendar) demotion approach
  during design: archiving genuinely *resolved* work (today's Resolved/Status-Archive
  pattern) is correct because that work is done; applying the same move to *not-done*
  work just because it's old is not the same thing and was rejected.
- Must not require a new external tracker/dependency.
- Must not require the model to hand-count session age from calendar dates in prose.

## Constraints

- basic-memory has no native TTL/expiry/retention lifecycle (confirmed via `bm_man`:
  no page mentions archive/retention/expire/TTL beyond `bm-move`/`bm-delete`, which are
  manual operations). Any "N sessions untouched" logic must be implemented by this
  workflow's own scripts/skills.
- `bm_schema` (Picoschema) validates/infers/diffs **frontmatter field shape** on a note
  type ("does this note have the required fields"), not line/character counts or section
  size. It cannot enforce a size cap. Its role here is restricted to validating the new
  `open-items/` note type's fields and making them queryable via `bm_find` filters — it
  is not, by itself, a growth-control mechanism.
- The `SessionStart` reminder hook (`session-reminder.sh`, `lib-status-note.sh`,
  `lib-session-log.sh`) must remain read-only, degrade to no-op on any missing
  file/section, and exit 0 unconditionally. Any new Open-section signal follows this
  same contract — it only ever prints a suggestion.
- `save-session-maintenance` remains `disable-model-invocation: true`,
  explicit-invocation-only. New rollup/triage logic runs inside that skill, never
  automatically from a bloat reminder.
- Must not break the existing `check-drift.sh status-bloat` subcommand or the v23
  Status Summary gate in `save-session-skill.md.template` Step 1.

## Current state (for the builder's grounding)

- `scripts/lib-status-note.sh`: `check_status_note_bloat()` (three-signal detector: ≥8,000
  chars, ≥200 lines, or any single line ≥800 chars), `extract_open_excerpt()` (15-line
  excerpt of the Open section with a "(N more open items...)" truncation notice),
  `resolve_status_note_path()`.
- `scripts/lib-session-log.sh`: `check_session_log_bloat()` (300-line rollover threshold).
- `scripts/executable_check-drift.sh`: has a `status-bloat` subcommand wrapping
  `check_status_note_bloat()`, called from `save-session-skill.md.template` Step 1
  before every new Status Summary entry is drafted.
- `assets/save-session-skill.md.template` Step 1/2: writes gated Status Summary entries
  (short pointer line once oversized, per the v23 spec requirement) and maintains the
  Open list "as baseline," explicitly never regenerating, resizing, or restructuring it.
- `assets/save-session-maintenance-skill.md.template` Step 2: triages the status note by
  moving stable reference facts to `reference/`/`known-issues/`, but explicitly
  preserves "Open items and task-tracker authority" — i.e., it never shrinks Open today.
- Live proof (chezmoi project, read 2026-11-17): status note's Status Summary section is
  healthy (short pointer entries); its Open section has ~30 items, several of them
  multi-line prose paragraphs, and is the dominant contributor to the still-firing
  oversized signal immediately after same-day maintenance.

## Approaches considered

1. **Schema-only drift detection, no Open restructuring.** Add `bm_schema diff`/`validate`
   as a new signal catching Status Summary format regressions. Cheapest to build, but
   does nothing for the Open section, which the live evidence shows is the actual
   bottleneck. Rejected as insufficient on its own.
2. **Calendar-age-based demotion of stale Open items.** Move items untouched for N days
   into an archive note during maintenance. Rejected: this silently removes visibility
   of unresolved problems from the default view. It conflates "old" with "done," and a
   deliberate weeks-long gap in working on a project would look identical to neglect.
3. **Pointer-ize Open items + session-count-based rollup (chosen).** Each Open item
   becomes one short line pointing at its own note; once the live Open section passes a
   line cap, items untouched for N *sessions* (not days) collapse into a single
   still-visible rollup line pointing at an index note. Chosen because it bounds size
   without ever hiding that the backlog exists, and ties staleness to actual work
   sessions rather than calendar gaps the user may deliberately create.

## Decided design

### Open-item notes

- Provisioning call: `open-items/` and its `type: schema` note are created **lazily**,
  by `save-session-skill.md.template` the first time it needs to write a new Open item,
  the same way the canonical status note and the first session log are already created
  on confirmed-missing rather than pre-provisioned. This is not a new piece type added
  to `lib-pieces.sh`'s templated-file/hook-command engine — that engine manages files
  and hook commands outside the notes tree, not basic-memory notes, and nothing else it
  manages today works this way either.
- New per-item notes live under `open-items/` (a sibling of `reference/`,
  `known-issues/`, `sessions/`, `status/`), one note per still-open item.
- Frontmatter: `type: open-item`, plus `status` (`open`/`stale`/`resolved`),
  `found_session` (the dated Status Summary entry that created it), `last_touched_session`
  (updated whenever a save or maintenance run references, confirms, or edits the item),
  and optional `severity` (mirroring today's "(low priority)" convention).
- Body: the existing `[problem]`/`[fact]` observation line and whatever prose detail it
  had — content is relocated, not rewritten or shortened.
- A matching `type: schema` note (`entity: open-item`) declares these fields so
  `bm_schema validate`/`diff` can catch drift — e.g., a maintenance run that forgets to
  set `last_touched_session`.

### Status note's Open section

- Each live item becomes one line: `- [problem] <short title> — [[Open: <slug>]]`,
  preserving the `[category]` marker so it stays a native Observation.
- Once the section's live line count passes a cap (default: reuse the existing
  `OPEN_EXCERPT_MAX_LINES = 15` constant unless the builder finds a reason the two
  should diverge), items whose `last_touched_session` is ≥ N sessions old (default
  N = 5, tunable) collapse out of the per-item lines into one line:
  `>N sessions untouched: <count> items — [[Stale Open Items Index — <project>]]`.
- The index note is itself just grouped pointer lines — nothing novel beyond today's
  pointer convention.

### Session-count clock (no new counter infrastructure, script-computed)

- "Sessions since an item was last touched" is computed by counting dated Status
  Summary entries (or session-log session boundaries) added after that item's
  `last_touched_session` marker — reusing data the workflow already writes every save,
  rather than introducing a monotonic counter file.
- `last_touched_session` is recorded as the dated entry's date string (the existing key
  convention for Status Summary entries), not an opaque session ID, so it stays
  human-readable directly in the note's frontmatter.
- **This computation is a deterministic script, not a model judgment call.** Every
  existing bloat/drift signal in this skill (`check_status_note_bloat()`,
  `check_session_log_bloat()`) is a plain bash function reading note files straight off
  disk under `$HOME/.local/share/basic-memory/$PROJECT/...`, specifically so nothing
  depends on the model getting the accounting right — the whole point of this design is
  to stop relying on that. A new `lib-open-items.sh`, following the same pattern, reads
  `open-items/*.md` frontmatter and the status note's dated Status Summary headers
  directly off disk and computes the stale set in bash/awk, exposed as a new
  `check-drift.sh` subcommand (e.g. `open-staleness`). Maintenance calls this subcommand
  and acts on its authoritative output; it does not reason out staleness itself via
  `bm_find`. `bm_schema` is still used, but only for its actual job: validating the
  `open-item` note type's frontmatter shape, not for computing session counts.

### Where the logic runs

- **Creation:** `save-session-skill.md.template` Step 2, where it currently adds a new
  Open item inline, instead creates (or updates) an `open-items/` note and adds the
  one-line pointer to the status note.
- **Touch tracking:** any save-session run that references an existing Open item
  updates that item-note's `last_touched_session`.
- **Rollup/triage:** `save-session-maintenance-skill.md.template` Step 2 runs
  `check-drift.sh open-staleness` (new, backed by `lib-open-items.sh`, see above) to get
  the authoritative stale-item list, then performs the collapse into the Stale Open
  Items Index and runs `bm_schema validate` against the `open-item` type to catch shape
  drift. This is additive to its existing "preserve Open items" rule — it now preserves
  them via the index rather than via the raw prose list.
- **Detection signal:** the new `lib-open-items.sh` (not `lib-status-note.sh`, which
  stays scoped to the note-as-a-whole signals — mirrors `lib-session-log.sh` getting its
  own file for log-specific concerns) gains a read-only, no-write
  `check_open_section_overflow()` that warns when the live Open section has grown past
  its line cap, following the same pattern as today's three bloat signals — it only ever
  suggests `/save-session-maintenance`.

### Migration of existing prose Open items (forward-only, no bulk rewrite)

- Nothing existing is bulk-converted on upgrade. New Open items created after this ships
  use the `open-items/` + pointer-line shape; items that predate this change stay as raw
  prose bullets, untouched, until individually resolved.
- `save-session-maintenance-skill.md.template` gains a narrowly-scoped **on-request**
  conversion path: when the user names a specific existing Open item (or a small named
  set), maintenance converts just that item — extracts it to its own `open-items/` note
  with inferred `found_session`/`severity`, replaces its prose bullet with a pointer
  line, and verifies the result — the same way every other targeted operation in this
  skill works (explicit invocation, no sweep of unrelated content). This lets the
  existing ~30-item chezmoi backlog be worked down incrementally, at the user's pace,
  without the risk of an automated one-shot reinterpretation of 30 items' worth of free
  text. A bulk, automatic migration was considered and rejected for the same reason this
  skill already refuses to "regenerate Open from this session alone, resize or
  restructure the whole note" elsewhere.

## What's left to the builder

- Exact default values for the Open-line cap and the N-session staleness threshold —
  stated above as defaults; confirm or tune.
- Whether `last_touched_session` is keyed by the Status Summary's dated-entry string or
  the session-log note's identifier — default is the dated string, unless there's a
  concrete reason the session-log identifier is more robust.
- Exact wording/format of the rollup line and the Stale Open Items Index note's internal
  structure (grouped by category vs. a flat list).
- Whether resolving a *stale* (indexed) item needs special handling beyond today's
  Resolved flow, or is identical (move its `open-items/` note, update the index).
- Exact invocation phrasing/UX for the on-request single-item conversion path (e.g. does
  `/save-session-maintenance` accept an item reference as an argument, or does the user
  describe which item in plain language and the skill resolves it).
- New bashunit coverage mirroring the existing
  `tests/setup_memory_workflow_status_bloat_test.sh` pattern for the new
  `open-staleness` subcommand, the overflow signal, and the `open-item` schema.
- `SMW_VERSION` bump and `CHANGELOG.md` entry per this skill's existing versioning
  convention once implemented.
