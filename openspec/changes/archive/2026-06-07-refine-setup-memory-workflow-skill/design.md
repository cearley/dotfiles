## Context

The `setup-memory-workflow` skill (`home/dot_claude/skills/setup-memory-workflow/SKILL.md`) is a Claude Code skill that bootstraps basic-memory session context into any project. It installs a project-specific `save-session` skill, registers the project with basic-memory, and adds a `UserPromptSubmit` hook to `.claude/settings.local.json`.

The skill had three categories of problems:
1. **Shell fragility**: jq idempotency check used string comparison; hook command used multi-level escaping
2. **Runtime name resolution**: project name was computed by the save-session skill and hook at runtime, making them generic rather than project-specific
3. **Missing setup**: no step to register the basic-memory project or verify the written config

## Goals / Non-Goals

**Goals:**
- Shell commands are idiomatic and maintainable
- Project name is baked in at install time, not derived at runtime
- basic-memory project is registered as part of setup
- Notes live outside the repo to avoid working-tree clutter
- Written config is verified before reporting success

**Non-Goals:**
- Changing the already-installed chezmoi `save-session` skill
- Migrating existing basic-memory projects to the new path convention
- Supporting cloud-sync or multi-machine note access

## Decisions

### 1. `jq -e` exit code instead of string comparison

**Decision**: Replace `already_has=$(jq ...) && [ "$already_has" != "true" ]` with `if ! jq -e '...' file >/dev/null 2>&1`.

**Rationale**: `jq -e` exits non-zero when the expression evaluates to false/null, making it directly usable in shell conditionals without string comparison. The old pattern was fragile: if jq errored (malformed JSON), `$already_has` would be empty — not `"true"` — so the guard would silently pass and attempt to append a duplicate hook.

**Alternative considered**: Pipe jq through `grep -q true`. Rejected — same fragility, slightly more verbose.

### 2. `jq --arg` for hook command injection

**Decision**: Hoist the hook command string into a shell variable and pass it to jq via `--arg cmd "$hook_cmd"`.

**Rationale**: Inlining the command string inside the jq filter required `\\\"` sequences (shell-escaping inside shell-escaping inside jq string). `--arg` separates the string from the filter entirely — jq handles JSON-encoding, the shell variable holds plain text. Readable and maintainable.

**Alternative considered**: Use a heredoc to write the JSON directly. Rejected — bypasses jq's merge logic and loses the `//=` idempotency for the MCP server entry.

### 3. Resolve project name at install time

**Decision**: Detect `$PROJECT` once in step 2 and substitute it literally into both the `save-session` SKILL.md and the hook command string.

**Rationale**: The save-session skill installed by this workflow already uses the project name in its description and search query. Having it compute the name at runtime added complexity for no benefit — the skill is project-specific by design. Baking the name in also matches the pattern already observed in the installed chezmoi version of the skill.

**Alternative considered**: Keep runtime detection in the hook via `PROJECT=$(git rev-parse ...)`. Rejected — adds a subshell and `&&` chain to every prompt submission; fails silently if git is unavailable.

### 4. External notes directory

**Decision**: Register the basic-memory project at `$HOME/.local/share/basic-memory/$PROJECT`.

**Rationale**: Three options were evaluated:
- **Repo root** (`$PROJECT_ROOT`): Notes appear in `git status`, clutter the working tree
- **`docs/` subfolder** (official recommendation): Conflicts with existing `docs/` usage; adds AI session notes to the repo
- **External directory** (`~/.local/share/basic-memory/$PROJECT`): Zero repo impact, follows XDG convention, notes are personal/machine-local by nature

The external path is appropriate for session notes — they're ephemeral context, not versioned artifacts.

### 5. Idempotent project registration via `basic-memory project add`

**Decision**: Call `basic-memory project add "$PROJECT" <path>` unconditionally — no pre-check needed.

**Rationale**: Confirmed empirically: `basic-memory project add` exits 0 and prints "Project '...' already exists" when the project is already registered. No guard or error suppression required.

## Risks / Trade-offs

- **External path is machine-local**: Notes don't follow the repo across machines. Acceptable — session context is machine-specific anyway. → Mitigation: document in the skill's confirm step.
- **`$PROJECT` name collision**: If two different repos share the same `basename`, they'd map to the same basic-memory project and notes directory. → Mitigation: this is the same risk as the existing basic-memory project-naming convention; acceptable for the common case.
- **`settings.local.json` not in `.gitignore`**: If committed, the hook and MCP config become machine-specific noise in the repo. → Mitigation: skill's confirm step explicitly reminds the user to gitignore it.

## Open Questions

None — all decisions made and implemented.
