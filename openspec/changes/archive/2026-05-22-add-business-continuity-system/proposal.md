# Change: Business Continuity — Emergency Repo Sync

## Why

When switching between machines (Mac Studio → MacBook Pro) or before a storm, uncommitted code changes are at risk of being stranded on the wrong machine.

**Current gaps:**
- No quick way to push all work-in-progress across all repos at once
- Manual per-repo git commits before switching is error-prone and slow
- Uncommitted changes get left behind when context-switching under pressure

**What this change provides:**
- One command (`emergency-sync`) that discovers all repos and pushes WIP to GitHub
- Safe isolation via emergency branches (no force-push, no history rewriting)
- `--dry-run` flag for testing and previewing

## What Changes

### One new script

**`emergency-sync`** — pushes all work-in-progress repos to GitHub

- Discovers git repos under `~/work` (configurable via `emergency_sync_dirs`)
- Skips repos with no uncommitted changes
- For each dirty repo:
  - Creates emergency branch: `${GITHUB_USERNAME}-dev/emergency/YYYY-MM-DD-HHMM`
  - Stages everything, commits with "WIP: Emergency sync from `<branch>` on `<hostname>`"
  - Pushes to GitHub
  - Returns to original branch
- Reports success/failure per repo
- Flags: `--dry-run`, `--help`

### Optional config

`home/.chezmoi.toml.tmpl` — add `emergency_sync_dirs` array (defaults to `["~/work"]`)

## Impact

- **Affected specs**: NEW `business-continuity`
- **New files**:
  - `home/executable_bin/executable_emergency-sync.sh`
- **Modified files**:
  - `home/.chezmoi.toml.tmpl` (optional — only if default `~/work` is insufficient)
- **Breaking changes**: None (purely additive)
- **Dependencies**: git (existing), fd (existing)

## Design Decisions

### Decision 1: Repository discovery via configurable directories
**Choice:** Scan all directories listed in `emergency_sync_dirs` (default: `["~/work"]`), recursively, using `fd`

`emergency_sync_dirs` is a list — multiple directories can be specified:
```toml
[data]
  emergency_sync_dirs = ["~/work", "~/personal/github"]
```

**Rationale:** Client work lives in `~/work`. Configurable via chezmoi data for machines with different layouts. `fd` handles recursive discovery cleanly, finds both standard repos (`.git` directory) and worktrees (`.git` file) without special-casing.

### Decision 2: Emergency branch strategy
**Choice:** Create a new branch per sync event, push without force

**Branch naming:** `${GITHUB_USERNAME}-dev/emergency/YYYY-MM-DD-HHMM`

**Rationale:** No force-push risk, no conflicts with collaborators, trivially safe. Emergency work is isolated and can be merged, cherry-picked, or deleted post-emergency.

**Post-sync cleanup (manual):**
```bash
git branch -D craig-dev/emergency/2026-05-22-1430
git push origin :craig-dev/emergency/2026-05-22-1430
```

## Files Modified

1. `openspec/changes/add-business-continuity-system/proposal.md` (this file)
2. `openspec/changes/add-business-continuity-system/design.md`
3. `openspec/changes/add-business-continuity-system/tasks.md`
4. `home/executable_bin/executable_emergency-sync.sh` (NEW)
5. `home/.chezmoi.toml.tmpl` (optional modification)

**Total: 2 implementation files (1 new, 1 possibly modified)**

## Deployment Status

**Status**: Pending implementation

**Next steps:**
1. Implement `emergency-sync.sh`
2. Test with `--dry-run` in `~/work`
3. Run live against a test repo
4. Run `chezmoi apply` to deploy
5. Archive change
