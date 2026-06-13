## Why

The `setup-memory-workflow` skill writes the basic-memory MCP server to the wrong file (`.claude/settings.local.json` instead of `.mcp.json`), uses the wrong command invocation, and always writes the entry even when basic-memory is already globally registered — causing redundant or broken config on chezmoi-managed machines.

## What Changes

- The skill now checks `claude mcp list` before writing any MCP server entry; if basic-memory is already globally registered, the write step is skipped entirely
- MCP server config is written to `.mcp.json` at the project root (not `.claude/settings.local.json`)
- The MCP server command is corrected to `uvx --python 3.12 basic-memory mcp` (was `basic-memory mcp`)
- The UserPromptSubmit hook remains in `.claude/settings.local.json` (unchanged)
- The confirm step notes that `.mcp.json` may or may not warrant gitignoring, and leaves that decision to the user

## Capabilities

### New Capabilities

_(none)_

### Modified Capabilities

- `setup-memory-workflow`: MCP server target file changes from `.claude/settings.local.json` to `.mcp.json`; command corrected; global-registration check added before any MCP write

## Impact

- `home/dot_claude/skills/setup-memory-workflow/SKILL.md` — skill procedure updated
- `openspec/specs/setup-memory-workflow/spec.md` — requirements updated to match new behavior
- No chezmoi scripts, templates, or packages.yaml affected
- Affects any project where the skill has been previously run (`.claude/settings.local.json` entries written by old skill remain but are now superseded by `.mcp.json` going forward)
- Tags affected: `ai`

## Non-goals

- Migrating existing `.claude/settings.local.json` MCP entries written by previous skill runs
- Changing how the hook is structured or what it says
- Modifying the global MCP server registration in packages.yaml
