# Design

## Context

See `proposal.md` - Why for motivation. Current state, for this design's
purposes: `check-drift.sh` is 581 lines, mixing skill-file drift detection
with memory-content rendering (6x hand-repeated check/update/apply blocks
per piece, plus `canonical_hook_cmd()`'s excerpt-baking). `memory.sh` (154
lines, sourced only by `check-drift.sh`) holds the status-note/session-log
reading logic that must move out. `crash-recovery-hook.sh` (104 lines) and
`basic-memory-write-guard.sh` (84 lines) are static, machine-wide, non-
templated scripts already — the pattern this change extends to the reminder
hook. The `PreToolUse` write-guard hook blocks the model's own Bash/Edit/Write
calls into `~/.local/share/basic-memory/`; it does not fire on hook-command
subprocesses Claude Code spawns directly, which is why a hook script (unlike
the model) can read that tree directly without triggering it.

## Goals / Non-Goals

**Goals:**
- Every file under `scripts/` ≤100 lines, each with one clear responsibility.
- `check-drift.sh` and its sourced pieces-engine contain zero memory-content
  logic (status note, session log, Open/Resolved, bloat thresholds).
- The reminder hook's command string in `.claude/settings.local.json` never
  varies with note content, at any note size.
- A v18 install upgrades to v19 with no duplicate hook entries and no manual
  per-project step (except the already-accepted non-canonical-location case).

**Non-Goals:**
- Restated from proposal.md's Non-goals — not repeated here.
- Deciding `shellmetrics`'s exact CLI flags/thresholds now — confirmed against
  the tool's own docs during implementation (see Open Questions).

## Decisions

### D1: Split `check-drift.sh` into an orchestrator plus two sourced libraries, not just trim it
`lib-project.sh` (~15 lines: `resolve_project()` only) and `lib-pieces.sh`
(~90 lines: a generic templated-file piece engine plus a generic hook-command
piece engine, parameterized by match-substring/canonical-command/settings-
path/event) replace the current 6x-repeated jq blocks. `check-drift.sh`
itself becomes a ~70-90 line orchestrator: source the libraries, define a
table of skill-owned pieces, dispatch `check|update|apply|drift-warn` by
iterating that table.
**Alternative considered**: trim `check-drift.sh` in place (shorten comments,
tighten jq). Rejected — the 6x repetition is structural, not verbose comments;
trimming alone can't reach ≤100 lines without losing a piece's check/update/
apply coverage.

### D2: The reminder hook becomes a fourth static, non-templated, machine-wide script
`session-reminder.sh` joins `crash-recovery-hook.sh` and
`basic-memory-write-guard.sh` as a static script with no `__PROJECT__`
substitution and no version marker — it resolves `$PROJECT` itself at
runtime, the same way `check-drift.sh` does, using the same override-file-
then-git-basename logic (duplicated as a small `resolve_project()` call via
`lib-project.sh`, not re-derived). This is the architectural reversal the
spec delta's "Project identity is resolved once, at apply-time" MODIFIED
requirement calls out explicitly as a deliberate, scoped exception.
**Alternative considered**: keep the reminder hook as a per-project-rendered,
version-marked piece, with `canonical_hook_cmd()` only dropping the
`__OPEN_EXCERPT__` substitution. Rejected — there would be nothing left to
render; a per-project copy of a script with no project-specific content is
pure waste and reintroduces a drift surface (per-project copies of literally
identical bytes) for no benefit over one global script.

### D3: `session-reminder.sh` is read-only; it never creates a missing canonical note
Confirmed hazard: a raw filesystem write under `~/.local/share/basic-memory/`
bypasses basic-memory's own SQLite index/checksums — exactly what the
existing `PreToolUse` write-guard warns the model about for its own tool
calls. If no note exists anywhere, the hook prints nothing; creating the
canonical-path note is left to the model via `bm_write`, guided by
`save-session-skill.md.template`'s updated convention text.
**Alternative considered**: have the hook `cat > ` an empty skeleton note on
first run. Rejected on the index-bypass hazard above — a later `bm_edit`
against that file could silently fail its checksum guard.

### D4: Non-canonical status notes are flagged, never auto-moved
Mirrors `check-drift.sh`'s own `NAME-MISMATCH` philosophy for skill pieces:
detect, surface, never silently repair. Applies directly to the
`WES.ViewPoint.CommonMicro.API` case found during this change's research
(no `status/` folder at all) — that project's note sits entirely outside the
fallback glob's reach and gets no notice at all, which is an accepted,
documented limitation (see Risks).
**Alternative considered**: have the hook search more broadly (e.g. also try
`project/*Open*.md`) to catch that case. Rejected — an unbounded prober for
"status content living anywhere" is itself a maintenance burden and still
wouldn't reliably distinguish a real status note from an unrelated note; one
manual migration action per already-drifted project is cheaper and safer.

### D5: Migration via a new `migrate_legacy_reminder_hook()`, mirroring the existing `migrate_hook_config()` pattern
The hook-piece match substring changes from `contains("basic-memory")` (the
old baked reminder text always mentioned basic-memory) to
`contains("session-reminder.sh")` (the new script's own path). Without a
migration, an old-format entry wouldn't be matched by the new substring and
`lib-pieces.sh`'s generic CREATE path would append a second entry instead of
replacing the first. `migrate_legacy_reminder_hook()` runs unconditionally,
before the generic engine's CREATE path, exactly where `migrate_hook_config()`
and `migrate_sync_memory()` already run in today's `migrations.sh` — same
idempotent, surgical-jq-removal shape.

### D6: `shellmetrics` is CI-only, fetched ephemeral, never added to `packages.yaml`
No Homebrew formula exists for it, and no shipped script depends on it being
present at runtime — only the CI verification step needs it. Adding it to
`home/.chezmoidata/packages.yaml` would make every machine install a tool
nobody's workstation actually uses.
**Alternative considered**: add it as a chezmoi external (pinned script
download), available on dev machines too. Rejected as unnecessary scope — CLI
linting tools used only by CI don't need machine-wide installation; this can
be revisited if a human ever wants to run it locally.

### D7: Add an agent-driven shellmetrics review pass, alongside the CI gate
A reviewer agent is spawned during implementation (tasks.md 7.1) to run
`shellmetrics`/`shellcheck` and interpret the results, rather than relying on
the CI gate (D6, task 8.1) as the only check. CI gives a binary pass/fail;
an agent can read shellmetrics' numeric complexity output and suggest *where
and how* to split a file that's over threshold, catching and fixing the
problem during implementation instead of after a failed CI run.
**Alternative considered**: rely on the CI job alone. Rejected — a failing
CI run gives no guidance on which function to extract or how to restructure;
an agent pass during implementation closes that loop immediately.

## Risks / Trade-offs

- [A status note at a completely unconventional location, like
  `WES.ViewPoint.CommonMicro.API`'s `project/Current Open Items.md`, is never
  found by `session-reminder.sh`, canonically or via fallback] → Accepted and
  documented (D4); the reminder degrades to no excerpt for that project,
  identical to today's behavior for a project with no status note at all —
  strictly no regression, just no improvement there either. Follow-up: one
  manual migration action per such project, out of scope here.
- [`lib-pieces.sh`'s generic hook-piece engine subtly changes behavior for the
  write-guard or crash-recovery-hook pieces, which aren't supposed to change
  at all] → Verification step: diff old `check-drift.sh check` output against
  new, on the same fixture `settings.local.json`, for those two pieces
  specifically (see tasks.md).
- [Upgrade migration misses an edge case — e.g. a project with two legacy
  reminder entries from a prior bug, or none at all] → `migrate_legacy_reminder_hook()`
  removes every match, not just the first; idempotent by construction (safe
  to run with zero matches).
- [Trimming `assets/*.template` verbosity drops a behaviorally load-bearing
  instruction] → Spot-check against the pre-change version for the specific
  items the proposal names (two-step save, size thresholds, archive naming)
  before merging.
- [`shellmetrics`'s actual CLI syntax/output differs from what's assumed here]
  → Not assumed; left as an explicit open question for the implementer to
  resolve against the tool's own `--help`/README before wiring into CI.

## Migration Plan

1. Ship the new scripts/templates and the v18→v19 `migrations.sh` addition
   together, in one commit — there is no intermediate state where only some
   of this lands, since `check-drift.sh`'s piece table and `lib-pieces.sh`'s
   engine are co-dependent.
2. On this machine, run `check-drift.sh update` in chezmoi itself first
   (the project with the largest, real baked excerpt) as the first real-world
   verification, before relying on fixture tests alone.
3. Each other project (herdr, hcom, oh-my-claudecode, the three WES/
   viewpoint-report-automation work repos, and any other project with this
   skill installed) self-heals independently, whenever its own
   `check-drift.sh update` is next run there — this was always this skill's
   update model (per-project, explicit; see the "Per-project explicit opt-in"
   requirement, unchanged by this proposal) and nothing here changes it.
4. Rollback: if `session-reminder.sh` misbehaves in a project, the prior
   `setup-memory-workflow-version:18` skill files remain on disk in
   `~/.claude/skills/setup-memory-workflow/` at the chezmoi source level
   until the next `chezmoi apply` after this change ships; reverting the
   source commit and re-applying restores v18 behavior project-by-project on
   their next `check-drift.sh update`. No data migration is irreversible —
   `session-reminder.sh` never writes anything (D3), so there's no state to
   unwind beyond the hook entry itself.

## Open Questions

- Exact `shellmetrics` invocation (flags, output format, what counts as
  "over threshold") — confirm against the tool's own `--help`/README when
  wiring the CI step; doesn't change the specs, approach, or task breakdown,
  only the CI job's literal command line.
