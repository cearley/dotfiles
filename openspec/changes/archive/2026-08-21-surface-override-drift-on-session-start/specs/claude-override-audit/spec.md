## ADDED Requirements

### Requirement: Automatic Session-Start Invocation Scoped to Current Persona
On Claude Code `SessionStart`, the system SHALL automatically run the drift check for the
single persona whose session is starting (derived from `$CLAUDE_CONFIG_DIR`), via a
`claude-settings-hooks-modifier`-managed `SessionStart` hook entry. This automatic invocation
SHALL NOT check any other declared persona as part of the same session start.

#### Scenario: Session start checks only the starting persona
- **WHEN** a Claude Code session starts under a given `$CLAUDE_CONFIG_DIR` persona
- **THEN** the drift check SHALL run for that persona only

#### Scenario: Other declared personas are not checked
- **WHEN** a session starts for one persona
- **AND** other personas are declared in the machine's `claude_envs` list
- **THEN** those other personas SHALL NOT be checked as part of that session start

### Requirement: Terse Report-Only Session-Start Output
When automatic invocation finds drift, the system SHALL emit a short `additionalContext`/
`systemMessage` pointer directing the user to run `check-claude-overrides` for full detail,
rather than the full sectioned-TSV `## drift` report the on-demand invocation produces. The
automatic invocation SHALL NOT modify any `settings.json`, `modify_settings.json.tmpl`, or
other Claude Code configuration file.

#### Scenario: Drift found emits a short pointer, not the full report
- **WHEN** automatic invocation finds one or more flagged entries for the current persona
- **THEN** it SHALL emit a short message pointing to `check-claude-overrides` for detail
- **AND** SHALL NOT emit the full sectioned-TSV `## drift` report inline

#### Scenario: No drift produces no message
- **WHEN** automatic invocation finds no flagged entries for the current persona
- **THEN** it SHALL emit no session-start message

#### Scenario: Automatic invocation never writes state
- **WHEN** automatic invocation runs, regardless of whether drift is found
- **THEN** no file under any `~/.claude*` directory or the chezmoi source tree SHALL be
  modified, other than the persona's own dedup state described below

### Requirement: Per-Persona Once-Per-Drift-State Dedup
The system SHALL fingerprint the currently-flagged persona/kind/key/value tuples for the
current persona and compare that fingerprint against the last one recorded for that same
persona. It SHALL emit a session-start message only when the current fingerprint is
non-empty and differs from the last recorded fingerprint for that persona, and SHALL record
the current fingerprint after each automatic invocation.

#### Scenario: Unchanged drift is not re-reported
- **WHEN** the current persona's drift fingerprint is non-empty
- **AND** it matches the fingerprint recorded from that persona's last automatic invocation
- **THEN** the system SHALL NOT emit a session-start message

#### Scenario: New or changed drift is reported
- **WHEN** the current persona's drift fingerprint is non-empty
- **AND** it differs from the fingerprint recorded from that persona's last automatic
  invocation (including no prior recorded fingerprint at all)
- **THEN** the system SHALL emit a session-start message
- **AND** SHALL record the new fingerprint for that persona

#### Scenario: Resolved drift updates recorded state silently
- **WHEN** the current persona's drift fingerprint is empty
- **AND** a prior non-empty fingerprint was recorded for that persona
- **THEN** the system SHALL record the empty fingerprint for that persona
- **AND** SHALL NOT emit a session-start message

#### Scenario: Dedup state is tracked independently per persona
- **WHEN** two different personas each have their own drift fingerprint history
- **THEN** a fingerprint change on one persona SHALL NOT affect whether a message is emitted
  for another persona's session start
