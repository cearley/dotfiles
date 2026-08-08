## 1. Verify spec delta matches shipped implementation

- [ ] 1.1 Confirm `plugins/basic-memory-workflow/scripts/ensure-project-registered.sh` behavior matches the "basic-memory project registration" requirement's scenarios: resolves `$PROJECT` via `resolve-project-name.sh`, runs idempotent `basic-memory project add`, and exits non-zero silently when `basic-memory` isn't installed or the repo isn't a git repo
- [ ] 1.2 Confirm `plugins/basic-memory-workflow/scripts/session-start-reminder.sh` calls `ensure-project-registered.sh` (not `resolve-project-name.sh` directly), per the updated requirement
- [ ] 1.3 Confirm `plugins/basic-memory-workflow/skills/save-session/SKILL.md` Step 1 no longer performs registration itself, only the `which basic-memory` install check
- [ ] 1.4 Confirm `plugins/basic-memory-workflow/skills/sync-memory/SKILL.md` Step 0 is unchanged — still calls `resolve-project-name.sh` directly for pure resolution

## 2. Validate the change

- [ ] 2.1 Run `openspec validate --strict` against this change and fix any structural issues
