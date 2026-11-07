# Design

## Context

See `proposal.md` — Why, for motivation. Relevant current-state facts this design depends on,
confirmed by reading `home/dot_claude/skills/setup-memory-workflow/scripts/executable_check-drift.sh`
directly (not assumed from the architecture doc, since this design needed line-level accuracy):

- The canonical `SessionStart` reminder-hook command (`canonical_hook_cmd()`) already chains two
  things: `echo '<rendered hook-message.txt.template>'`, then a silent, best-effort call back
  into the same globally-installed `check-drift.sh drift-warn` (stderr redirected, `|| true`).
  So `drift-warn` already runs on *every* session start in every opted-in project — no new hook
  entry is needed for item 2 below.
- `cmd_drift_warn()` currently checks exactly one thing: whether the installed
  `.claude/skills/save-session/SKILL.md`'s embedded version marker is older than this script's
  own `SMW_VERSION`. If so, it prints one line naming the skill-level fix.
- `resolve_project()` runs unconditionally at the top of every `check-drift.sh` invocation
  (`PROJECT=$(resolve_project)`), including a `drift-warn` invocation — this is already the
  established pattern, not a new exception. The "no runtime identity-resolution script ships in
  any *installed* piece" constraint (see `openspec/specs/setup-memory-workflow/spec.md`,
  "Project identity is resolved once, at apply-time") is about the per-project *rendered*
  templates (`save-session` skill, hook message, etc.) never re-deriving identity themselves —
  it has never applied to `check-drift.sh` itself, which is the one piece explicitly allowed to
  resolve identity on every invocation since its own content isn't rendered per project.
- `save-session-maintenance`'s existing thresholds for status-note triage (total size ≥~8,000
  chars or ≥200 lines; any single entry ≥~800 chars) are the right numbers to reuse for the new
  bloat signal — inventing a second set of thresholds for the same note would be a maintenance
  hazard with no benefit.
- The status note lives at a fixed, derivable path:
  `~/.local/share/basic-memory/$PROJECT/status/$PROJECT-current-status.md` (consistent with the
  identifier `save-session` reads via MCP: `"__PROJECT__/status/__PROJECT__-current-status"`).
  `drift-warn` needs read access to that file's content/size via plain shell (`wc`), not MCP —
  it runs as a hook, with no MCP tool access.

## Goals / Non-Goals

**Goals:**
- Close the two specific gaps identified in the comparative analysis (bounded status visibility
  at `SessionStart`; a nudge toward manual maintenance that nothing currently triggers for note
  bloat specifically) with the smallest change that fits the existing architecture.
- Reuse existing mechanisms (`drift-warn`'s existing invocation point, `resolve_project()`,
  `save-session-maintenance`'s existing thresholds) rather than introducing parallel ones.

**Non-Goals:**
- Not adding a time-based ("days since last check") signal — out of scope per proposal.md's
  Non-goals; version-drift already covers "something hasn't been checked/updated recently" for
  templates, and adding a second, differently-shaped signal for the same general concern (staleness) is unnecessary.
- Not making `drift-warn` call basic-memory via MCP — it stays a plain hook script with shell
  access only, matching every other hook in this skill.
- Not changing where the status note lives or how `save-session`/`save-session-maintenance`
  address it.

## Decisions

### 1. Bounded excerpt: render it into the hook message template, computed at `check` time, not hook runtime

The excerpt is produced once, when `check-drift.sh check`/`update`/`apply hook-config` renders
`hook-message.txt.template`, by reading the current-status note file directly (same shell
primitives `save-session-maintenance` already uses: `wc -c`, `wc -l`, a line-count-bounded
`head`/`tail`/`grep` extraction of lines between the note's `## Open` and next `##` heading) and
substituting a new `__OPEN_EXCERPT__` placeholder in the template, the same way `__PROJECT__` and
`__SMW_VERSION__` are substituted today via `render()`.

**Why render-time, not hook-runtime:** every other per-project piece in this skill is rendered
once and re-rendered only on explicit `update`/`apply` — baking the excerpt in at the same point
keeps this piece consistent with that model and avoids adding a second class of "hook computes
its own content live" behavior alongside the templated-rendering model that already exists for
five of the six installed pieces.

**Alternative considered — compute the excerpt live in the hook command at session-start time**
(e.g. `canonical_hook_cmd()` appends a `head`/`grep` pipeline against the note file instead of a
baked-in string): rejected because it means the excerpt can silently go stale between
`check-drift.sh` runs and the actual current-status note content (the note can be edited via MCP
between check-drift runs) — acceptable, since the excerpt is explicitly a "better than nothing
before the real search runs" aid, not a replacement for `search_notes`/`recent_activity`, but
baking it at render time is simpler to reason about for drift purposes: a stale excerpt is then
just ordinary version drift, caught and reportable by the exact same `DRIFT` mechanism that
already exists for this piece, rather than a new, unversioned failure mode. Trade-off accepted
explicitly below.

**Consequence accepted:** the injected excerpt can be stale relative to the live note (it
reflects the note's content as of the last `check-drift.sh check`/`update`, not the current
moment). This is acceptable because `save-session`'s Step 1 and the `search_notes`/
`recent_activity` instruction remain the authoritative path — the excerpt is a visibility aid for
the gap before those run (or if the model skips the instruction), not a second source of truth.

### 2. Fallback behavior: a read/parse failure degrades to today's message, never errors

`render()` already runs under `set -euo pipefail`. The excerpt-extraction step is wrapped so any
failure (note file missing, unreadable, malformed) is caught and treated as "no excerpt,"
falling back to exactly today's `hook-message.txt.template` output (i.e. `__OPEN_EXCERPT__`
substitutes to an empty string, and the template is written so an empty excerpt renders no extra
lines — not an empty header with nothing under it).

**Why:** the proposal's and spec's explicit constraint that this is additive, never a regression
— a parse bug in the excerpt logic must never take down the one thing (`search_notes`/
`recent_activity` instruction) that currently reliably works.

### 3. Excerpt size cap: a fixed line count, truncated with a visible marker

Cap the excerpt at 15 lines (chosen to comfortably fit a handful of Open items without
approaching the hook message becoming a second status note). If the note's Open section exceeds
the cap, truncate and append a line: `... (N more open items — see the status note)`.

**Alternative considered** — a character-count cap matching `save-session-maintenance`'s
~800-char single-entry threshold: rejected for this specific use because Open items are
naturally one-per-line, so a line cap is the simpler, more predictable mechanism for a reader and
for truncation logic (no mid-entry cut risk).

### 4. Note-bloat signal: extend `cmd_drift_warn`, not a new hook or script

Add the size checks directly inside the existing `cmd_drift_warn()` function, using the
already-resolved `$PROJECT`, reading
`~/.local/share/basic-memory/$PROJECT/status/$PROJECT-current-status.md` with the same `wc -c`
/ `wc -l` / per-line-length approach `save-session-maintenance`'s own instructions describe.
Print an additional line (independent of, and in addition to, the existing version-drift line)
when any threshold is crossed:
`[setup-memory-workflow] current-status note looks oversized — run /save-session-maintenance to triage it.`

**Why no new hook piece:** `drift-warn` already runs on every session start via the existing
reminder hook's command chain (`canonical_hook_cmd()`); adding a second `SessionStart` entry
would duplicate an invocation point that already exists, add a second script to deploy and keep
in sync, and give `check-drift.sh` a new "missing piece" case for something that isn't actually a
separate installable piece — it's one function gaining a second check.

**Alternative considered** — a dedicated `staleness-nudge-hook` piece with its own global script
(the shape originally proposed before re-reading `check-drift.sh`): rejected once `drift-warn`'s
existing invocation was found; it would have been pure duplication.

**Risk accepted:** `cmd_drift_warn` now reads a file outside the project directory
(`~/.local/share/basic-memory/`) from a hook context for the first time (`drift-warn` previously
only read a project-relative file). This is read-only and the same base path the write-guard hook
already treats as a known, trusted location — no new trust boundary is crossed, only a new read.

## Risks / Trade-offs

- **[Risk] Excerpt-extraction logic (Open-section parsing) is itself a small parser that could
  break on an unusual status note format (e.g. no `## Open` heading, or a heading typo).** →
  Mitigation: Decision 2's fallback — any extraction failure or empty match degrades to no
  excerpt, never an error, and is covered by its own spec scenario.
- **[Risk] The baked-in excerpt can be stale between `check-drift.sh` runs (Decision 1).** →
  Mitigation: accepted explicitly; the excerpt is a secondary aid, and staleness here is no worse
  than any other `DRIFT`-tracked piece — the fix is the same `update` path users already know.
- **[Risk] `cmd_drift_warn` reading outside the project directory is a new code path in a
  frequently-invoked hook function (every session start).** → Mitigation: read-only, local
  filesystem, wrapped so a missing/unreadable note degrades to "skip this signal" rather than
  erroring the whole `drift-warn` call (consistent with `canonical_hook_cmd()`'s own `|| true`
  wrapping of the entire `drift-warn` invocation as a second layer of protection).
- **[Trade-off] Reusing `save-session-maintenance`'s exact thresholds means a future change to
  one must remember the other.** → Accepted: the alternative (independent thresholds) is strictly
  worse — two different "is this note too big" answers for the same note is the actual
  maintenance hazard, not the duplication of a numeric constant across two files.

## Migration Plan

- Bump `SMW_VERSION` in `executable_check-drift.sh` once, covering both changes.
- Existing installs: the `cmd_drift_warn` extension takes effect immediately on next session
  start (global script, no per-project render needed). The hook-message excerpt is a per-project
  rendered piece — existing installs report `DRIFT` on `check-drift.sh check` and need
  `check-drift.sh update` (safe, unconditional, matching every prior version bump) to pick it up.
- No rollback mechanism beyond the existing one: `git revert` the chezmoi-side commit, bump
  `SMW_VERSION` again, and installed projects pick up the reverted template on their next
  `update` — identical to how every previous `SMW_VERSION` bump has been rolled back.

## Open Questions

None — both decisions above were resolved during design rather than deferred, per the
proposal's stated scope.
