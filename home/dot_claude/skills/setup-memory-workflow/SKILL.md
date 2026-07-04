---
name: setup-memory-workflow
description: Set up, verify, or repair the basic-memory session workflow in the current project so Claude remembers context across sessions. Installs the save-session skill, configures the basic-memory MCP server, and adds a hook that primes Claude with prior session notes at every prompt. Safe to re-run any time — it self-heals by checking that basic-memory is still installed, the project is still registered, and the generated skill/config files haven't drifted from the current template. Use whenever the user says "set up memory", "add basic-memory", "configure save-session", "initialize memory workflow", "set up session notes", "check memory workflow health", "repair memory setup", "verify memory workflow is still working", or expresses frustration about losing context between sessions or about the memory setup seeming broken — even if they don't use those exact words.
---

This skill bootstraps *and* self-heals the basic-memory session workflow in the current project. Every step is safe to run repeatedly: on a fresh project it creates things from scratch; on an already-configured project it verifies each piece is still present, still correctly configured, and not drifted from what this skill would generate today — then repairs anything broken or out of date.

## How drift detection works

Two of the generated artifacts are free-text and carry an embedded version marker (a string containing `setup-memory-workflow-version:N`); the third is a small fixed JSON object that's cheaper to compare directly:

```
SMW_VERSION=1
```

Bump `SMW_VERSION` whenever you edit the canonical templates in step 4 or step 5b, so existing installs get flagged for review on their next run.

- **`save-session/SKILL.md`** — marker on the line right after the frontmatter. If the marker is current, leave the file alone even if the user has customized the body below it — that's their edit to keep, not drift.
- **The `UserPromptSubmit` hook command** — marker appended to the end of the reminder text. Same reasoning: an unchanged marker means "still the version this skill produced," regardless of other wording.
- **The `.mcp.json` basic-memory entry** — no marker; it's just `{"command": "uvx", "args": [...]}`, so compare it to the canonical value directly.

**Whenever something is drifted (marker missing/older, or the mcp entry doesn't match canonical), never silently overwrite it.** Show the user what's currently there vs. the canonical version and ask whether to update, leave as-is, or let them merge manually by hand. The user may have intentionally customized it (different Python version pin, reworded reminder, etc.).

## Steps

### 1. Verify basic-memory is installed

Run:
```bash
which basic-memory
```

If not found, tell the user to install it first (`uv tool install basic-memory`), then stop. This doubles as the health check for "basic-memory got uninstalled since setup" on a rerun.

### 2. Detect project name and create skill directory

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PROJECT=$(basename "$PROJECT_ROOT")
mkdir -p .claude/skills/save-session
```

`$PROJECT` and `$PROJECT_ROOT` are used in steps 3–5b — resolve them once here.

### 3. Register the basic-memory project

```bash
basic-memory project add "$PROJECT" "$HOME/.local/share/basic-memory/$PROJECT"
```

This is idempotent — if the project already exists it prints a notice and exits 0. It also self-heals the case where the project registration was lost (e.g. the basic-memory config was reset) even though the rest of the setup is intact. Notes are stored outside the repo in `~/.local/share/basic-memory/<project-name>/`, so they never clutter the working tree or git status.

### 4. Install or verify the save-session skill

If `.claude/skills/save-session/SKILL.md` does not exist, write it fresh from the canonical template below (substituting `$PROJECT` for `<project-name>`) and move on — nothing to check.

If it already exists, check whether it's current:

```bash
marker=$(grep -o 'setup-memory-workflow-version:[0-9]*' .claude/skills/save-session/SKILL.md | grep -o '[0-9]*$')
name_match=$(grep -qF "$PROJECT" .claude/skills/save-session/SKILL.md && echo yes || echo no)
```

- If `$marker` equals `SMW_VERSION` AND `$name_match` is `yes`: report "save-session skill is up to date" and move on — do not touch the file.
- If `$marker` is empty or less than `SMW_VERSION`: the file predates this check or the template has changed since it was written. Show the user a diff between the existing file and what the canonical template below would produce, and ask whether to overwrite, keep as-is, or let them merge manually. Only rewrite the file if they confirm.
- If `$marker` equals `SMW_VERSION` but `$name_match` is `no`: the template itself hasn't changed, but the file doesn't mention the current project name — likely the project directory was renamed after this was generated. Flag it separately ("this file still refers to a different project name — was this directory renamed?") and ask before regenerating with the current `$PROJECT`.

Canonical template (note the version marker on the line right after the frontmatter):

```markdown
---
name: save-session
description: Append today's decisions, findings, and next steps to the <project-name> basic-memory note. Run at end of every coding session.
---
<!-- setup-memory-workflow-version:1 -->

Search basic-memory project "<project-name>" for the most recent session note using search_notes with query "<project-name> session".

Append an update with edit_note (operation="append") including:
- Date (use the currentDate value from context)
- What was changed or decided today
- Any new open items or next steps discovered
- Any resolved items that can be checked off

Never overwrite the existing note — always append.
Confirm the note title and permalink after saving.
```

### 5a. Add or verify the basic-memory MCP server in `.mcp.json`

First check whether basic-memory is already registered globally — if so, this step is not applicable (managed elsewhere, nothing to drift-check here):

```bash
if claude mcp list 2>/dev/null | grep -q "basic-memory"; then
  echo "basic-memory already registered globally — skipping .mcp.json"
else
  [ -f .mcp.json ] || echo '{}' > .mcp.json
  current=$(jq -c '.mcpServers["basic-memory"] // empty' .mcp.json)
  canonical='{"command":"uvx","args":["--python","3.12","basic-memory","mcp"]}'
  if [ -z "$current" ]; then
    jq '.mcpServers["basic-memory"] = {"command": "uvx", "args": ["--python", "3.12", "basic-memory", "mcp"]}' \
      .mcp.json > .mcp.json.tmp && mv .mcp.json.tmp .mcp.json
    echo "added basic-memory entry"
  elif [ "$(echo "$current" | jq -S .)" = "$(echo "$canonical" | jq -S .)" ]; then
    echo "basic-memory mcp entry is up to date"
  else
    echo "DRIFT: existing basic-memory mcp entry differs from canonical:"
    echo "  current:   $current"
    echo "  canonical: $canonical"
  fi
fi
```

If drift is reported, show both values to the user and ask whether to update to canonical or leave as-is (they may have deliberately pinned a different Python version or args). Only change `.mcp.json` if they say yes.

Note: `.mcp.json` is the standard project-level MCP config file for Claude Code. Whether to commit it or add it to `.gitignore` is a team preference — the confirm step will remind you.

### 5b. Add or verify the UserPromptSubmit hook in `.claude/settings.local.json`

**Ensure the file exists first:**
```bash
[ -f .claude/settings.local.json ] || echo '{}' > .claude/settings.local.json
```

**Find any existing hook command mentioning basic-memory:**
```bash
existing_cmd=$(jq -r '[.hooks.UserPromptSubmit[]?.hooks[]?.command // empty] | map(select(contains("basic-memory")))[0] // empty' .claude/settings.local.json)
```

**Canonical command for this project** (`$PROJECT` and `$SMW_VERSION` substituted with their actual values):
```bash
canonical_cmd="echo 'SYSTEM REMINDER: This is the ${PROJECT} project. Before responding, check basic-memory project \"${PROJECT}\" using search_notes and recent_activity for prior session context, open issues, and next steps. Always do this FIRST. [setup-memory-workflow-version:${SMW_VERSION}]'"
```

- If `$existing_cmd` is empty, add the hook fresh with `$canonical_cmd`:
  ```bash
  jq --arg cmd "$canonical_cmd" \
    '.hooks.UserPromptSubmit += [{"matcher": "", "hooks": [{"type": "command", "command": $cmd}]}]' \
    .claude/settings.local.json > .claude/settings.local.json.tmp \
    && mv .claude/settings.local.json.tmp .claude/settings.local.json
  ```
- If `$existing_cmd` is non-empty, extract its version marker and check it still mentions the current project:
  ```bash
  marker=$(echo "$existing_cmd" | grep -o 'setup-memory-workflow-version:[0-9]*' | grep -o '[0-9]*$')
  name_match=$(echo "$existing_cmd" | grep -qF "$PROJECT" && echo yes || echo no)
  ```
  - If `$marker` equals `SMW_VERSION` AND `$name_match` is `yes`: report "hook is up to date" — leave it alone.
  - If `$marker` is empty or less than `SMW_VERSION`, or `$name_match` is `no` (the template changed, or the project directory was renamed so the hook still references the old name): show the existing command text vs. `$canonical_cmd`, and ask before replacing it. Only if the user confirms, update the matching hook's command in place (do not append a duplicate entry):
    ```bash
    jq --arg cmd "$canonical_cmd" '
      .hooks.UserPromptSubmit |= map(
        .hooks |= map(
          if (.command // "" | contains("basic-memory")) then .command = $cmd else . end
        )
      )
    ' .claude/settings.local.json > .claude/settings.local.json.tmp \
      && mv .claude/settings.local.json.tmp .claude/settings.local.json
    ```

If jq is not available, use the Read and Write tools to merge manually, preserving all existing keys.

### 5.5. Verify configuration

**Verify `.mcp.json`** (skip if global registration was detected in step 5a):
```bash
jq '{mcp: .mcpServers["basic-memory"]}' .mcp.json
```

**Verify hook in `.claude/settings.local.json`**:
```bash
jq '{hook_commands: [.hooks.UserPromptSubmit[]?.hooks[]?.command // ""]}' \
  .claude/settings.local.json
```

If either jq call exits non-zero (malformed JSON), stop and report the error — do not proceed to step 6. Otherwise show the output to the user, along with a summary of any drift found (and how it was resolved) in steps 4, 5a, and 5b.

### 6. Confirm

Report the status of each piece — one of: created, already up to date, drift found and repaired (user approved), or drift found and left as-is (user declined):

```
✓ basic-memory project registered — <project-name> → ~/.local/share/basic-memory/<project-name>
✓ .claude/skills/save-session/SKILL.md — <created | up to date | repaired (was vN) | left as-is (user declined update)>
✓ .mcp.json — <configured | already registered globally | up to date | repaired | left as-is>
✓ .claude/settings.local.json — <hook added | up to date | repaired (was vN) | left as-is>
```

Remind the user that:
- `.mcp.json` is the project-level MCP config — commit it if the whole team uses basic-memory, or add it to `.gitignore` if this is a personal setup
- `.claude/settings.local.json` is personal to this machine — add it to `.gitignore` if it's not already there
- At the end of each session, run `/save-session` to persist decisions and next steps
- Notes are stored outside the repo at `~/.local/share/basic-memory/<project-name>/`
- This skill is safe to re-run any time to check the setup is still healthy — nothing gets overwritten without asking first
