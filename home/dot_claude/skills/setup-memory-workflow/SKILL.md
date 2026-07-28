---
name: setup-memory-workflow
description: Set up, verify, or repair the basic-memory session workflow in the current project so Claude remembers context across sessions. Installs the save-session skill, configures the basic-memory MCP server, and adds a hook that primes Claude with prior session notes at every prompt. Safe to re-run any time — it self-heals by checking that basic-memory is still installed, the project is still registered, and the generated skill/config files haven't drifted from the current template. Use whenever the user says "set up memory", "add basic-memory", "configure save-session", "initialize memory workflow", "set up session notes", "check memory workflow health", "repair memory setup", "verify memory workflow is still working", or expresses frustration about losing context between sessions or about the memory setup seeming broken — even if they don't use those exact words.
---

This skill bootstraps *and* self-heals the basic-memory session workflow in the current
project. All of the mechanical work — marker parsing, JSON comparisons, idempotent
creates — lives in `scripts/check-drift.sh`, a fixed, repeatable operation with no
judgment involved. This file covers the two things that genuinely need judgment: deciding
whether basic-memory should be installed, and deciding whether to overwrite something that
has drifted from canonical.

## Step 1: Run the check

```bash
~/.claude/skills/setup-memory-workflow/scripts/check-drift.sh check
```

Run this from anywhere inside the target project — it resolves the project root itself via
`git rev-parse --show-toplevel`.

The script:
- Stops immediately if `basic-memory` isn't installed (tell the user to run
  `uv tool install basic-memory` first, then stop — nothing else can proceed without it).
- Always performs the safe, idempotent pieces directly: registering the basic-memory
  project, and creating the save-session skill / `.mcp.json` entry / hook **only when
  each is entirely missing** — there's nothing to lose by creating something that doesn't
  exist yet.
- Reports `UP-TO-DATE` for anything that already matches canonical — leave those alone.
- Reports `DRIFT` (with current vs. canonical shown side by side) for anything that
  exists but differs — **never overwrites these itself.**
- Reports `NAME-MISMATCH` if the save-session skill or hook still reference a different
  project name (the directory may have been renamed after initial setup).

## Step 2: Handle anything reported as DRIFT or NAME-MISMATCH

For each such item, show the user the current vs. canonical values from the script output
and ask whether to update, leave as-is, or merge manually by hand. The user may have
intentionally customized it (a different Python version pin, a reworded reminder) — never
silently overwrite.

If the user confirms an update, apply it with:

```bash
~/.claude/skills/setup-memory-workflow/scripts/check-drift.sh apply save-session-skill
~/.claude/skills/setup-memory-workflow/scripts/check-drift.sh apply mcp-config
~/.claude/skills/setup-memory-workflow/scripts/check-drift.sh apply hook-config
```

## Step 3: Confirm

Report the status of each piece — one of: created, already up to date, drift found and
repaired (user approved), or drift found and left as-is (user declined):

```
✓ basic-memory project registered — <project-name> → ~/.local/share/basic-memory/<project-name>
✓ .claude/skills/save-session/SKILL.md — <created | up to date | repaired (was vN) | left as-is (user declined update)>
✓ .mcp.json — <configured | already registered globally | up to date | repaired | left as-is>
✓ .claude/settings.local.json — <hook added | up to date | repaired (was vN) | left as-is>
```

Remind the user that:
- `.mcp.json` is the project-level MCP config — commit it if the whole team uses
  basic-memory, or add it to `.gitignore` if this is a personal setup
- `.claude/settings.local.json` is personal to this machine — add it to `.gitignore` if
  it's not already there
- At the end of each session, run `/save-session` to persist decisions and next steps
- Notes are stored outside the repo at `~/.local/share/basic-memory/<project-name>/`
- This skill is safe to re-run any time to check the setup is still healthy — nothing gets
  overwritten without asking first

## Updating the canonical templates

The canonical save-session skill body lives in `assets/save-session-skill.md.template`; the
canonical hook message lives in `assets/hook-message.txt.template`. Both use `__PROJECT__`
and `__SMW_VERSION__` placeholders that the script substitutes at render time. Whenever you
edit either template, bump the `SMW_VERSION` constant at the top of
`scripts/check-drift.sh` so existing installs get flagged as drifted on their next check.
