---
name: integrate-worktrees
description: >
  Safely integrate features developed in parallel Git worktrees into main. Use this skill
  whenever the user wants to merge multiple feature branches together, integrate parallel
  work, combine completed features before shipping, or says things like "integrate these
  features", "merge my worktrees", "combine feature branches", "bring parallel features
  together", or "I'm done with parallel development and want to merge". Also use when
  the parallel-worktrees skill has been used and the user is ready to consolidate work.
---

# Integrate Worktrees

Safely combine multiple feature branches developed in parallel, verify they work together,
then merge to main and clean up.

## Step 1: Identify Features to Integrate

If the user has listed specific feature names, use those. Otherwise, show them what's
available:

```bash
git branch --list "feature/*"
git worktree list
```

Confirm the list before proceeding — integrating the wrong branches is hard to undo cleanly.

## Step 2: Ensure Main Is Up to Date

Before creating the integration branch, sync with the remote to avoid surprises later:

```bash
git checkout main
git pull origin main
```

If `git pull` fails due to uncommitted changes or a detached HEAD, stop and resolve with
the user before continuing.

If there is no remote configured (e.g., a local-only repo), skip the pull and note it:
> No remote configured — skipping pull. Integration will be local-only until you add a remote.

## Step 3: Create the Integration Branch

Name the integration branch based on what's being merged. Use a timestamp or descriptive
name if multiple features are involved:

```bash
# Generic name (good when integrating a batch of features)
git checkout -b integration/parallel-features

# Or descriptive if the set has a clear theme
git checkout -b integration/auth-and-export
```

Base it on the latest `main` so the eventual merge-back is clean.

## Step 4: Merge Each Feature Branch

Merge features one at a time. This makes conflict resolution tractable — attempt each merge
and only stop if git reports a conflict:

```bash
git merge --no-ff feature/[feature-name] -m "Integrate feature/[feature-name]"
```

Use `--no-ff` to preserve each feature's history as a distinct unit in the log.

### When a conflict occurs

If git reports conflicts after a merge attempt, don't try to silently resolve them — surface
them clearly:

1. Run `git status` to list conflicted files
2. For each conflicted file, show the conflict markers and explain what each side changed
3. Propose a resolution strategy (keep one side, merge logic, etc.) and ask the user to confirm
4. After resolving: `git add <file>` then `git merge --continue`

If a conflict is complex (interleaved logic changes, renamed files, etc.), pause and walk
through it with the user rather than guessing.

## Step 5: Verify Features Work Together

After all merges succeed, run the project's test suite:

```bash
# Auto-detect test runner
[ -f package.json ] && (command -v bun &>/dev/null && bun test || npm test)
[ -f Cargo.toml ] && cargo test
[ -f pyproject.toml ] && (command -v uv &>/dev/null && uv run pytest || pytest)
[ -f go.mod ] && go test ./...
```

If tests fail:
- Show which tests failed and what error they produced
- Check whether the failure is integration-specific (features conflicting) or pre-existing
- Don't proceed to merge main until the integration branch is green

## Step 6: Merge to Main

Once tests pass on the integration branch:

```bash
git checkout main
git merge --no-ff integration/parallel-features -m "Merge integration/parallel-features into main"
git push origin main
```

Confirm with the user before pushing — this step affects the shared remote.

## Step 7: Clean Up

Remove branches and worktrees that are no longer needed:

```bash
# Delete integration branch (already merged)
git branch -d integration/parallel-features

# For each feature worktree and branch:
git worktree remove "../${project}-${feature}"
git branch -d feature/${feature}
git push origin --delete feature/${feature}   # if pushed to remote
```

List what will be deleted and ask the user to confirm before removing worktrees — they
may still want to reference that code.

## Merge Strategy Reference

| Scenario | Recommended approach |
|----------|---------------------|
| Features are independent (different files) | Merge in any order; conflicts unlikely |
| Features touch the same files | Merge the simpler one first; resolve conflicts in context of the second |
| One feature depends on the other | Merge the dependency first |
| Conflicts are extensive | Consider a short pairing session to understand intent before resolving |

## Notes

- The integration branch acts as a staging area — it's safe to experiment here before touching `main`
- `--no-ff` merges create a visible merge commit that makes the integration history auditable
- If integration reveals design conflicts between features, it's better to surface them now than after merging to main
- Worktree removal only works if the worktree has no uncommitted changes; check with `git -C ../project-feature status` first
