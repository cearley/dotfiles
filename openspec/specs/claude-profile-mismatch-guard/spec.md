# Claude Profile Mismatch Guard

## Purpose

Defines the permission contract of `claude-profile-mismatch-guard`, the `PreToolUse` hook
that flags reads/writes crossing Claude Code profile boundaries — e.g. editing
`~/.claude-work/CLAUDE.md` while `$CLAUDE_CONFIG_DIR` says `~/.claude-personal` is active.
Split out of `claude-tooling-write-guard` (code review, 2026-11-16): a different concern
(whose file is this, not whether it's safe to edit directly) with no shared state —
`claude-tooling-write-guard` (see `openspec/specs/claude-tooling-write-guard/`) handles
chezmoi-managed-file protection and has no profile-awareness of its own. This hook only ever
asks or stays silent; it never denies and never checks chezmoi-managed status.

## Requirements

### Requirement: Guard Never Denies or Auto-Approves

The guard SHALL respond to any tool call only with an `ask` decision or no output. It SHALL
NOT return `permissionDecision: "deny"` or `permissionDecision: "allow"` under any input.

#### Scenario: No input yields a deny or allow decision
- **WHEN** the guard is run against every fixture payload in its test suite
- **THEN** no output SHALL contain `"permissionDecision": "deny"` or `"permissionDecision": "allow"`

### Requirement: Cross-Profile Ask Tier

The guard SHALL return `ask` when an in-scope path — `settings.json`, `plugins/`,
`projects/`, or `CLAUDE.md`, live or chezmoi-source — belongs to a profile other than the
one `$CLAUDE_CONFIG_DIR` indicates is active, whether or not that path is itself
chezmoi-managed. `.claude.json` is excluded from this check entirely, since it's never
chezmoi-managed in any profile. `skills/` and `rules/` are excluded too, since they're
symlink-shared across every profile — there is no "wrong profile" for them. Unlike its
sibling hook, this guard also covers the `Read` tool.

#### Scenario: Edit of a different profile's file asks
- **WHEN** an Edit targets a file (chezmoi-managed or not) under a profile directory other
  than the one `$CLAUDE_CONFIG_DIR` indicates is active
- **THEN** the guard SHALL return `permissionDecision: "ask"`

#### Scenario: Read of a different profile's file asks
- **WHEN** a Read targets a file under a profile directory other than the one
  `$CLAUDE_CONFIG_DIR` indicates is active
- **THEN** the guard SHALL return `permissionDecision: "ask"`

#### Scenario: Plugins write in a different profile asks
- **WHEN** a Bash command redirects output into a file under a profile's `plugins/`
  directory other than the one `$CLAUDE_CONFIG_DIR` indicates is active
- **THEN** the guard SHALL return `permissionDecision: "ask"`

#### Scenario: .claude.json is out of scope regardless of profile
- **WHEN** an Edit targets any profile's `.claude.json`, including one other than the
  active profile
- **THEN** the guard SHALL NOT return a `permissionDecision`

#### Scenario: Same-profile path is not flagged
- **WHEN** an Edit targets a path belonging to the profile `$CLAUDE_CONFIG_DIR` indicates
  is active
- **THEN** the guard SHALL NOT return a `permissionDecision`
