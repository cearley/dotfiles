# Spec Delta

## Purpose

Defines the permission contract of `claude-tooling-write-guard`, the `PreToolUse` hook that
steers edits of chezmoi-managed Claude Code tooling files to their source. It may block,
prompt, or inform, but never approve.

## ADDED Requirements

### Requirement: Guard Never Auto-Approves
The write guard SHALL respond to any tool call only with a `deny` decision, an `ask`
decision, additional context without a permission decision, or no output. It SHALL NOT
return `permissionDecision: "allow"` under any input.

#### Scenario: Unrecognized tooling mutation goes through normal permissions
- **WHEN** a Bash command modifies a persona `settings.json` in a form the guard does not
  classify (e.g. `python3 -c` writing to `~/.claude-personal/settings.json`)
- **THEN** the guard's output SHALL NOT contain a `permissionDecision` field
- **AND** the tool call SHALL be subject to Claude Code's normal permission evaluation

#### Scenario: Read of a tooling path is not auto-approved
- **WHEN** a Bash command only reads a persona `settings.json` (e.g. `jq . ~/.claude-work/settings.json`)
- **THEN** the guard's output SHALL NOT contain `"permissionDecision": "allow"`

#### Scenario: No input yields an allow decision
- **WHEN** the guard is run against every fixture payload in its test suite
- **THEN** no output SHALL contain `"permissionDecision": "allow"`

### Requirement: Informational Note Preserved
When a Bash command references a deployed tooling path, and the guard neither denies nor
asks, the guard SHALL emit its informational note as `additionalContext` and
`systemMessage` at most once per session, as it does today.

#### Scenario: Note emitted once per session
- **WHEN** two unclassified Bash commands referencing a tooling path run in the same session
- **THEN** the first SHALL produce the informational note
- **AND** the second SHALL produce no output

### Requirement: Deny and Ask Tiers Unchanged
The guard SHALL keep its existing tiered decisions. It SHALL return `deny` for direct
edits to chezmoi-managed tooling files, including the managed-key and full-overwrite rules
for `settings.json`. It SHALL return `ask` for edits under `plugins/`, or under `skills/`
directories chezmoi does not track.

#### Scenario: Managed file edit still denied
- **WHEN** an Edit targets a chezmoi-managed file under a persona directory
- **THEN** the guard SHALL return `permissionDecision: "deny"`

#### Scenario: Plugin cache edit still asks
- **WHEN** a Bash command redirects output into a file under a persona's `plugins/`
  directory
- **THEN** the guard SHALL return `permissionDecision: "ask"`
