# Design: Emergency Repo Sync

## Context

Uncommitted code changes can get stranded on the wrong machine when switching between workstations, or be lost before a power event. The script is run manually and proactively — before switching machines or before an anticipated outage — while internet is still available.

**Constraints:**
- Must not require per-repo manual work — one command covers everything
- Must be safe to re-run (idempotent)
- Must not corrupt git history or conflict with collaborators
- Fast enough to run before leaving the desk

**Use cases:**
- Before switching to a secondary machine
- Before a storm or anticipated power event
- Any time you want a remote checkpoint of all WIP

## Goals / Non-Goals

**Goals:**
- Single command pushes all dirty repos to GitHub
- Safe branch isolation (no force-push)
- Testable via `--dry-run`
- Configurable repo directories
- Clear per-repo success/failure reporting

**Non-Goals:**
- UPS/PowerPanel integration (generator makes this unnecessary)
- Automated triggering (manual invocation is sufficient)
- SSH propagation to other machines (run directly on each machine as needed)
- Machine-switch workflow documentation (separate concern)
- Windows or Linux support

## Decisions

### Decision 1: Repository Discovery

**Choice:** Scan directories from `emergency_sync_dirs` config (default: `~/work`)

**Rationale:**
- Client work lives in `~/work` — scanning it covers the common case
- Configurable via chezmoi template data for machines with different layouts
- Git worktrees are discovered naturally (`fd` finds both `.git` directories and `.git` files)

**Configuration:**
```toml
# .chezmoi.toml.tmpl — only needed if ~/work is insufficient
[data]
  emergency_sync_dirs = ["~/work", "~/personal/github"]
```

**Template expansion:**
```bash
{{- if .emergency_sync_dirs }}
REPO_DIRS=({{- range .emergency_sync_dirs }} "{{ . }}"{{- end }})
{{- else }}
REPO_DIRS=("$HOME/work")
{{- end }}
```

**Discovery tool: `fd`**

Use `fd` instead of `find` for repository discovery.

```bash
for repo_dir in "${REPO_DIRS[@]}"; do
    expanded_dir="${repo_dir/#\~/$HOME}"
    fd --hidden --glob '.git' "$expanded_dir" | while read git_entry; do
        repo_path="$(dirname "$git_entry")"
        # Process repository...
    done
done
```

`fd` is preferred because:
- Cleaner syntax — `--hidden --glob '.git'` vs `find -name .git -prune`
- Handles both `.git` directories (standard repos) and `.git` files (worktrees) without special-casing
- Already available in this dotfiles environment

**Recursive scanning**

`fd` scans recursively by default with no depth limit. This means repos nested at any depth under a search directory are discovered — useful for structures like `~/work/client-a/project-foo/` where the repo root is not directly under `~/work`.

**Alternatives considered:**
- **`find` with `-prune`**: Verbose, requires `-type d` flag which misses worktree `.git` files. Rejected in favour of `fd`.
- **Scan entire home**: Too slow and noisy
- **Command-line arguments**: Requires remembering paths; defeats one-command goal
- **Hardcoded paths**: Breaks on machines with different layouts

### Decision 2: Emergency Branch Strategy

**Choice:** Create a new branch per sync, push without force

**Branch naming:** `${GITHUB_USERNAME}-dev/emergency/YYYY-MM-DD-HHMM`
**Commit message:** `WIP: Emergency sync from <branch> on <hostname> - <datetime>`

**Rationale:**
- Zero force-push risk — new branch can never conflict with anything
- Collaborator-safe — doesn't touch any existing branch
- Easy post-emergency cleanup: delete branch once merged/discarded
- Works naturally with git worktrees — each worktree gets its own emergency branch
- Timestamp in branch name shows when the sync occurred

**Workflow per repo:**
```bash
current_branch=$(git branch --show-current || echo "HEAD")
emergency_branch="${GITHUB_USERNAME}-dev/emergency/$(date +%Y-%m-%d-%H%M)"

git stash --include-untracked --message "Emergency stash $(date)"
git checkout -b "$emergency_branch"
git stash pop 2>/dev/null || true
git add -A
git commit -m "WIP: Emergency sync from $current_branch on $(hostname) - $(date '+%Y-%m-%d %H:%M:%S')"
git push -u origin "$emergency_branch"
git checkout "$current_branch" 2>/dev/null || git checkout -
```

**Post-emergency cleanup:**
```bash
git branch -D craig-dev/emergency/2026-05-22-1430
git push origin :craig-dev/emergency/2026-05-22-1430
```

**Alternatives considered:**
- `--force-with-lease`: Still a force-push, can fail if remote diverged. Rejected.
- Direct commit to current branch: Pollutes main branch history. Rejected.
- Stash only (no commit): Not pushed to GitHub, doesn't survive machine loss. Rejected.

### Decision 3: Script Location

**Choice:** `home/executable_bin/executable_emergency-sync.sh` → `$HOME/bin/emergency-sync`

**Rationale:**
- `$HOME/bin` is already in PATH via `.zshrc`
- chezmoi `executable_` prefix sets execute permissions automatically
- Accessible by any process, not zsh-specific (matters for potential future automation)
- Consistent with other user scripts in this dotfiles repo

## Risks

### Emergency branch accumulation
Branches pile up if not cleaned after each use.
**Mitigation:** Branch naming is consistent — easy to list and bulk-delete. The risk is cosmetic only; branches don't affect development work.

### Stash conflicts on return
If the original branch has changed between stash and return, `git stash pop` may conflict.
**Mitigation:** Script should handle stash pop failure gracefully (warn, don't abort). The emergency commit is already safe on the remote branch.

### Repo has no remote
Push fails on repos without a configured remote.
**Mitigation:** Check for remote before attempting push; report clearly and continue with other repos.
