# Design

## Context

See proposal.md, "Why". Scripts 38 and 39 each loop `for_each_claude_env <callback> <dirs…>` and prefix every `claude` call inside the callback with `CLAUDE_CONFIG_DIR="$env_dir"`. The directory list is `claude_envs`, or `["~/.claude"]` when a machine declares none. Claude Code resolves `.claude.json` differently depending on whether the variable is *set* (to `$CLAUDE_CONFIG_DIR/.claude.json`) or *unset* (to `~/.claude.json`). `settings.json` and `plugins/` resolve to `~/.claude/` in both cases.

## Goals / Non-Goals

**Goals:**
- Every `claude` call in scripts 38 and 39 targets the config that sessions for that environment actually read.
- One place encodes the unset-for-default rule.

**Non-Goals:**
- Changing `for_each_claude_env` or the `claude_envs` default list.

## Decisions

### D1. A helper in `shared-utils.sh`, not inline conditionals
- `run_claude_in_env() { local env_dir="$1"; shift; if [[ "$env_dir" == "$HOME/.claude" ]]; then env -u CLAUDE_CONFIG_DIR claude "$@"; else CLAUDE_CONFIG_DIR="$env_dir" claude "$@"; fi; }`
- **Alternative: an `if` around each call site.** Rejected. There are five call sites across two scripts, and the rule would be duplicated at each one.
- **Alternative: change the default list to empty and branch on "no personas" at the top of each script.** Rejected. It duplicates the loop body for the no-persona case. The helper keeps `for_each_claude_env` usage unchanged.

### D2. Remove the variable with `env -u`; omitting it isn't enough
- `chezmoi apply` runs in the user's shell, which on persona machines exports `CLAUDE_CONFIG_DIR=~/.claude-<default>`. Leaving the prefix off for `~/.claude` would silently target that persona. `env -u` is available in macOS `/usr/bin/env`.
- The comparison uses the expanded path, `$HOME/.claude`, because `for_each_claude_env` has already expanded `~`.

### D3. The test drives the rendered script, not just the helper
- The failing test renders script 38 as a no-persona machine and runs it against a sandboxed `HOME`, with `CLAUDE_CONFIG_DIR` exported to a decoy to prove the helper removes it. Before the fix, `basic-memory` ends up in `$HOME/.claude/.claude.json` and not in `$HOME/.claude.json`. After the fix, it's the reverse.
- To render as a no-persona machine, a `scutil` shim reports an unmatched computer name. `.zsh_secrets` doesn't exist in the sandbox, so the script's `source` is skipped.

## Risks / Trade-offs

- **[Risk]** The next `chezmoi apply` re-runs scripts 38 and 39 on every `ai` machine, because their content changed. → Both are idempotent: 38 does remove and re-add, and 39's install is a no-op when already installed.
- **[Risk]** On affected machines, the stray `~/.claude/.claude.json` keeps stale registrations. → Harmless, since nothing reads it. It's listed as a manual cleanup step.

## Migration Plan

1. Apply on each machine. On a no-persona machine, script 38 now registers into `~/.claude.json`.
2. On affected machines, confirm `claude mcp list` (in a shell with the variable unset) shows `basic-memory`, then delete `~/.claude/.claude.json`.

Rollback is `git revert`.
