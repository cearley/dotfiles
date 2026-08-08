## 1. sync-memory.py: decouple cursor commit from log discovery

- [x] 1.1 Remove the unconditional `save_cursor()` call from default-mode's path
      through `main()`
- [x] 1.2 Add `mark_synced()`: loads the current cursor, refuses to move it backward,
      otherwise commits it
- [x] 1.3 Add `--mark-synced <mtime>` CLI flag wired to `mark_synced()`, handled early
      in `main()` before any log discovery
- [x] 1.4 `default_mode()` prints a final `--- CURSOR: <mtime> ---` line reporting the
      max `mtime` of the (possibly `--max-logs-per-run`-truncated) batch it just printed
- [x] 1.5 `--standalone` mode keeps committing its own cursor immediately after a
      successful `write_to_vault()` call — no `--mark-synced` involved

## 2. sync-memory.py: full-history first-run scan

- [x] 2.1 `find_unsynced_logs()`: when no cursor exists, drop the automatic `--since-days`
      fallback — return full history unless `--since-days` was explicitly passed
- [x] 2.2 `--since-days` default changed from `1` to `None`; remove the now-unused
      `DEFAULT_SINCE_DAYS` constant
- [x] 2.3 `python3 -m py_compile` on the edited script

## 3. Defensive project registration in both skills

- [x] 3.1 `sync-memory/SKILL.md` Step 0: call `ensure-project-registered.sh` instead of
      the bare `resolve-project-name.sh`
- [x] 3.2 `save-session/SKILL.md` Step 1: same swap; remove the now-inaccurate "already
      registered by SessionStart, nothing to do here" note
- [x] 3.3 Leave `sync-memory.py`'s own internal `resolve_project_name()` (used by
      `--standalone` / default vault-dir resolution) calling `resolve-project-name.sh`
      directly — see design.md Decisions for why

## 4. sync-memory skill: explicit project param + commit step

- [x] 4.1 Step 3: instruct passing `project="$PROJECT"` explicitly on every
      `search_notes`/`write_note`/`edit_note` call
- [x] 4.2 Step 3: instruct verifying the tool result's echoed `project:` before trusting
      a write, with a recovery path (`delete_note` + retry) on mismatch
- [x] 4.3 Add new Step 4: run `sync-memory.py --mark-synced <mtime>` using the value
      from Step 1's `--- CURSOR: ... ---` line, only after Step 3 is confirmed

## 5. Verification

- [x] 5.1 Scratch git repo: first run with an old (outside any 1-day window) log and a
      recent log, no `--since-days` — both found, cursor file not created
- [x] 5.2 Re-run default mode again before committing — same two logs still reported
      (nothing lost to an interrupted session)
- [x] 5.3 `--mark-synced <mtime>` commits the cursor; re-run reports "No unsynced logs
      found."
- [x] 5.4 `--mark-synced` with an `<mtime>` at or before the current cursor exits
      non-zero and leaves the state file untouched
- [x] 5.5 Regression: existing-cursor repeat sync with a newly added log still finds
      only the new log
- [x] 5.6 Explicit `--since-days` on a cursor-less repo still bounds the scan as before
- [x] 5.7 `--max-logs-per-run` capping: `--- CURSOR: ... ---` reflects only the
      processed (truncated) subset, not the full backlog
- [x] 5.8 `ensure-project-registered.sh` run directly in a scratch repo whose name was
      never previously registered — confirms registration happens without relying on
      `SessionStart`
- [x] 5.9 Scratch basic-memory project and directory cleaned up after verification

## 6. Spec sync and completion

- [x] 6.1 Draft proposal/specs/design/tasks for this change
- [ ] 6.2 `openspec validate sync-memory-cursor-reliability-fix --strict`
- [ ] 6.3 `openspec archive sync-memory-cursor-reliability-fix --yes` (merges the deltas
      into `openspec/specs/sync-memory/spec.md` and
      `openspec/specs/setup-memory-workflow/spec.md`)
- [ ] 6.4 Confirm with the user before committing (git workflow: explicit confirmation
      required per commit)
- [ ] 6.5 Confirm with the user before pushing (separate gate from commit)
