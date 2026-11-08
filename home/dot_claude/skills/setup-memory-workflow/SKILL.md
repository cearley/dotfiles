---
name: setup-memory-workflow
description: Set up, verify, or repair the basic-memory session workflow in the current project so Claude remembers context across sessions. Installs the save-session and save-session-maintenance skills, configures the basic-memory MCP server, and adds a SessionStart reminder to read prior context. Safe to re-run any time — it self-heals by checking that basic-memory is still installed, the project is still registered, and the generated skill/config files haven't drifted from the current template. Use whenever the user says "set up memory", "add basic-memory", "configure save-session", "initialize memory workflow", "set up session notes", "check memory workflow health", "repair memory setup", "verify memory workflow is still working", or expresses frustration about losing context between sessions or about the memory setup seeming broken — even if they don't use those exact words.
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
  project, and creating the save-session and save-session-maintenance skills / `.mcp.json`
  entry / SessionStart reminder / PreToolUse write-guard hook **only when each is entirely
  missing** — there's nothing to lose by creating something that doesn't exist yet.
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
~/.claude/skills/setup-memory-workflow/scripts/check-drift.sh apply save-session-maintenance-skill
~/.claude/skills/setup-memory-workflow/scripts/check-drift.sh apply mcp-config
~/.claude/skills/setup-memory-workflow/scripts/check-drift.sh apply hook-config
~/.claude/skills/setup-memory-workflow/scripts/check-drift.sh apply write-guard-hook
```

## Step 3: Confirm

Report the status of each piece — one of: created, already up to date, drift found and
repaired (user approved), or drift found and left as-is (user declined):

```
✓ basic-memory project registered — <project-name> → ~/.local/share/basic-memory/<project-name>
✓ .claude/skills/save-session/SKILL.md — <created | up to date | repaired (was vN) | left as-is (user declined update)>
✓ .claude/skills/save-session-maintenance/SKILL.md — <created | up to date | repaired (was vN) | left as-is (user declined update)>
✓ .mcp.json — <configured | already registered globally | up to date | repaired | left as-is>
✓ .claude/settings.local.json — <SessionStart reminder added | up to date | repaired (was vN) | left as-is>
✓ .claude/settings.local.json (write-guard hook) — <created | up to date | repaired | left as-is>
```

Remind the user that:
- `.mcp.json` is the project-level MCP config — commit it if the whole team uses
  basic-memory, or add it to `.gitignore` if this is a personal setup
- `.claude/settings.local.json` is personal to this machine — add it to `.gitignore` if
  it's not already there
- `/save-session` may run proactively when a session produces decision-worthy content; explicit
  invocation remains appropriate at a session boundary. `/save-session-maintenance` is manual-only
  and handles size/triage work separately.
- The SessionStart hook is an instruction to call `search_notes` and `recent_activity` before
  responding. It does not itself invoke basic-memory; Basic Memory must be available through MCP
  and the model must follow the reminder.
- The PreToolUse write-guard hook denies any Bash/Edit/Write call that would write directly into
  `~/.local/share/basic-memory/` (any project, not just this one) — those files are indexed by
  the basic-memory MCP server, and a direct filesystem write bypasses that index and can corrupt
  `bm_edit`'s checksum-based concurrency guard. It points the model at `bm_write`/`bm_edit`
  instead. The guard script itself is global (deployed once by chezmoi, not per-project); only
  the hook *entry* pointing at it lives in this project's `.claude/settings.local.json`.
- Notes are stored outside the repo at `~/.local/share/basic-memory/<project-name>/`
- This skill is safe to re-run any time to check the setup is still healthy — nothing gets
  overwritten without asking first

## Updating the canonical templates

The canonical save-session and save-session-maintenance skill bodies live in
`assets/save-session-skill.md.template` and `assets/save-session-maintenance-skill.md.template`.
Rendered pieces use `__PROJECT__` and `__SMW_VERSION__` placeholders only, substituted via
bash-native `${content//pattern/replacement}` expansion inside `render()` in
`scripts/lib-pieces.sh` (sourced by `check-drift.sh`, not defined in it); `apply_templated_file()`
calls `render()` and writes the result to disk when repairing drift.
Whenever you edit a canonical rendered asset, bump the `SMW_VERSION` constant at
the top of `scripts/executable_check-drift.sh` so existing installs get flagged as drifted on
their next check.

`check-drift.sh` is a thin orchestrator: it sources `scripts/lib-project.sh`
(`resolve_project()`), `scripts/lib-pieces.sh` (the generic templated-file engine above, plus a
generic hook-command engine — `hook_piece_status`/`hook_piece_apply`, parameterized by settings
file / event / matcher / match-substring / canonical command — shared by the SessionStart
reminder, PreToolUse write-guard, and crash-recovery hook pieces alike; none of them has its own
dedicated `canonical_*_cmd()` function any more), and `scripts/migrations.sh` (mutates only this
skill's own prior-version artifacts, run unconditionally on every invocation to clean up
leftovers from an older install — e.g. `migrate_hook_config`/`migrate_sync_memory`/
`migrate_legacy_reminder_hook`).

The SessionStart reminder message is **not** rendered from a template at all: it's a literal
string inside `scripts/executable_session-reminder.sh` itself — a fourth static, non-templated,
machine-wide script (like the write-guard and crash-recovery hooks), deployed once and never
per-project-rendered. Only the fixed hook *entry* pointing at its global path is tracked per
project, via the same `hook_piece_status`/`hook_piece_apply` engine and literal command-string
comparison — so editing the reminder's wording needs no `SMW_VERSION` bump. `session-reminder.sh`
sources its own two helper libraries, never sourced by `check-drift.sh`: `scripts/lib-status-note.sh`
(resolves the current-status note's on-disk path — canonical `status/<project>-current-status.md`
first, a broader fallback glob second — and extracts a bounded `## Open` excerpt, read live at
every session start, never baked into any rendered file) and `scripts/lib-session-log.sh`
(resolves the active session-log note by mtime and checks its rollover threshold). Both degrade
to empty/no-op on any missing file/section/read failure and never create, write, or delete
anything — `session-reminder.sh` is read-only by construction.

The PreToolUse write-guard and crash-recovery hooks are two more pieces that are *not*
`__PROJECT__`-templated: `scripts/executable_basic-memory-write-guard.sh` and
`scripts/executable_crash-recovery-hook.sh` are plain static scripts, deployed machine-wide by
chezmoi exactly like `check-drift.sh` itself (not rendered per project). Only the hook *entry*
pointing at each fixed global path is managed per project, via the generic hook-command engine
and literal command-string comparison — there is no version marker for either, so editing a
guard script's content doesn't need an `SMW_VERSION` bump; only changing a hook entry's command
string (e.g. the global path itself) would.

If you add a self-referential check inside a canonical template (e.g. "fail if this looks
un-rendered"), don't compare literally against the placeholder string itself — `render()`'s
substitution is a blind global replace and will rewrite that literal occurrence too, silently
inverting the check. Use a pattern check instead (e.g. checking whether a resolved value still
starts with `__`, rather than matching the literal placeholder text).
