## Why

The `setup-memory-workflow` skill bootstraps basic-memory session context into any project, but its shell commands were fragile (jq string-comparison idempotency check, deeply nested escaping in the hook command) and it lacked a step to register the basic-memory project or verify the output — making silent failures possible and the skill hard to maintain.

## What Changes

- **Fix jq idempotency guard**: replace `already_has=$(jq ...) && [ "$already_has" != "true" ]` pattern with `jq -e` exit-code check — more robust and idiomatic
- **Fix hook command escaping**: hoist the hook command string into a shell variable passed via `jq --arg`, eliminating `\\\"` nesting inside jq filters
- **Resolve project name at install time**: both the `save-session` skill content and the UserPromptSubmit hook command now have the project name baked in at install time (not computed at runtime), matching the pattern already used in the chezmoi project
- **Add basic-memory project registration step**: explicitly call `basic-memory project add "$PROJECT" "$HOME/.local/share/basic-memory/$PROJECT"` so the project exists before any MCP tools try to use it
- **Use external notes directory**: project notes stored at `~/.local/share/basic-memory/<project>/` rather than inside the repo root, avoiding working-tree clutter
- **Add settings verification step**: run a jq query after writes to confirm both the MCP server entry and hook command landed correctly
- **Fix install instruction**: replace `uvx basic-memory` (ephemeral run) with `uv tool install basic-memory` (persistent install)
- **Strengthen description**: reframe around the user benefit (persistent context across sessions) and add "frustration about losing context" as a trigger signal

## Capabilities

### New Capabilities

- `setup-memory-workflow`: The skill itself — bootstraps basic-memory session workflow (save-session skill + MCP config + UserPromptSubmit hook) into any project with correct project registration, install-time name injection, and post-write verification

### Modified Capabilities

<!-- No existing spec-level capability changes — this change affects only the skill file itself -->

## Non-goals

- Does not change the `save-session` skill already installed in the chezmoi project (`.claude/skills/save-session/SKILL.md`)
- Does not migrate existing basic-memory projects to the new external path convention
- Does not add cloud-sync or multi-machine sync for basic-memory notes

## Impact

- **File changed**: `home/dot_claude/skills/setup-memory-workflow/SKILL.md`
- **No chezmoi templates affected**: the skill is a plain markdown file, not a `.tmpl`
- **No secrets involved**
- **Tags affected**: `ai` (skill is only deployed to machines with the `ai` tag)
