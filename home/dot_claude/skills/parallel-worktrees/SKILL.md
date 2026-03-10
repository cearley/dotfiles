---
name: parallel-worktrees
description: >
  Set up Git worktrees for parallel feature development so multiple features can be
  worked on simultaneously without branch-switching conflicts. Use this skill whenever
  the user wants to work on multiple features at once, mentions parallel development,
  asks to set up worktrees for several tasks, or says things like "develop X and Y in
  parallel", "set up worktrees for these features", "I want to work on multiple features
  at the same time", or provides a list of features/tasks to build concurrently. Also
  use proactively when the brainstorming skill produces multiple independent features
  that could be parallelized.
---

# Parallel Worktrees

Set up isolated Git worktrees so you can develop multiple features simultaneously without
switching branches or stashing work.

## Step 1: Identify Features

If the user has listed specific features to build, use those directly and proceed to Step 2.

If they've described work without clearly naming features, reason about how to divide it:

- Group related work into coherent, independently-shippable features
- Name each feature with a short kebab-case identifier (e.g., `auth`, `csv-export`, `dark-mode`)
- Aim for features that don't require each other to be complete first

Then confirm with the user before creating any worktrees. Keep it short:

> I'll set up worktrees for these features: **auth**, **csv-export**, **dark-mode**. Does that look right, or would you like to adjust the names?

## Step 2: Detect Project Name

```bash
project=$(basename "$(git rev-parse --show-toplevel)")
```

Use this as the prefix for all worktree directories.

## Step 3: Create Worktrees

For each feature, create a sibling worktree directory:

```bash
git worktree add "../${project}-${feature}" -b "feature/${feature}"
```

This places each worktree **outside** the main project directory to avoid any `.gitignore`
complications and keep the main workspace clean.

If a branch already exists for the feature, use `--track` or omit `-b` and pass the
existing branch name.

## Step 4: Set Up Development Environment

In each worktree, auto-detect and run the appropriate setup:

```bash
cd "../${project}-${feature}"

# Node.js / Bun
[ -f package.json ] && (command -v bun &>/dev/null && bun install || npm install)

# Rust
[ -f Cargo.toml ] && cargo build

# Python
[ -f requirements.txt ] && pip install -r requirements.txt
[ -f pyproject.toml ] && (command -v uv &>/dev/null && uv sync || poetry install)

# Go
[ -f go.mod ] && go mod download
```

Skip setup gracefully if the project type isn't recognized — just note it.

## Step 5: Confirm and Explain

Run `git worktree list` and show the output to the user.

Then summarize each worktree in plain language:

- What feature it's for
- Its full path
- What branch it's on
- What work will happen there
- How it's isolated (changes in one worktree don't affect others)

## Step 6: Workflow Tips

Remind the user of the common parallel workflow:

```
Main repo:           git pull / merge finished features
Worktree A:          cd ../project-feature-a   →  work on feature A
Worktree B:          cd ../project-feature-b   →  work on feature B

When feature is done:
  cd ../project-feature-a
  git push -u origin feature/feature-a
  # open PR, merge
  cd /path/to/main-repo
  git worktree remove ../project-feature-a
```

## Common Issues

| Situation | Resolution |
|-----------|------------|
| Branch already exists | Use existing branch: `git worktree add ../project-feat feature/feat` |
| Worktree path already exists | Check `git worktree list` — may already be set up |
| Uncommitted changes in main | Stash or commit first; worktrees share the index |
| Feature names conflict | Use more descriptive names (e.g., `user-auth` not just `auth`) |

## Notes

- Worktrees share the same `.git` directory — commits, tags, and remotes are visible everywhere
- Each worktree has its own working tree and can be on a different branch simultaneously
- To clean up when done: `git worktree remove ../project-feature && git branch -d feature/feature`
