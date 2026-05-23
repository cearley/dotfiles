## Why

The `claude-environments` partial defines per-env Claude wrappers as **shell functions** but every SpecStory wrapper as a **shell alias**. Aliases do not expand in non-interactive shells: `bash -c 'claude-work-spec ...'`, scripts, and cron all fail with `command not found`. The functions/aliases also differ in introspection (`type` reports each differently) and in shell completion behavior. This is a small but real correctness gap, and fixing it while the partial is being actively maintained is cheap.

## What Changes

- **BREAKING**: `claude-spec`, `claude-<name>-spec` (one per `claude_envs` entry), `codex-spec`, and `gemini-spec` SHALL be defined as shell functions instead of aliases.
- Each function SHALL forward extra arguments via `"$@"` so today's invocations like `claude-work-spec --resume` continue to work identically.
- The `openspecui` alias SHALL remain an alias — it is not an AI CLI wrapper, has no `CLAUDE_CONFIG_DIR` interaction, and never accepts extra arguments.
- The per-env base functions (`claude-<name>`) are unchanged — already functions.

## Capabilities

### New Capabilities
<!-- None -->

### Modified Capabilities
- `claude-environments`: Replaces the `SpecStory Wrapper Aliases` requirement with `SpecStory Wrappers`, defining the wrappers as shell functions with explicit `"$@"` argument forwarding.

## Impact

- **Affected files**:
  - `home/.chezmoitemplates/claude-environments` — replaces the `alias claude-spec=...`, the `range`-generated `alias claude-<name>-spec=...`, `alias codex-spec=...`, and `alias gemini-spec=...` lines with corresponding function definitions.
  - `openspec/specs/claude-environments/spec.md` — renames and modifies the `SpecStory Wrapper Aliases` requirement.
- **Tags affected**: `ai` only.
- **Machines affected**: All `ai`-tagged machines. Behavior in interactive shells is unchanged; non-interactive shells gain the ability to invoke `*-spec` wrappers directly.
- **Dependencies**: none. Pure refactor of existing template logic. No new packages, scripts, or files.
- **Security implications**: none. No secret handling, no permission changes.

## Non-goals

- Touching `openspecui`. It is an alias for `npx openspecui@latest` with no env or arg surface to unify.
- Restructuring or renaming sections of the partial.
- Adding new wrappers or new tools.
- Changes to the per-env base functions (`claude-<name>`) — already functions.
