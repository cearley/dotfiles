# `setup-memory-workflow`: Session Memory Architecture

Analysis of how the `setup-memory-workflow` skill (`home/dot_claude/skills/setup-memory-workflow/`,
deployed by chezmoi to `~/.claude/skills/setup-memory-workflow/`) bootstraps and runs
per-project session memory on top of basic-memory. Source of truth for anything below is the
skill's own files and `openspec/specs/setup-memory-workflow/spec.md`; this document is a
read-oriented map of that implementation, not a spec itself — if the two disagree, the spec and
code win.

## Scope and non-goals

Covers one project's installed workflow: what gets rendered where, which hooks fire when, what
the `save-session` / `save-session-maintenance` skills instruct the model to do, and how
persistence is organized. Does not cover the retired plugin-era design (`basic-memory-workflow`
plugin with runtime `$PROJECT` resolution) beyond noting why it was abandoned — see the archived
OpenSpec changes under `openspec/changes/archive/*memory-workflow*` and
`openspec/changes/archive/2026-08-17-deprecate-basic-memory-workflow-plugin/` for that history.

## Components and where they live

Two locations matter: the **canonical templates** (chezmoi source, one copy, machine-wide) and
the **installed, per-project rendered copies** (one physically independent set per opted-in
project).

### Canonical source (`home/dot_claude/skills/setup-memory-workflow/`)

```
setup-memory-workflow/
├── SKILL.md                                    orchestrator: judgment calls only
├── scripts/
│   ├── executable_check-drift.sh               all mechanical work (check/update/apply)
│   ├── executable_basic-memory-write-guard.sh  PreToolUse hook script (static, global)
│   ├── executable_crash-recovery-hook.sh       SessionStart hook script (static, global)
│   └── migrations.sh
└── assets/
    ├── save-session-skill.md.template          __PROJECT__/__SMW_VERSION__ placeholders
    ├── save-session-maintenance-skill.md.template
    └── hook-message.txt.template
```

`check-drift.sh` is the only place with judgment-free mechanical logic: marker parsing, JSON
diffing, idempotent creation. `SKILL.md` covers exactly two decisions that need a human: whether
to install basic-memory, and whether to overwrite something that has drifted from canonical.

### Installed, per-project (rendered by `check-drift.sh check`, opt-in per project)

```
<project>/
├── .mcp.json                                   mcpServers.basic-memory entry
└── .claude/
    ├── skills/
    │   ├── save-session/SKILL.md               rendered from template, __PROJECT__ baked in
    │   └── save-session-maintenance/SKILL.md   rendered from template, disable-model-invocation
    ├── settings.local.json
    │   hooks.SessionStart  → [reminder hook, crash-recovery hook]
    │   hooks.PreToolUse    → [write-guard hook]  (matcher: Bash|Edit|Write)
    ├── basic-memory-project.txt                optional: overrides resolved project identity
    └── .last-saved-session                     marker: last session ID save-session evaluated
```

Two of the six installed pieces are deliberately **not** per-project rendered content: the
write-guard and crash-recovery *scripts* are static files deployed once, machine-wide, by
chezmoi. Only the hook *entry* pointing at their fixed global path lives per-project in
`settings.local.json` — drift on those two is detected by literal command-string comparison,
not a version marker.

## Project identity resolution

Resolved exactly once, at the top of `check-drift.sh`, and reused for every piece rendered or
checked in that invocation — no installed piece re-resolves identity at runtime.

1. Default: `$PROJECT = basename(git rev-parse --show-toplevel)`.
2. Override: `<project-root>/.claude/basic-memory-project.txt`, if present and non-blank.
3. Outside a git repo: `$PROJECT_ROOT` falls back to `pwd` rather than failing.

This value is substituted into every `__PROJECT__` placeholder at render time (via
`check_templated_file()` / `apply_templated_file()` in `check-drift.sh`) — there is no runtime
identity-resolution script shipped to any project.

## Drift detection and repair (`check-drift.sh`)

Three states per piece, reported by `check`:

| State | Meaning | `update` behavior |
|---|---|---|
| `UP-TO-DATE` | matches canonical for current version + identity | untouched |
| `DRIFT` | version marker stale, identity still matches | repaired unconditionally, no confirmation |
| `NAME-MISMATCH` | embedded project name ≠ current resolution (project dir renamed) | **never** auto-repaired — always skipped, even if also version-stale |

A piece that is both version-stale and identity-mismatched is still reported and treated as
`NAME-MISMATCH`, not `DRIFT` — fixing the version while silently changing identity is exactly
the failure `update` is designed never to cause. The only way to repair a `NAME-MISMATCH` is
`check-drift.sh apply <piece>`, invoked after the user explicitly confirms the identity change
is intentional.

A missing piece (not installed at all) is always created unconditionally — there is nothing to
lose, so no confirmation gate applies there.

Installing the workflow is **always an explicit, per-project action** (`check-drift.sh check`
run inside that project). A project where the script has never run has none of these pieces —
there is no mechanism by which installing elsewhere activates it here.

## Hooks: what fires, and when

### `SessionStart` — reminder hook (`hook-message.txt.template`)

Fires on every session start. Injects a system-reminder instructing the model to call
`search_notes` and `recent_activity` on the project's basic-memory corpus *before* responding
to the user or running any skill — including when the first message is itself a skill
invocation. It is purely an instruction; the hook performs no basic-memory call itself, and the
reminder does nothing if the model ignores it or basic-memory's MCP server isn't actually
available.

### `SessionStart` — crash-recovery hook (`executable_crash-recovery-hook.sh`, static/global)

Exists to cover the one gap `SessionEnd` cannot, by construction: a session that ends via
SIGKILL, crash, or a closed terminal never fires `SessionEnd`, so no save ever happens for it.

Mechanism, entirely local-file-based, no process spawned:

1. Reads `session_id`, `transcript_path`, `cwd` from hook stdin JSON.
2. Scans the transcript directory for `.jsonl` files, excluding the session now starting
   (matched by filename == current `session_id`), and picks the most recently modified one by
   mtime.
3. Compares that prior transcript's session ID (not its mtime) against the content of
   `.claude/.last-saved-session`.
4. If they **differ**, prints a system-reminder naming the prior transcript path, telling the
   model to surface this to the user and ask permission before running a catch-up pass — never
   runs the catch-up itself. If the user agrees, the model reads that transcript directly (its
   own context has no visibility into it) and follows `save-session`'s Step 1–2 and
   on-success/on-failure using the reconstructed content.
5. If they **match** (the prior session already completed its own save-session evaluation),
   prints nothing and exits 0.

Identity (session ID), not mtime, is the correctness-bearing comparison — an earlier mtime-based
version of this design was found unsound and replaced.

### `PreToolUse` — write-guard hook (`executable_basic-memory-write-guard.sh`, static/global)

Matcher: `Bash|Edit|Write`. Denies any call that would write directly into
`~/.local/share/basic-memory/` — the whole tree across every project, not scoped to the current
one — because a direct filesystem write bypasses the basic-memory MCP server's SQLite index and
per-note checksums, which can make a later `bm_edit` silently fail its optimistic-concurrency
check or leave `bm_search`/`recent_activity` stale.

- `Edit`/`Write`: denied if `tool_input.file_path` resolves (symlink-aware) under the base path.
- `Bash`: denied if the raw command text references the base path (after manually expanding
  `~` and `$HOME`, since the command isn't shell-evaluated before inspection) **and** matches a
  write-shaped pattern — a redirect (`>`/`>>`), one of `rm|mv|cp|touch|mkdir|truncate|dd|install|tee`,
  or `sed -i`.
- Reads (`cat`, `grep`, `jq`, `ls`, plain `Read` tool calls) are left unguarded — explicitly a
  heuristic that favors false positives (blocking something harmless) over false negatives; a
  sufficiently creative command (e.g. a Python one-liner) can still slip through.
- The model is redirected to `mcp__basic-memory__bm_write` / `bm_edit` instead.

## Agent instructions: the two installed skills

### `save-session` (model-invokable, proactive)

Frontmatter explicitly allows the model to invoke it on its own initiative when a session has
produced decision-worthy content — not gated on whether a file was edited.

- **Root anchor guard** (runs before anything else, including Step 0's marker touch):
  `PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd); cd "$PROJECT_ROOT"`, then
  verifies `.claude/skills/save-session/SKILL.md` exists there — protects every relative path
  in the skill against working-directory drift (an earlier `cd`, a worktree) over a long
  session.
- Every basic-memory call passes `project="__PROJECT__"` explicitly, and the result's own
  `project` field is checked against it after every write — never relies on the server
  remembering a project chosen on an earlier call.
- **Step 0** (self-invocation gate only; skipped on explicit `/save-session`): a mechanical
  pre-filter (meaningful tool-call/exchange volume) followed by judgment (did anything
  persistable actually happen) — never asks the user "should I save this session?". Either
  outcome of "nothing to save" still stamps `.claude/.last-saved-session` with
  `$CLAUDE_CODE_SESSION_ID`, so the crash-recovery hook sees this session as evaluated.
- **Step 1**: reads the current status note, then resolves the *active session-log note*
  deterministically — the **last wikilink in the most recent Status Summary entry** — rather
  than issuing a `search_notes` query. (A broader search once ranked a stale,
  similarly-named note above the real one and corrupted a save; this fixed the failure mode.)
  Falls back to `search_notes` only when no wikilink exists at all (cold start). Then edits the
  status note in place: moves resolved items Open → Resolved, adds new open items, updates
  "Last updated" — treating the existing Open list as a baseline to preserve, never a blank
  page to regenerate from this session's diff alone. Ends the new entry with a wikilink to the
  session-log note, which is exactly what the *next* save's Step 1 depends on.
- **Step 2**: appends today's detail (date, decisions, findings — not open items) to the note
  Step 1 resolved. Append-only; never restructures or resizes here.
- **On success / empty-skip**: stamps `.claude/.last-saved-session` again, confirms note titles
  and permalinks to the user.
- **On failure** (read/edit error, e.g. a note too large to read): reports the failure and
  stops — explicitly does not attempt chunked reads, inline summarization, or any other
  improvised workaround.

### `save-session-maintenance` (`disable-model-invocation: true`, manual-only)

Never runs on the model's own initiative or as part of a `save-session` call — only via
`/save-session-maintenance`. Same root-anchor guard pattern as `save-session`.

- **Step 1 — session-log rollover**: if the active session-log note is ≥300 lines, archives
  it under `sessions/` as `Session Log — <earliest-date>`, re-chains any prior "continuation"
  banner to point at the new archive instead of skipping ahead, and replaces the active note's
  body with a one-line "Continues from [[...]]" pointer — keeping its title/permalink stable so
  `save-session`'s own resolution keeps finding it.
- **Step 2 — status-note triage**: triggered by any of three independent signals — a read
  failure (size/token-limit error), total size ≥~8,000 chars or ≥200 lines, or any single entry
  ≥~800 chars (checked independently, since one long entry is itself the anti-pattern, not just
  a symptom of general growth). Delegates to `memory-defrag` if installed; otherwise splits
  manually into `reference/`/`known-issues/` notes with a one-line pointer left behind, and
  prefers `memory-lifecycle`'s archive-never-delete `move_note` over delete+recreate so existing
  wikilinks keep resolving. Repeats until all three signals clear.

## Memory hierarchy and persistence

```
~/.local/share/basic-memory/<project>/        one basic-memory "project" per chezmoi project,
│                                              stored OUTSIDE the git repo
├── status/
│   └── <project>-current-status              single current-state source of truth:
│                                              Open/Resolved items, environment facts,
│                                              "Last updated" date, edited in place
└── sessions/
    ├── Session Log — <active>                append-only dated entries; status note's
    │                                          latest Status Summary entry wikilinks here
    └── Session Log — <earliest-date>          archived copies created by rollover, chained
        (one per prior rollover)                via "Continues from [[...]]" banners
```

Two tiers, kept consistent by convention and by `save-session`'s own wikilink discipline rather
than by code:

- **Status note** — mutated, never grown unbounded. The authoritative "what's true right now."
- **Session log** — append-only narrative/decision detail. Grows until `save-session-maintenance`
  rolls it over; the chain of archived notes stays traversable in both directions (forward via
  the "Continues from" banner, backward via whichever archive the status-note wikilink or a
  prior archive's forward pointer names).

Writes to this tree go exclusively through the basic-memory MCP tools (`bm_write`, `bm_edit`),
enforced by the `PreToolUse` write-guard — direct filesystem writes are structurally blocked
from ordinary tool calls, keeping the SQLite index and per-note checksums consistent with disk.

## Persistence strategy, summarized

- **Per-project physical copies, not a shared reference.** Deliberately inverted from the
  retired plugin design, which shared one canonical copy across every enabled project and
  required a runtime `$PROJECT` resolution script in every installed piece. The plugin's
  update story (a commit-SHA-pinned cache with no `needsUpdate` signal) was confirmed stale on
  a real install during the investigation that led to this design; per-project copies trade
  that failure mode for an explicit, opt-in `check-drift.sh update`/`apply` step per project.
- **Version-marker drift, with identity mismatch always taking precedence.** Keeps "this got a
  routine template update" (safe, unconditional) and "this project's identity actually changed"
  (unsafe to guess at) as two different code paths that can never be conflated, even when both
  conditions are true simultaneously on the same piece.
- **Two static, machine-wide exceptions** (write-guard, crash-recovery scripts) carry no
  version marker at all — their content has no per-project identity to drift against; only the
  fixed hook *entry* referencing their global path is tracked and compared per project.
- **Crash resilience via a session-ID marker, not a timer.** `.claude/.last-saved-session` plus
  the crash-recovery hook is the explicit fallback for the one case `SessionEnd` cannot cover
  by construction (SIGKILL/crash/closed terminal) — comparing session IDs rather than file
  mtimes, after an mtime-based version of this was found unsound.

## Comparative lessons (vs. oh-my-claudecode and oh-my-pi)

Findings from a 2026-11-07 cross-project hcom debate between this project's analysis (chezmoi),
`oh-my-claudecode`'s memory architecture (as of its commit `0564555b6`, see its own
`docs/MEMORY-ARCHITECTURE.md`), and `oh-my-pi`'s memory/context-persistence design. Not
re-verified independently here — treat the other two projects' self-descriptions as their own
authoritative account, subject to drift the same way this document is.

### Confirmed as already the right call (by contrast, not just assumption)

- **Single-backend consistency.** oh-my-pi's own self-flagged weakness is exactly what chezmoi
  avoids: four memory backends (local file-consolidation, SQLite-based `mnemopi`, remote
  `hindsight`, lightweight `sharpshooter`) with genuinely different consistency/durability
  models, hidden behind one uniform tool interface (`recall`/`retain`/`reflect`/`memory_edit`),
  with nothing forcing a project to pick one consistently across contributors. Chezmoi's
  per-project templated install — always basic-memory, identical shape in every opted-in
  project — is the stronger position. Do not regress toward pluggable backends for novelty's
  sake.
- **Archive growth is deliberate, not a leak.** oh-my-claudecode flagged its own checkpoints
  growing unbounded because the write path (`PreCompact`) and the clean path (`SessionEnd`)
  disagree about what gets removed. Chezmoi's session-log rollover looks superficially similar
  (archived notes accumulate under `sessions/`) but is bounded per-file (~300 lines) and
  intentionally archive-never-delete, to preserve wikilink integrity — a designed tradeoff, not
  drift. Recorded here explicitly so it isn't mistaken for the same bug in a future audit.

### Five concrete improvements worth taking

1. **Bounded, structured injection instead of a bare instruction.** The `SessionStart` reminder
   hook only instructs the model to call `search_notes`/`recent_activity` — it trusts the model
   to retrieve the right slice every time, with no guarantee against a bloated note crowding out
   what matters. oh-my-claudecode instead builds a fixed-priority, char-budgeted context block
   (project-memory summary → Priority Context → pending todos → everything else) at
   `SessionStart`. Chezmoi could inject a small, size-bounded excerpt of the status note's Open
   items directly in the hook message — a cheap local file read, same no-process-spawn pattern
   the crash-recovery hook already uses — rather than relying entirely on the model's own
   retrieval judgment. **Implemented** via OpenSpec change `memory-workflow-sessionstart-improvements`
   (see `openspec/changes/archive/` once archived) — `extract_open_excerpt()` in `check-drift.sh`.
2. **Exactly-once-replay hardening.** `.claude/.last-saved-session` is a plain overwrite today.
   oh-my-claudecode uses a hard-link CAS marker for its checkpoint replay specifically to avoid
   a race on concurrent/rapid session starts. If concurrent sessions in one project (multiple
   worktrees, multiple panes) become plausible, the marker write should move to atomic
   write-to-temp-then-rename.
3. **A named routing cheat-sheet, surfaced proactively.** oh-my-claudecode's `remember` skill
   exists purely to tell the model which store a fact belongs in, separate from save mechanics.
   Chezmoi's equivalent routing logic (status note vs. session log vs. a future
   `reference/`/`known-issues/` split) currently only lives inside `save-session-maintenance`'s
   Step 2 — invoked rarely, manually. Surfacing a short routing convention from the
   `SessionStart` reminder or from `save-session` itself would make it visible where the
   decision is actually made, not just at triage time.
4. **Guard against silent capture-path breakage from upstream renames.** oh-my-claudecode's
   `<remember>`-tag capture silently breaks because Claude Code renamed its delegation tool from
   `Task` to `Agent` and the parser still matches the old name. Chezmoi's own hook scripts make
   comparable assumptions — literal `tool_name`/payload-field matches
   (`.tool_name`, `.tool_input.file_path`, `hooks.SessionStart[]?.hooks[]?.command`) — with no
   test verifying they still match Claude Code's current hook payload shape.
5. **Don't let "safe to re-run anytime" become an unkept promise.** oh-my-claudecode's retention
   caps are frequently never enforced because nothing actually calls the prune tool. Chezmoi's
   `check-drift.sh check` and `/save-session-maintenance` are honestly documented as manual-only
   — the spec doesn't claim otherwise — but that also means drift and note-bloat can sit
   unnoticed indefinitely between runs, with nothing nudging a session to check. A cheap,
   non-spawning staleness nudge at `SessionStart` (rough size check or days-since-last-check,
   same local-file-only style as the crash-recovery hook) would close that gap without
   weakening the deliberate manual-confirmation model for actual repairs. **Implemented** via
   OpenSpec change `memory-workflow-sessionstart-improvements` (see `openspec/changes/archive/`
   once archived) — `cmd_drift_warn()`'s note-bloat signal in `check-drift.sh`.

See `openspec/changes/` for the change spun up to implement items 1 and 5.

### Follow-up: `memory-workflow-cross-project-hardening` (2026-11-07)

A second change, `memory-workflow-cross-project-hardening`, closed the remaining gaps from
the 2026-11-07 comparison above: it added the session-log bloat nudge item 5 above didn't
yet cover (`check_session_log_bloat()` in `memory.sh`, mirroring the status-note signal),
split `cmd_check()`'s SessionStart-hook reporting into `STALE-EXCERPT: hook` vs `DRIFT: hook`
so a version-marker-only mismatch (baked excerpt/date content changed) is no longer
indistinguishable from an actual stale version marker, and reworded
`hook-message.txt.template`'s instruction text from an imperative "do this first" directive
to background-context framing — the half of that reminder-wording gap addressable without a
runtime capability change, conditioning the `search_notes`/`recent_activity` call on the
baked-in snapshot actually being insufficient/stale/missing rather than commanding it
unconditionally, while still forcing the real call on direct resume/status-request phrasing.
It also incorporates a newly observed version-drift instance from the `oh-my-pi` repo,
confirming the same staleness risk item 5 already flagged occurs in practice, not just in
theory.

Separately — found during this change's own design review, not from the cross-project
comparison — it corrected a scope conflation between note-content reading (live,
evolving basic-memory note data) and template-content drift (this skill's own versioned
canonical assets): the two had been mixed together inside `check-drift.sh` since v17;
`extract_open_excerpt()` and its status-note-path resolution were pulled out into a new
sourced file, `scripts/memory.sh`, with its own narrower, read-only contract, mirroring
`migrations.sh`'s precedent of a single-purpose sourced helper with no shebang and no
execute bit.

Separately again, it fixed two correctness gaps in `executable_crash-recovery-hook.sh`'s
identity-only comparison: a false positive after `/clear` (a new session ID in the same
project, with nothing actually unsaved) and a false negative when a session saved and then
kept going (same session ID as the marker, but real work happened afterward) — both fixed
by replacing the session-ID-equality check with a turns-since-last-save magnitude check
against a new `UNSAVED_TURN_THRESHOLD`.

See `docs/formal-models/memory-workflow.als` for an Alloy model of the invariants behind both
the current spec's piece drift/lifecycle state machine and the proposed delta's SessionStart
additions, verified with the `alloy-analyzer` CLI (Homebrew `alloy-analyzer` formula).

## Open questions / things this document does not resolve

- This document reflects the skill's state as read on 2026-11-07 (`SMW_VERSION` and template
  contents as currently checked in). Re-read `scripts/executable_check-drift.sh` and the
  `assets/*.template` files directly before relying on specifics here — `check-drift.sh check`
  itself is the authoritative live-drift answer for any given project.
- The retired plugin-era design is referenced for contrast only; see the archived OpenSpec
  changes for its actual mechanics if that history is needed.
