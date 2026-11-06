# Spec Delta

## Purpose

Lets a user run an approved OpenSpec change to completion in this repo with a single kickoff confirmation, without a second competing task ledger or manual phase-by-phase supervision.

## ADDED Requirements

### Requirement: Single writer of tasks.md
For the duration of one `/opsx:run-omc` invocation, only the orchestrating session SHALL modify the target change's `tasks.md`. Subagents spawned during the run SHALL NOT edit it.

#### Scenario: Executor reports completed work
- **WHEN** an executor subagent finishes a phase and reports which tasks it completed with evidence
- **THEN** the orchestrating session, not the subagent, updates `tasks.md` to check off those tasks

### Requirement: Preflight gates the run
`/opsx:run-omc <slug>` SHALL run a read-only preflight check before any implementation step, and SHALL stop without implementing anything if the change fails OpenSpec validation or has no remaining tasks.

#### Scenario: Change fails validation
- **WHEN** the named change fails `openspec validate`
- **THEN** the command stops, shows the validation errors, and does not spawn any executor

#### Scenario: Change has no remaining tasks
- **WHEN** the named change's task list has zero remaining tasks
- **THEN** the command stops and suggests `/opsx:verify` and `/opsx:archive` instead of implementing

### Requirement: Dirty working tree requires confirmation
If the working tree has uncommitted changes at preflight, the command SHALL ask the user to confirm before proceeding, and this SHALL be the only question asked before the run begins.

#### Scenario: Uncommitted changes present
- **WHEN** preflight finds uncommitted changes in the working tree
- **THEN** the command reports the count and asks the user to confirm proceeding before spawning any executor

### Requirement: Implementation proceeds phase by phase
The command SHALL group the change's pending tasks by phase and implement one phase at a time by default, spawning one executor subagent per phase with that phase's pending tasks only.

#### Scenario: Change has multiple phases
- **WHEN** the target change's tasks are grouped under multiple phase headers
- **THEN** the command implements each phase's tasks via a separate executor subagent, sequentially unless the phases touch disjoint files

### Requirement: Verification runs before any completion report
After implementation, the command SHALL run the `code-review` skill, the `opsx:verify` skill, and the `template-reviewer` agent when any `.tmpl` file changed, before producing a final verdict.

#### Scenario: Template file changed during implementation
- **WHEN** any `.tmpl` file was added or modified during the run
- **THEN** the `template-reviewer` agent runs as part of verification before the final report

#### Scenario: No template file changed
- **WHEN** no `.tmpl` file was added or modified during the run
- **THEN** the `template-reviewer` agent is skipped and the report notes it was skipped

### Requirement: Blocking findings trigger a bounded fix loop
If verification produces a blocking finding and fix iterations remain, the command SHALL spawn a fresh executor with the findings and retry verification, up to a configurable maximum (default 3).

#### Scenario: Verification finds a blocker with iterations remaining
- **WHEN** a verification pass reports a blocking finding and fewer than the maximum iterations have been used
- **THEN** the command spawns a fresh executor with the findings, then re-marks tasks and re-verifies

#### Scenario: Maximum iterations reached with a blocker still open
- **WHEN** a blocking finding remains after the configured maximum number of fix iterations
- **THEN** the command stops looping and reports BLOCKED with the remaining findings

### Requirement: The command never commits, pushes, or archives
`/opsx:run-omc` SHALL NOT create a git commit, push to a remote, or archive the OpenSpec change under any circumstance. Those actions remain explicit, separate user decisions after the final report.

#### Scenario: Run completes with a clean verdict
- **WHEN** every verification pass is clean and all tasks are marked complete
- **THEN** the command reports READY TO MERGE and tells the user to review the diff and decide on committing, pushing, and archiving — without performing any of those itself
