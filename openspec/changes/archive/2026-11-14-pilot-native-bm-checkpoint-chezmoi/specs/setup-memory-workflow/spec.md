# Spec Delta

## ADDED Requirements

### Requirement: Native checkpoint/orient/diagnostic skills are available but not auto-invoked
The workflow SHALL make upstream BM 1.x `bm-checkpoint`, `bm-orient` and `memory-doctor` skills available as declared, installable skills alongside the existing shared memory skills. Their availability SHALL NOT itself trigger any automatic capture, write or consent change; each remains an explicit, agent- or user-invoked action.

#### Scenario: Skills are declared, not activated
- **WHEN** `bm-checkpoint`, `bm-orient` or `memory-doctor` is declared for installation
- **THEN** no automatic hook, startup capture or consent record is created as a side effect
- **AND** each skill is invoked only when an agent or user explicitly runs it

#### Scenario: Checkpoint write still follows the existing note-write contract
- **WHEN** `bm-checkpoint` performs a note write
- **THEN** the write is subject to the same host tool approvals and recording-consent boundary as any other basic-memory note write this workflow governs
- **AND** it does not bypass the `.basic-memory-workflow.json` consent check by virtue of being an upstream skill rather than `save-session`

### Requirement: Native lifecycle hooks remain disabled pending explicit consent mapping
The workflow SHALL NOT enable BM's native `SessionStart` or `PreCompact` plugin hooks (Claude Code or Codex) in any project as part of piloting the native checkpoint/orient/doctor skills. Enabling those hooks requires a separate, explicit proposal that maps their automatic behavior against the project's recording-consent record.

#### Scenario: Pilot installs skills without their sibling hooks
- **WHEN** the native checkpoint/orient/doctor skills are installed for a pilot project
- **THEN** the upstream plugin's `SessionStart` and `PreCompact` hook registrations are not installed or enabled alongside them

#### Scenario: Future hook adoption needs its own proposal
- **WHEN** enabling a native lifecycle hook is later proposed
- **THEN** that proposal explicitly states how the hook's automatic behavior respects or is gated by `.basic-memory-workflow.json` consent status
- **AND** adoption of the checkpoint/orient/doctor skills under this requirement does not itself authorize that later step

### Requirement: Native setup/configuration skills do not write chezmoi-owned settings
The workflow SHALL NOT use BM's native `bm-setup` skill (or any other upstream skill that writes directly to `.claude/settings.json`, `.claude/settings.local.json`, or `.mcp.json`) to configure a project. Any MCP server registration or project settings this workflow requires SHALL continue to be delivered through chezmoi-managed templates.

#### Scenario: bm-setup is available but its config-writing step is not used
- **WHEN** `bm-setup` or an equivalent upstream setup skill is present in a project's installed skill set
- **THEN** it is not invoked to write or merge `.claude/settings.json`, `.claude/settings.local.json`, or `.mcp.json`
- **AND** the project's actual MCP/server registration is whatever chezmoi's existing managed templates already deliver

#### Scenario: Conflicting settings are reported, not silently merged
- **WHEN** an upstream setup skill is run manually by a user outside this workflow and writes a `basicMemory` settings block
- **THEN** that write is understood to be outside this workflow's ownership boundary and is not treated as chezmoi-managed state
