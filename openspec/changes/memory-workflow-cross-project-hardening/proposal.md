# Proposal

## Why

A 2026-11-07 live hcom comparison of `setup-memory-workflow`'s `SessionStart`
mechanics against `oh-my-claudecode` (`kali`) and `oh-my-pi`'s own agent-memory
backend (`muse`) — run immediately after the `memory-workflow-sessionstart-improvements`
change landed — surfaced four cheap, concrete gaps that don't require revisiting
that change's binding architectural decisions (excerpt baked in at check-time,
not live-computed; bloat handled by a manual nudge, not auto-pruning). The
comparison also incidentally confirmed, via a third peer (`raza`, running this
same skill in the `oh-my-pi` repo), that an installed project can sit on a
stale `SMW_VERSION` indefinitely with no proactive signal beyond the existing
version-drift line — which is working as designed, but sharpened the case for
tightening the signals this skill already emits rather than adding new ones.

A follow-on design review (same day) separately surfaced a conceptual scope
problem, unrelated to the comparison: the prior change put live basic-memory
note-content reading (`extract_open_excerpt()`, the current-status-note bloat
check) directly inside `check-drift.sh`, whose own stated job is comparing
installed pieces against canonical templates — a different concern from
reading a user's evolving note content. This change's own session-log-bloat
addition would otherwise double down on that same conflation, so this
proposal corrects it retroactively rather than adding a third instance.

A third, independent issue was raised by the user during this same design
pass: `crash-recovery-hook.sh` currently fires its catch-up reminder purely
on session-ID identity — did the most recent prior session's transcript ID
match the one `save-session` last recorded, yes or no. That binary check has
two real failure modes, confirmed by walking through the actual script: a
trivially small session started by `/clear` and ending unsaved always
triggers the reminder (a false positive — the common, reported complaint),
while a session that saves early and then keeps going never triggers it
again for that session, no matter how much unsaved work piles up afterward
(a false negative, and the more serious of the two). Both are fixed by the
same change: track *how much* has happened since the last save, not just
*whether* a save ever happened.

## What Changes

- Extract all live basic-memory note-content reading out of `check-drift.sh`
  into a new sourced file, `scripts/memory.sh`, mirroring the existing
  `migrations.sh` precedent (sourced, no shebang, not executable, relies on
  globals already set by the sourcing script). This moves
  `resolve_status_note_path()`, `extract_open_excerpt()`, and the
  current-status-note-bloat check — all added by the prior change —
  retroactively, with no behavior change; `check-drift.sh` keeps only
  template-rendering and piece-drift logic, calling into `memory.sh` the same
  way it already calls into `migrations.sh`.
- Extend `cmd_drift_warn()`'s existing note-bloat signal to also check the
  active session-log note against `save-session-maintenance`'s existing
  ~300-line rollover threshold — today only the current-status note is
  checked; the session log (which that same maintenance skill already knows
  how to roll over) gets no proactive nudge at all.
- Give the baked Open-items excerpt's own staleness a distinct report
  category in `check-drift.sh check`, instead of folding it into the same
  `DRIFT` bucket used for real template/version changes. Today, any edit to
  the status note's `## Open` section (which happens routinely via
  `/save-session`) makes the installed hook piece report generic `DRIFT`,
  diluting that signal's original meaning ("this piece needs a real
  update") with routine content churn it was never meant to flag.
- Stamp the baked excerpt with its capture date (e.g. "as of 2026-11-07")
  when rendering it into the hook message, so anyone reading the
  `SessionStart` reminder has an explicit signal for how stale the excerpt
  itself might be, without moving to live-at-session-start computation
  (explicitly rejected in the prior change's design.md).
- Reword the `SessionStart` reminder's phrasing in three ways, bundled
  together as one wording-only change (no behavior change to what gets
  injected or when): (a) from an imperative instruction ("Your FIRST
  action this session...") to an explicit "background context — current
  user/tool input takes precedence on conflict" framing, matching the
  convention `oh-my-pi`'s own injected memory blocks already use; (b)
  from unconditionally commanding `search_notes`/`recent_activity` as a
  mandatory first action to conditioning that real MCP call on the baked
  excerpt (plus its capture date) actually being insufficient — closing a
  redundancy identified mid-design, where the cheap excerpt and the
  expensive MCP round-trip were both being paid for every session even
  though they mostly cover the same ground; and (c) naming the kind of
  user phrasing (direct resume/status-request language like "what's the
  current status," "where did we leave off," "let's resume/continue")
  that should override (b)'s default and always trigger the real call —
  model-judgment only, since the model already sees the user's literal
  message in the same turn, so no new hook is needed.
- Replace `crash-recovery-hook.sh`'s pure session-ID-identity check with a
  turns-since-last-save magnitude threshold: `.claude/.last-saved-session`
  changes from a bare session ID to `SESSION_ID:TURN_COUNT_AT_SAVE`, and the
  hook fires only when the most recent prior transcript's unsaved turns
  (computed against that checkpoint, or against the whole transcript if it
  was never saved at all) exceed a new, easily-changed constant,
  `UNSAVED_TURN_THRESHOLD=5`. This covers both a `/clear`-started session
  that ends quickly and unsaved (stays quiet, below the threshold) and a
  session that saves early then keeps going for real work before crashing
  (still fires, since the magnitude crosses the threshold either way) — one
  rule for both cases, with no special-casing of *why* a session ended.
- Bump `SMW_VERSION` in `scripts/executable_check-drift.sh` so existing
  installs (including the `oh-my-pi` repo this comparison surfaced as
  already behind) pick up all pieces on their next
  `check-drift.sh check`/`update`.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `setup-memory-workflow`: extends `cmd_drift_warn()` with a session-log
  bloat signal alongside the existing status-note one; adds a distinct
  `STALE-EXCERPT` report category separate from `DRIFT` for the baked
  Open-items excerpt specifically; adds a capture-date stamp to the
  rendered excerpt; rewords the reminder hook's framing to be
  background-context-styled, to make the real memory-retrieval call
  conditional on the excerpt's sufficiency rather than unconditional, and
  to name resume/status-request phrasing that overrides that default.
  Internally (no externally observable change), relocates note-content
  reading out of `check-drift.sh` into a new sourced `memory.sh`. Also
  replaces the crash-recovery hook's session-identity check with a
  turns-since-last-save magnitude threshold.

## Impact

- `home/dot_claude/skills/setup-memory-workflow/scripts/memory.sh` — new
  file, sourced by `check-drift.sh`, mirroring the `migrations.sh`
  precedent; holds `resolve_status_note_path()`, `extract_open_excerpt()`,
  `resolve_active_session_log_path()` (new), and the current-status-note
  and session-log bloat-check functions.
- `home/dot_claude/skills/setup-memory-workflow/scripts/executable_check-drift.sh`
  — the above functions move out (retroactively, for the first two) or are
  added directly into `memory.sh` (for the new ones) rather than landing
  here; `cmd_drift_warn()` becomes a thin orchestrator calling into
  `memory.sh` for bloat signals while keeping its own version-drift check;
  `check`'s reporting gains a `STALE-EXCERPT` category distinct from `DRIFT`
  for the hook piece specifically, with its own (still manual,
  `update`-driven) repair path; `render()` gains a capture-date stamp (via
  `memory.sh`'s `extract_open_excerpt()`); `SMW_VERSION` bump.
- `home/dot_claude/skills/setup-memory-workflow/assets/hook-message.txt.template`
  — reworded framing text; new placeholder for the capture-date stamp.
- `home/dot_claude/skills/setup-memory-workflow/scripts/executable_crash-recovery-hook.sh`
  — replaces the session-ID-only comparison with the turns-since-last-save
  magnitude check; adds the `UNSAVED_TURN_THRESHOLD=5` constant. Needs no
  `SMW_VERSION` bump or per-project `update` — it's the static, machine-wide
  script the main spec already exempts from version-marker tracking, so this
  fix is live everywhere the moment `chezmoi apply` runs.
- `home/dot_claude/skills/setup-memory-workflow/assets/save-session-skill.md.template`
  — its three marker-writing spots (`Step 0` ×2, "On success") change from
  writing a bare session ID to writing `SESSION_ID:TURN_COUNT_AT_SAVE`; this
  piece *is* version-marked and per-project rendered, so it rides along with
  this change's shared `SMW_VERSION` bump and needs `check-drift.sh update`
  per project, unlike the hook script above.
- `home/dot_claude/skills/setup-memory-workflow/CHANGELOG.md`, `SKILL.md` —
  documentation of the new version bump, matching the existing pattern.
- Every project that has already run `check-drift.sh check` sees `drift-warn`'s
  session-log check take effect immediately on next session start (global
  script, no per-project render needed), same as the prior change's
  status-note bloat signal. The reworded hook message and the excerpt
  date-stamp are per-project rendered pieces — existing installs report drift
  and need `check-drift.sh update` to pick them up, consistent with every
  prior `SMW_VERSION` bump.
- No tag (`core`/`dev`/`ai`/etc.) gating changes — this only affects projects
  that have already opted into `setup-memory-workflow`.
- No secrets, permissions, or SIP implications — all additions and the
  `memory.sh` relocation are local file reads/comparisons inside
  `~/.local/share/basic-memory/` and `.claude/`, the same paths and trust
  boundary the prior change already established; no new file is read that
  wasn't already in scope for this skill.

## Non-goals

- Not moving the excerpt (or any other injected content) to live computation
  at session-start time — `design.md` from the prior change explicitly
  considered and rejected this, and that reasoning still holds; the
  `STALE-EXCERPT` category and the date-stamp are mitigations for the
  consequence of that decision, not a reversal of it.
- Not building an enforced, auto-pruning bloat mechanism (as OMC's
  `project-memory.json` FIFO caps or oh-my-pi's TTL-based decay do) —
  `save-session-maintenance` remains manual-trigger-only; this change only
  extends which signals nudge toward running it.
- Not changing the `PreToolUse` write-guard hook, or `save-session`'s own
  Step 1/Step 2 content-handling logic (only its marker-writing one-liners
  change) — and not changing `save-session-maintenance`'s own logic at all.
- Not adopting OMC's or oh-my-pi's injection models wholesale (budgeted
  multi-source blocks, structured `<memories>` schemas, prompt-cache-stable
  frozen recalls) — those are much larger architectural changes outside this
  change's scope; this change only closes the four specific, cheap gaps
  identified in the comparison.
- Not touching `migrations.sh` itself or moving any legacy-cleanup logic —
  it's a separate, parallel precedent this change follows, not something it
  changes.
- Not adding an unconditional `/clear`-source exclusion to the crash-recovery
  hook — the user explicitly confirmed a large amount of work after `/clear`
  should still trigger the reminder, which only the magnitude threshold
  (not a hard source-based skip) gets right.
