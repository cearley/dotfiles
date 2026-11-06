## Purpose

Provides unattended, scheduled distillation of Claude Code session transcripts into a
machine-owned basic-memory note, running as a local background worker against the Anthropic API
rather than inside a Claude Code session, so that decision-worthy content is captured without the
user remembering to save and without any session ending unrecorded.

## ADDED Requirements

### Requirement: Scheduled execution, never hook-triggered
The worker SHALL be started by a periodic local scheduler on a fixed interval. No Claude Code
hook SHALL participate in triggering it, and the worker SHALL NOT be a Claude Code session.

#### Scenario: Worker runs with no Claude Code session active
- **WHEN** the scheduled interval elapses and no Claude Code session is running
- **THEN** the worker runs, processes any eligible transcripts, and exits

#### Scenario: Worker cannot trigger itself
- **WHEN** the worker runs to completion
- **THEN** no Claude Code session is created and no hook fires as a consequence, so the worker
  cannot cause another worker to start

### Requirement: Transcripts become eligible by quiescence
A transcript SHALL be eligible for distillation only when it has not been modified for at least a
configured quiet period AND contains unread content past its recorded offset.

#### Scenario: Session still in progress is skipped
- **WHEN** a transcript was modified more recently than the quiet period
- **THEN** it is not distilled on this run, regardless of how much unread content it holds

#### Scenario: Cleanly ended session is distilled
- **WHEN** a session ends normally and its transcript then remains untouched for the quiet period
- **THEN** its unread content is distilled on the next run

#### Scenario: Crashed session is distilled by the same path
- **WHEN** a session is killed, crashes, or its terminal is closed, so no orderly shutdown occurs
- **THEN** its transcript goes quiet like any other and is distilled by the same mechanism, with
  no separate crash-recovery path

### Requirement: Projects opt in by explicit registration
The worker SHALL process only projects listed in its registry. It SHALL NOT discover projects
implicitly by scanning the filesystem.

#### Scenario: Unregistered project is ignored
- **WHEN** a project has Claude Code transcripts but no registry entry
- **THEN** the worker does not read or distil them

#### Scenario: Registry entry points at a missing directory
- **WHEN** a registry entry names a project root that no longer exists
- **THEN** the worker logs the condition and skips that entry, continuing with the remaining
  projects, and does not remove the entry itself

### Requirement: Transcripts are discovered across all Claude Code profiles
The worker SHALL locate a registered project's transcripts across every Claude Code configuration
profile present on the machine, not only the currently active one.

#### Scenario: Sessions from multiple profiles
- **WHEN** a project has transcripts under more than one Claude Code configuration profile
- **THEN** transcripts from all of them are considered for eligibility

#### Scenario: A new profile appears
- **WHEN** an additional configuration profile is created later
- **THEN** its transcripts are discovered without any change to the worker's configuration

### Requirement: Progress is tracked per session and advances only on verified success
The worker SHALL record, per session, how much of that session's transcript has been distilled,
and SHALL advance that record only after confirming the resulting write succeeded and landed in
the intended basic-memory project.

#### Scenario: Write fails
- **WHEN** the distillation or the write to basic-memory fails for any reason
- **THEN** the recorded position is left unchanged, so the same content is reprocessed on a later
  run rather than being silently dropped

#### Scenario: Write lands in the wrong project
- **WHEN** the write succeeds but the result reports a basic-memory project other than the one
  intended for that registered project
- **THEN** the run is treated as failed, the recorded position is not advanced, and the mismatch
  is logged

#### Scenario: Session is resumed and continues
- **WHEN** a previously distilled session is resumed, grows, and then goes quiet again
- **THEN** only the content added since the recorded position is distilled

### Requirement: All basic-memory access goes through the basic-memory MCP server
The worker SHALL read and write basic-memory content exclusively through the basic-memory MCP
server. It SHALL NOT write vault files directly, and SHALL name the target basic-memory project
explicitly on every call.

#### Scenario: Note is written through the server
- **WHEN** the worker records distilled output
- **THEN** it does so via the MCP server, leaving frontmatter, permalinks and the search index
  under basic-memory's sole control

#### Scenario: Server is unavailable
- **WHEN** the basic-memory MCP server cannot be started
- **THEN** the worker logs the failure, skips that project, and continues with the remaining ones

### Requirement: The worker writes exactly one note per project and never curated content
For each registered project the worker SHALL write to exactly one machine-owned note. It SHALL
NOT create, edit, or delete any note maintained by a human, including the curated session log and
the status note.

#### Scenario: Distilled output is appended
- **WHEN** the worker distils a session
- **THEN** the output is appended to that project's machine-owned note, creating it if absent

#### Scenario: Curated notes are untouched
- **WHEN** the worker runs while curated notes exist in the same basic-memory project
- **THEN** those notes are not modified, and no coordination with any interactive session is
  required because the worker and the user never write the same note

### Requirement: The machine-owned note is rolled over mechanically
When the machine-owned note exceeds a configured size threshold, the worker SHALL move older
entries into a dated archive note. This rollover SHALL be deterministic and SHALL NOT depend on
model judgment.

#### Scenario: Threshold exceeded
- **WHEN** the machine-owned note grows past the configured threshold
- **THEN** entries older than the most recent dated entry are moved into an archive note, and the
  live note retains the most recent entries

#### Scenario: Below threshold
- **WHEN** the note is under the threshold
- **THEN** no rollover occurs

### Requirement: Maintenance thresholds are reported, never acted on
The worker SHALL evaluate size and structure thresholds for the project's curated notes and record
its findings in its own machine-owned note. It SHALL NOT perform editorial maintenance on curated
notes.

#### Scenario: Curated note is oversized
- **WHEN** a curated note crosses a maintenance threshold
- **THEN** the worker records that finding where the user will see it, and makes no change to the
  curated note itself

#### Scenario: Findings are refreshed, not accumulated
- **WHEN** the worker records maintenance findings on a later run
- **THEN** the previous findings are replaced rather than appended, so the report reflects current
  state

### Requirement: Absent credentials degrade to a logged no-op
The worker SHALL require an Anthropic API key. When none is available it SHALL exit without error
after recording the condition once.

#### Scenario: No API key configured
- **WHEN** the worker runs on a machine where no API key is available
- **THEN** it records the condition, exits successfully, and does not repeat the message on every
  subsequent run

#### Scenario: Credentials are never taken from a Claude Code subscription
- **WHEN** the worker calls the Anthropic API
- **THEN** it authenticates with an API key, never with Claude Code subscription credentials

### Requirement: Per-run cost is bounded
The worker SHALL bound the work performed in a single run, by both the number of sessions
processed and the volume of transcript content sent to the API, and SHALL record usage.

#### Scenario: Large backlog
- **WHEN** more eligible sessions exist than the configured per-run cap
- **THEN** the worker processes up to the cap and leaves the remainder for subsequent runs

#### Scenario: Oversized transcript
- **WHEN** a single transcript exceeds the configured content budget
- **THEN** it is reduced to fit the budget before being sent, and the reduction is evident in what
  is sent

#### Scenario: Usage is recorded
- **WHEN** a run completes
- **THEN** the tokens consumed by that run are recorded in the log

### Requirement: Every run is auditable, including failures before distillation begins
The worker SHALL record each run's outcome to a local log, including failures that occur before
any model interaction starts.

#### Scenario: Process fails at startup
- **WHEN** the worker fails before reaching the API (missing dependency, unusable credentials,
  scheduler-level failure)
- **THEN** the failure is recorded in the log rather than being visible only as an absence of
  output

#### Scenario: Successful run
- **WHEN** a run completes normally
- **THEN** the log records which projects were scanned, which sessions were distilled, and the
  usage incurred
