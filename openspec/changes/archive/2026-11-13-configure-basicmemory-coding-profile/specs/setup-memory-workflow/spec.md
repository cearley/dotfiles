# Spec Delta

## ADDED Requirements

### Requirement: Project-local basicMemory coding-profile configuration
A project MAY declare a `basicMemory` configuration block (`sessionProfile`, `repository`, `placementConventions`) in its own tracked `.claude/settings.json` or gitignored `.claude/settings.local.json`, hand-authored and committed like the rest of those files. The workflow SHALL NOT write this block via BM's native `bm-setup` skill or any other automatic settings-writing path, per the existing requirement that native setup/configuration skills do not write chezmoi-owned settings.

#### Scenario: Coding profile is declared for a project
- **WHEN** a project's `.claude/settings.json` declares `basicMemory.sessionProfile: coding` with a `repository` value
- **THEN** `bm-checkpoint` run in that project resolves `sessionProfile: coding` per its own documented settings precedence and writes structured `coding_session` frontmatter instead of the `general` profile's prose

#### Scenario: No configuration means the general profile
- **WHEN** a project declares no `basicMemory` block
- **THEN** `bm-checkpoint` defaults to its own `general` profile, unchanged from before this requirement existed

#### Scenario: Configuration is not written by an automatic setup skill
- **WHEN** this workflow or its documentation recommends declaring a `basicMemory` block
- **THEN** the recommendation is to hand-author the block directly in `.claude/settings.json`/`.claude/settings.local.json`, not to run `bm-setup` or an equivalent automatic settings-writer

### Requirement: Rendered maintenance skill includes a memory-doctor health check
The canonical `save-session-maintenance` template SHALL include a step that runs BM's `memory-doctor` skill (or the equivalent read-only diagnostic call) unconditionally against the current project, and reports its findings alongside the rest of the maintenance summary. This step SHALL be read-only and SHALL NOT itself perform any repair, restructuring, archival or deletion.

#### Scenario: Maintenance run reports memory-doctor findings
- **WHEN** `/save-session-maintenance` runs in a project with this requirement's rendered template installed
- **THEN** it runs a read-only `memory-doctor` health check scoped to that project and includes its findings (or a clean result) in the completion summary, in addition to the log-rollover and status-note triage steps

#### Scenario: memory-doctor findings do not trigger automatic repair
- **WHEN** `memory-doctor` reports a finding during a maintenance run
- **THEN** the maintenance skill reports it for the user's attention and does not automatically act on it beyond the maintenance skill's own existing bounded scope

#### Scenario: Existing per-project copies are repaired via version update
- **WHEN** a project's already-rendered `save-session-maintenance` skill predates this requirement
- **THEN** running `check-drift.sh update` in that project repairs it to the version that includes the `memory-doctor` step, the same mechanism already used for prior version bumps
