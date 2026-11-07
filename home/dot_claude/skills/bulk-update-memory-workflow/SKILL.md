---
name: bulk-update-memory-workflow
description: Propagate a setup-memory-workflow version bump across every project on this machine, not just the one currently open. Use when the canonical setup-memory-workflow templates have just been updated and other projects now need the same fix, or when the user says "update memory workflow everywhere", "sweep memory workflow across projects", "bulk update memory workflow version", "propagate the SMW version bump", "do the same check-drift sweep we did on the other Mac", or asks to repeat a prior cross-project memory-workflow update. Not for setting up or repairing a single project's memory workflow — that's setup-memory-workflow itself.
---

## Why this exists

`setup-memory-workflow` installs several pieces into a project (the `save-session` and
`save-session-maintenance` skills, a `SessionStart` reminder hook, a `PreToolUse`
write-guard hook, a crash-recovery hook, a `.mcp.json` entry), each tracked by a
`setup-memory-workflow-version:N` marker. The canonical version lives in this chezmoi repo
and renders to `~/.claude/skills/setup-memory-workflow/` — the same copy every project's
pieces are compared against. Bumping that canonical version (a new requirement, a bug fix
in `save-session`, etc.) only fixes the project you're actively working in unless you also
sweep every *other* project on the machine that has these pieces installed. Skipping the
sweep is how drift accumulates silently — one project discovered this session was still on
version 1, several years of versions behind canonical 16.

This has been done before as a full-machine sweep (most recently repeated on both a Mac
Studio and this Mac in the same week, 2026-11-07). This skill exists so the procedure
doesn't have to be reconstructed from scratch each time it needs repeating.

## Step 1 — Discover every candidate project, and run `check` only

```bash
~/.claude/skills/bulk-update-memory-workflow/scripts/sweep.sh check
```

This finds every project with `.claude/skills/save-session/` installed anywhere under
`$HOME` (filtering out Syncthing version-backup copies in `.stversions/` and macOS Trash
copies under `_Archived Items/` — both are false-positive matches, not real projects), then
runs `check-drift.sh check` in each one and prints its output under a `=== <path> ===`
header.

**Always run `check` before `update` — never skip straight to the bulk update.** `check` is
informational (it compares, it doesn't repair drifted pieces), and it's the only pass that
surfaces `NAME-MISMATCH` — a piece whose recorded project identity no longer matches the
project (e.g. a renamed directory). Trusting that nothing has drifted that way "because it
was always safe last time" is exactly the kind of assumption that lets a real mismatch slip
through silently.

## Step 2 — Read the `check` output before doing anything else

For every project in the output, look for these three outcomes:

- **`UP-TO-DATE`** — nothing to do.
- **`DRIFT (version X -> Y)`** or plain **`DRIFT`** — version-only staleness. Safe to repair
  unconditionally; no per-piece confirmation needed. (`CREATED` and `MIGRATED` lines are
  also expected and already-applied — `check` performs those directly since creating a
  missing piece, or migrating away a known-retired legacy piece, is always safe by design.)
- **`NAME-MISMATCH`** — **stop.** This means the installed piece's recorded project identity
  doesn't match what `check` resolved for that directory now (commonly: the project
  directory was renamed after initial setup, or a `.claude/basic-memory-project.txt`
  override file changed). Show the user the diff `check` printed for that specific piece and
  get their explicit, per-piece confirmation before running:
  ```bash
  cd "<that project>" && ~/.claude/skills/setup-memory-workflow/scripts/check-drift.sh apply <piece-name>
  ```
  Never include a `NAME-MISMATCH` project in the bulk-update loop below. `update` silently
  skips pieces reporting `NAME-MISMATCH` (it only repairs plain `DRIFT`), so the risk isn't
  that bulk update corrupts it — it's that skipping this review step means nobody ever
  notices and asks whether the mismatch is actually fine.

One more benign case: a project's `check` may abort partway with something like:
```
Error adding project: Project '<name>' already exists with different path.
Existing: /some/other/path, Requested: ~/.local/share/basic-memory/<name>
```
This means that project's basic-memory notes are intentionally registered at a
non-default path — not a bug to fix. `check`'s very first action is an unconditional
`basic-memory project add` call at the default path, under `set -euo pipefail`, so this
error aborts the rest of that project's `check` output. It's still safe to run `update`
for that project (see next step) — `update` never calls `basic-memory project add` at all.

## Step 3 — Once nothing needs special handling, run the bulk update

Either run it yourself:
```bash
~/.claude/skills/bulk-update-memory-workflow/scripts/sweep.sh update
```
or hand that exact command to the user to run and paste the output back — **this is the
preferred default**, since the user has specifically asked to run these commands
themselves (both on this machine and a second Mac) rather than have Claude execute them
directly. Ask, don't assume, which the user wants this time.

This re-runs the same discovery, but calls `check-drift.sh update` instead of `check`.
`update` unconditionally repairs every piece currently reporting plain `DRIFT` in each
discovered project, and is a no-op for anything already `UP-TO-DATE`. It does not touch
basic-memory project registration, so a project that hit the benign registration-abort
above is still safely included.

## Step 4 — Report a summary

After the bulk update finishes, summarize for the user:
- Which projects were already current (no action taken)
- Which projects were updated, and from what version to what (`version X -> 16`, etc.)
- Any project flagged in Step 2 for manual `NAME-MISMATCH` follow-up, and whether it was
  resolved or is still pending the user's decision
