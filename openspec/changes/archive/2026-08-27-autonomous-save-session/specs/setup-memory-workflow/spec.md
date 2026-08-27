## MODIFIED Requirements

### Requirement: Skill is distributed as per-project rendered copies, not a shared reference

The `save-session` skill (now scoped to the fast, append-only `save` concern), a new
`save-session-maintenance` skill (the periodic rollover/triage concern), the `sync-memory`
skill and script, and the `SessionStart`/`SessionEnd` hook configuration SHALL each be rendered
from a canonical template into the target project's own `.claude/` directory (or
`.claude/settings.local.json`, for hooks), with a version marker
(`setup-memory-workflow-version:N`) embedded in each rendered piece.

#### Scenario: Missing piece is created unconditionally
- **WHEN** `check-drift.sh check` finds a piece (skill file, script, hook entry, or `.mcp.json`
  entry) missing from the current project
- **THEN** it renders the current canonical template into place directly — creating a missing
  piece is always safe and requires no confirmation

#### Scenario: Two projects have independent copies
- **WHEN** the workflow is installed in two different projects
- **THEN** each project has its own physically separate rendered files — editing one project's
  installed copy has no effect on the other

#### Scenario: One canonical copy serves every enabled project
- **WHEN** considering the retired plugin-era guarantee this scenario originally described —
  that two projects with the plugin enabled ran the exact same shared skill/hook content, with
  no per-project rendered copy of any of it
- **THEN** it is deliberately inverted, not preserved: each project now has its own
  independently rendered copy (see "Two projects have independent copies" above) — this is the
  whole point of returning to a copy-based distribution, since a single shared copy is exactly
  what made runtime `$PROJECT` resolution necessary and skippable in the first place

#### Scenario: Updating the plugin updates every consumer
- **WHEN** considering the retired plugin-era guarantee this scenario originally described —
  that changing the canonical plugin content and updating the marketplace propagated to every
  enabled project automatically, with no per-project drift-check or repair step
- **THEN** it is deliberately inverted, not preserved: canonical template changes now reach an
  installed project only when `check-drift.sh update` (or `apply`) is explicitly run there —
  propagation is opt-in and per-project again

## ADDED Requirements

### Requirement: `save-session` is limited to append-only work with no size/triage logic

The `save-session` skill SHALL append to the session log without checking or acting on its
size, and SHALL update the current status note's Open/Resolved content without checking or
acting on the note's size. On a status-note read or edit failure, it SHALL log the failure and
stop, and SHALL NOT attempt rollover, triage, splitting, or any other remediation inline.

#### Scenario: Session log append never checks size
- **WHEN** `save-session` appends today's update to the session log
- **THEN** it does not read the log's current line count or size before appending, and does not
  trigger any rollover — rollover is exclusively `save-session-maintenance`'s responsibility

#### Scenario: Status-note edit failure is logged, not fixed
- **WHEN** `save-session` reads the current status note and the read fails with a size/token-limit
  error
- **THEN** it records the failure in the audit log (see the audit-log requirement below) and
  stops — it does not fall back to local-file inspection, triage, or any other remediation; that
  is `save-session-maintenance`'s job, triggered separately

### Requirement: `save-session-maintenance` owns all rollover and triage logic

A new `save-session-maintenance` skill SHALL own the session-log rollover threshold (≥300
lines) and the status-note's three-signal oversized-note detection (read failure, total size
≥~8,000 characters, any single entry ≥~800 characters), delegating to the `memory-defrag`/
`memory-lifecycle` skills where installed, exactly as `save-session`'s prior Step 3b did. This
logic SHALL NOT run as part of any `save-session` invocation.

#### Scenario: Maintenance triages an oversized status note
- **WHEN** `save-session-maintenance` runs and the status note is at or over the total-size or
  single-entry-length threshold
- **THEN** it triages the note (via `memory-defrag` if installed, manually otherwise), following
  the same archive-never-delete preference (`memory-lifecycle`'s `move_note` pattern) as before

#### Scenario: Maintenance is a no-op when nothing is over threshold
- **WHEN** `save-session-maintenance` runs and neither the session log nor the status note meets
  any of the rollover/triage thresholds
- **THEN** it makes no changes and reports nothing to do

### Requirement: In-session autonomous save requires no user confirmation

When a mechanical pre-filter passes and a subsequent LLM judgment step determines the current
session has produced decision-worthy content, the model SHALL invoke `save-session`'s fast path
directly, without asking the user for confirmation first. The mechanical pre-filter SHALL be
based on tool-call count or conversation length, and SHALL NOT be based on whether any file was
edited.

#### Scenario: Decision-worthy session saves without a confirmation prompt
- **WHEN** a session has produced an architectural decision, a resolved open item, or another
  save-worthy finding, and the mechanical pre-filter has passed
- **THEN** the model runs `save-session`'s fast path directly — it does not ask "should I save
  this session?" and wait for a yes

#### Scenario: Trivial session is skipped by the mechanical pre-filter
- **WHEN** a session consists of a single trivial exchange (e.g., a one-off factual lookup with
  no decisions made)
- **THEN** the mechanical pre-filter fails and no LLM judgment call or save is triggered

#### Scenario: File-edit-free session still passes the mechanical pre-filter
- **WHEN** a session makes substantial tool calls (reads, searches, fetches) and reaches
  real decisions but edits no files (e.g., an `/opsx:explore` session)
- **THEN** the mechanical pre-filter passes on tool-call/conversation-length grounds alone,
  independent of whether any file was ever edited, and LLM judgment still runs

### Requirement: The session marker records every terminal outcome, not only successful saves

`save-session` SHALL record the current session's ID in `.claude/.last-saved-session` on every
terminal outcome — success, no-op, and failure alike. The marker's meaning is "the last session
this skill reached a terminal outcome on", not "the last session that saved successfully".
`save-session-maintenance` SHALL do the same on its headless path. A proactive pre-filter
decision not to save a session that is still in progress is NOT a terminal outcome and SHALL NOT
stamp the marker.

#### Scenario: Session assessed as not worth saving
- **WHEN** a headless catch-up run reads a transcript and concludes there is nothing
  decision-worthy to persist
- **THEN** it logs a `no-op` to the audit log **and** records the session marker, so the
  `SessionStart` crash-recovery gate sees its transcript as covered

#### Scenario: Save fails partway through
- **WHEN** a save run fails (e.g. a status-note edit errors after a successful read)
- **THEN** it logs a `failure` to the audit log **and** records the session marker, so the
  failure is recorded once rather than retried by a fresh worker on every subsequent
  `SessionStart`

#### Scenario: Headless maintenance run finishes
- **WHEN** a detached `save-session-maintenance` run completes
- **THEN** it records the session marker, so its own transcript does not become an uncovered
  newest-prior that triggers a pointless catch-up worker

#### Scenario: Marker is never left empty
- **WHEN** the session ID is unavailable when the marker would be written
- **THEN** the marker file is left unchanged and the condition is logged, rather than written as
  an empty value that matches no session

### Requirement: `SessionEnd` hook triggers unattended save catch-up

A `SessionEnd` hook SHALL check a project-local marker file
(`.claude/.last-saved-session`) for whether the ending session's ID is already recorded there.
If not, it SHALL spawn a detached process running `save-session`'s fast path headlessly against
the ending session's own transcript, and SHALL return control to the CLI without waiting for
that detached process to complete.

#### Scenario: In-session save already covered this session
- **WHEN** a session ends and its ID matches the marker file's recorded value
- **THEN** the `SessionEnd` hook does not spawn a detached save run

#### Scenario: Ending session's transcript no longer exists
- **WHEN** a session ends and its recorded transcript path does not resolve to an existing file
- **THEN** no detached run is spawned and the condition is logged, rather than a worker being
  started that would hold the shared lock only to find nothing to read

#### Scenario: Session ends with no prior in-session save
- **WHEN** a session ends and the marker file does not record its ID (no in-session save
  occurred, or the pre-filter never passed)
- **THEN** the `SessionEnd` hook spawns a detached headless save run against that session's
  transcript and returns immediately, without blocking CLI exit on that run's completion

### Requirement: `SessionStart` opportunistically triggers maintenance and crash-recovery save, non-blocking

A `SessionStart` hook SHALL perform a mechanical, file-based check (no MCP round-trip) of the
session log's line count and the status note's size/longest-entry length against
`save-session-maintenance`'s thresholds, and SHALL separately check whether the marker file
covers the most recently modified transcript in the current project. Both checks SHALL complete
without blocking session startup on any spawned remediation work.

#### Scenario: Nothing over threshold, marker current — no-op
- **WHEN** `SessionStart` runs and neither maintenance threshold is met, and the marker file
  already covers the most recent transcript
- **THEN** no detached process is spawned and no advisory is printed

#### Scenario: Maintenance threshold met, no run already in progress
- **WHEN** `SessionStart` runs and a maintenance threshold is met, and the lockfile shows no
  maintenance run currently in progress
- **THEN** it spawns a detached headless `save-session-maintenance` run, prints one advisory
  line (visible to Claude via `SessionStart`'s stdout), and returns without waiting for that run
  to complete

#### Scenario: Maintenance already running — skipped, not duplicated
- **WHEN** `SessionStart` runs and the lockfile shows a maintenance run already in progress
- **THEN** it does not spawn a second maintenance run

#### Scenario: Marker file doesn't cover the most recent transcript (crash recovery)
- **WHEN** `SessionStart` runs and the most recently modified transcript in the current project
  (excluding the session starting now) has a session ID that does **not** match the marker file's
  recorded value (e.g. the prior session was killed or crashed, so `SessionEnd` never fired for it)
- **THEN** it spawns the same detached headless save catch-up `SessionEnd` would have run, on
  this best-effort, next-session basis

#### Scenario: Catch-up worker's own transcript does not re-trigger the gate
- **WHEN** a detached catch-up worker finishes and its own transcript becomes the most recently
  modified one in the project
- **THEN** the next `SessionStart` finds that transcript's ID recorded in the marker and spawns
  nothing, terminating the chain after exactly one catch-up

### Requirement: Detached save and maintenance runs use `claude -p` headless execution

Both the `SessionEnd`-triggered save catch-up and the `SessionStart`-triggered maintenance run
SHALL execute via `claude -p` (Claude Code's headless mode), reusing the invoking machine's
existing Claude Code authentication. Neither SHALL require a separately provisioned API key or
support an alternate model-provider backend (e.g. OpenRouter).

#### Scenario: Maintenance delegates to a companion skill
- **WHEN** a detached `save-session-maintenance` run determines the status note needs
  splitting and the `memory-defrag` skill is installed
- **THEN** the headless `claude -p` process invokes `memory-defrag` against that note, exactly
  as an interactive session would

#### Scenario: Model is changed via a single flag
- **WHEN** a different model is desired for detached runs (e.g. for cost or quality reasons)
- **THEN** changing `claude -p`'s `--model` argument is sufficient — no code restructuring or
  alternate execution path is required

### Requirement: Detached runs are auditable via a project-local log

Every detached save-catch-up or maintenance run SHALL append a record (timestamp, trigger,
outcome, and any error) to a project-local audit log under `.claude/`. This log SHALL be the
mechanism by which failures are surfaced, since no interactive session observes these runs
directly.

#### Scenario: Successful detached run is logged
- **WHEN** a detached save or maintenance run completes successfully
- **THEN** the audit log gains an entry recording the trigger (`SessionEnd`/`SessionStart`),
  timestamp, and outcome

#### Scenario: Failed detached run is logged, not silently dropped
- **WHEN** a detached save or maintenance run fails (e.g. the headless process errors, or a
  status-note edit fails)
- **THEN** the audit log gains an entry recording the failure, so a later interactive session
  or a manual check can discover it

#### Scenario: Detached process dies before the skill can log anything
- **WHEN** the spawned headless process exits non-zero without reaching the skill's own failure
  handling (authentication failure, missing binary, timeout-kill, or an out-of-memory kill)
- **THEN** the spawning hook itself records a `failure` entry naming the calling branch and
  distinguishing a signal kill from an ordinary non-zero exit, so the run is never invisible

#### Scenario: No worker identity can be assigned
- **WHEN** a detached run is about to be spawned but no session ID can be generated for it
- **THEN** the run is abandoned, the lock released, and a failure logged — rather than spawning a
  worker with no recorded lock holder, which the `PreToolUse` guard would deny for the full
  timeout

### Requirement: New runtime state is project-local and unshared

The marker file, lockfile, and audit log this change introduces SHALL live under the target
project's own `.claude/` directory, matching `.claude/settings.local.json`'s existing
personal-machine scoping — not committed, not shared across machines.

#### Scenario: State does not leak between projects
- **WHEN** two projects both have this workflow installed
- **THEN** each has its own independent marker file, lockfile, and audit log under its own
  `.claude/` directory
