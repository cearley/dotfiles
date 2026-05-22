# Implementation Tasks

**Status**: Pending implementation

---

## Phase 1: Core Script

### 1. Create emergency-sync.sh

- [ ] 1.1 Create `home/executable_bin/executable_emergency-sync.sh`
- [ ] 1.2 Add shebang, source shared-utils.sh, parse `--dry-run` and `--help` flags
- [ ] 1.3 Expand `REPO_DIRS` from chezmoi template data (default: `~/work`)
- [ ] 1.4 Find all `.git` dirs in `REPO_DIRS` using `find -name .git -prune`
- [ ] 1.5 Skip repos with no uncommitted changes (`git status --porcelain` is empty)
- [ ] 1.6 Check for configured remote before attempting push; skip with warning if none
- [ ] 1.7 For each dirty repo: stash → create emergency branch → pop stash → commit → push → return to original branch
- [ ] 1.8 Handle `git stash pop` failure gracefully (warn, don't abort)
- [ ] 1.9 Track successes and failures; continue on per-repo failure
- [ ] 1.10 Print summary at end (N synced, N skipped, N failed)
- [ ] 1.11 Exit non-zero if any repo failed
- [ ] 1.12 In `--dry-run` mode: report what would happen, skip all git write operations

---

## Phase 2: Configuration (if needed)

### 2. Optional chezmoi.toml addition

- [ ] 2.1 Confirm whether `~/work` covers all repos or if additional dirs are needed
- [ ] 2.2 If additional dirs needed: add `emergency_sync_dirs` array to `home/.chezmoi.toml.tmpl`

---

## Phase 3: Spec

### 3. Write business-continuity spec

- [ ] 3.1 Create `openspec/changes/add-business-continuity-system/specs/business-continuity/spec.md`
- [ ] 3.2 Requirement: emergency-sync discovers repos in configured directories
- [ ] 3.3 Requirement: emergency-sync creates isolated emergency branch and pushes
- [ ] 3.4 Requirement: emergency-sync skips repos with no changes
- [ ] 3.5 Requirement: emergency-sync reports per-repo success/failure
- [ ] 3.6 Requirement: emergency-sync supports `--dry-run`
- [ ] 3.7 Requirement: script is idempotent (safe to re-run)

---

## Phase 4: Testing

- [ ] 4.1 Run `emergency-sync --dry-run` — verify repo discovery output
- [ ] 4.2 Run against a real repo with uncommitted changes — verify emergency branch created and pushed
- [ ] 4.3 Run against a repo with no changes — verify it is skipped
- [ ] 4.4 Verify return to original branch after sync
- [ ] 4.5 Verify emergency branch exists on remote after sync
- [ ] 4.6 Manually clean up test emergency branches

---

## Phase 5: Deploy and Archive

- [ ] 5.1 Run `openspec validate add-business-continuity-system --strict`
- [ ] 5.2 Run `chezmoi apply` on Mac Studio
- [ ] 5.3 Run `chezmoi apply` on MacBook Pro
- [ ] 5.4 Run `emergency-sync --dry-run` on both machines to confirm setup
- [ ] 5.5 Run `openspec archive add-business-continuity-system`

---

**Total tasks**: ~22 across 5 phases

**Estimated complexity**: Low (one script, ~100 lines of bash)

**Dependencies**: git (existing), shared-utils.sh (existing)
