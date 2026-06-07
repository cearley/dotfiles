---
name: setup-memory-workflow
description: Set up the basic-memory session workflow in the current project so Claude remembers context across sessions. Installs the save-session skill, configures the basic-memory MCP server, and adds a hook that primes Claude with prior session notes at every prompt. Use whenever the user says "set up memory", "add basic-memory", "configure save-session", "initialize memory workflow", "set up session notes", or expresses frustration about losing context between sessions — even if they don't use those exact words.
---

This skill bootstraps the basic-memory session workflow in the current project. Each step is idempotent — safe to run more than once.

## Steps

### 1. Verify basic-memory is installed

Run:
```bash
which basic-memory
```

If not found, tell the user to install it first (`uv tool install basic-memory`), then stop.

### 2. Detect project name and create skill directory

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PROJECT=$(basename "$PROJECT_ROOT")
mkdir -p .claude/skills/save-session
```

`$PROJECT` and `$PROJECT_ROOT` are used in steps 3–5 — resolve them once here.

### 3. Register the basic-memory project

```bash
basic-memory project add "$PROJECT" "$HOME/.local/share/basic-memory/$PROJECT"
```

This is idempotent — if the project already exists it prints a notice and exits 0. Notes are stored outside the repo in `~/.local/share/basic-memory/<project-name>/`, so they never clutter the working tree or git status.

### 4. Install the save-session skill

If `.claude/skills/save-session/SKILL.md` already exists, skip this step and tell the user it's already present.

Otherwise write `.claude/skills/save-session/SKILL.md` with `$PROJECT` substituted in for `<project-name>`:

```markdown
---
name: save-session
description: Append today's decisions, findings, and next steps to the <project-name> basic-memory note. Run at end of every coding session.
---

Search basic-memory project "<project-name>" for the most recent session note using search_notes with query "<project-name> session".

Append an update with edit_note (operation="append") including:
- Date (use the currentDate value from context)
- What was changed or decided today
- Any new open items or next steps discovered
- Any resolved items that can be checked off

Never overwrite the existing note — always append.
Confirm the note title and permalink after saving.
```

### 5. Update `.claude/settings.local.json`

Use jq to merge into `.claude/settings.local.json` (create it if absent). `$PROJECT` was resolved in step 2 — use it directly when constructing the hook command.

**Ensure the file exists first:**
```bash
[ -f .claude/settings.local.json ] || echo '{}' > .claude/settings.local.json
```

**Add basic-memory MCP server** (idempotent — `//=` only sets if key is absent):
```bash
jq '.mcpServers["basic-memory"] //= {"command": "basic-memory", "args": ["mcp"]}' \
  .claude/settings.local.json > .claude/settings.local.json.tmp \
  && mv .claude/settings.local.json.tmp .claude/settings.local.json
```

**Add UserPromptSubmit hook** (only if no existing hook already contains "basic-memory"):
```bash
if ! jq -e '[.hooks.UserPromptSubmit[]?.hooks[]?.command // ""] | any(contains("basic-memory"))' \
    .claude/settings.local.json >/dev/null 2>&1; then
  hook_cmd="echo 'SYSTEM REMINDER: This is the ${PROJECT} project. Before responding, check basic-memory project \"${PROJECT}\" using search_notes and recent_activity for prior session context, open issues, and next steps. Always do this FIRST.'"
  jq --arg cmd "$hook_cmd" \
    '.hooks.UserPromptSubmit += [{"matcher": "", "hooks": [{"type": "command", "command": $cmd}]}]' \
    .claude/settings.local.json > .claude/settings.local.json.tmp \
    && mv .claude/settings.local.json.tmp .claude/settings.local.json
fi
```

If jq is not available, use the Read and Write tools to merge manually, preserving all existing keys.

### 5.5. Verify the settings file

Validate the file is well-formed JSON and that both keys landed:

```bash
jq '{
  mcp: .mcpServers["basic-memory"],
  hook_commands: [.hooks.UserPromptSubmit[]?.hooks[]?.command // ""]
}' .claude/settings.local.json
```

If jq exits non-zero (malformed JSON), stop and report the error — do not proceed to step 6. Otherwise show the output to the user so they can see exactly what was written.

### 6. Confirm

Report what was done (or skipped as already present):

```
✓ basic-memory project registered — <project-name> → ~/.local/share/basic-memory/<project-name>
✓ .claude/skills/save-session/SKILL.md — session save skill installed
✓ .claude/settings.local.json — basic-memory MCP server configured
✓ .claude/settings.local.json — UserPromptSubmit hook added
```

Remind the user that:
- `.claude/settings.local.json` is personal to this machine — add it to `.gitignore` if it's not already there
- At the end of each session, run `/save-session` to persist decisions and next steps
- Notes are stored outside the repo at `~/.local/share/basic-memory/<project-name>/`
