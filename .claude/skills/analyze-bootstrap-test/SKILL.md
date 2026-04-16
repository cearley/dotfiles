---
name: analyze-bootstrap-test
description: >
  Analyze terminal output from a macOS VM bootstrap test to identify failure modes and propose fixes.
  Invoke whenever the user shares terminal output from running the dotfiles bootstrap/install command
  on a fresh VM or machine, mentions that a bootstrap test failed or didn't complete, or says
  something like "I tested the install script" or "here's what happened on the VM".
  Also invoke proactively when the user asks for help debugging setup script failures even without
  explicitly pasting output yet — prompt them to share the output and then run this workflow.
---

# Analyze Bootstrap VM Test

A structured workflow for analyzing terminal output from fresh macOS VM bootstrap tests.
The goal: trace every failure to its root cause in the source files, then propose concrete fixes.

## Step 1 — Read Source Files First

**Before touching the terminal output**, read the bootstrap entry points so you can cross-reference errors against the actual code:

- `README.md` — the exact command the user ran and its documented prerequisites
- `remote_install.sh` — bootstrap script logic (Homebrew/chezmoi detection, exec)
- Relevant `home/.chezmoiscripts/` files (read specific scripts when the output points to one)

This is the most important step. Without the source, you can only describe symptoms — with it, you can explain root causes.

## Step 2 — Parse Distinct Attempts

Users often run the command multiple times before asking for help. Separate the output into individual attempts by looking for:
- Shell prompt reappearance (`% ` or `$ `)
- "Last login:" lines (new terminal session)
- The command being invoked again

For each attempt, note what changed (different flag, different username, same command re-run) and whether it reached a different failure point.

## Step 3 — Categorize Each Failure

For each distinct failure, assign one of these categories:

| Category | Typical examples |
|---|---|
| **Documentation/UX** | Placeholder text run literally, missing prerequisite note |
| **Environment/PATH** | Tool not in PATH in non-login subshell, wrong shell type |
| **Dependency/Version** | Wrong bash/python version, missing prerequisite tool |
| **Authentication** | HTTPS clone prompts on a repo requiring auth, deprecated credential method |
| **Script Logic** | Wrong condition, unhandled edge case, bad assumption about state |

## Step 4 — Trace to Root Cause

For each failure, answer:
- **What line/condition** in the source triggered it?
- **What assumption** was violated? (PATH inherited? Tool version? Auth method?)
- **First-run or repeated-run?** Some issues only appear the first time; others on every re-run.
- **Independent or cascading?** Does this failure only appear because a prior one wasn't handled?

### macOS Baseline Gotchas (check these first)

- **`sh -c "$(curl ...)"` is a non-login, non-interactive subprocess** — it does NOT source `~/.zprofile`, `~/.bashrc`, or any user profile. Changes the script writes to `~/.zprofile` take effect only in future shells, not the current `sh -c` invocation.
- **`command -v <tool>`** checks the current PATH. If a tool was installed by a prior step in the same script but PATH wasn't updated, this check fails — even though the binary exists at its absolute path.
- **macOS ships Bash 3.2** (GPL licensing restriction). Tools that require Bash 4+ (SDKMAN, some CI scripts) will hard-exit on a stock machine.
- **HTTPS GitHub clone** prompts for credentials; GitHub dropped password auth in 2021. Public repos clone without auth; private repos need a token or SSH.
- **Xcode CLT stubs** (`/usr/bin/git`, `/usr/bin/clang`) exist on every macOS install but may trigger a GUI install dialog on first run rather than working silently.
- **Script execution ordering** in chezmoi (positions 20–29 = package management) means a tool installed at position 23 is NOT available to a script at position 20.

## Step 5 — Propose Fixes

For each root cause, write a fix proposal in this format:

```
**Issue**: <one-line title>
**Category**: <category from Step 3>
**Root cause**: <why it happens, in 1-2 sentences>
**Affected file**: <filename:line or just filename>
**Fix**: <concrete change — be specific about what to edit>
**Alternatives considered**: <what else was evaluated and why rejected>
**Impact**: tags affected, breaking/non-breaking, idempotent after fix?>
```

Prefer fixes that are:
- **Idempotent** — safe to run multiple times without side effects
- **Self-contained** — don't require reordering other scripts or cascading changes
- **Absolute-path-safe** — don't rely on PATH being set in a subshell

## Step 6 — Output and Next Steps

Present findings grouped as:
1. **Blockers** — prevent bootstrap from completing successfully
2. **Friction points** — degrade experience but have workarounds
3. **Observations** — informational; not immediately actionable

End with a concrete recommendation:
- Multiple changes needed across files → suggest `/opsx:propose` to create an OpenSpec change
- Single-file quick fix → offer to implement directly
- Unclear scope → suggest filing a beads issue for discussion before investing in a fix

## Example Output Structure

```
## Bootstrap Test Analysis

### Context
- Attempts: 3 (2 failed, 1 partial success)
- Platform: macOS 15 (Sequoia), ARM64
- Command: sh -c "$(curl ...)" -- init --apply <username>

### Findings

#### [BLOCKER] SDKMAN installer exits on macOS Bash 3.2
**Category**: Dependency/Version
**Root cause**: `curl ... | bash` pipes to /bin/bash which is Bash 3.2. SDKMAN's
  installer hard-exits when it detects Bash < 4.
**Affected file**: home/.chezmoiscripts/run_once_before_darwin-20-install-sdkman.sh.tmpl:25
**Fix**: Install Homebrew's `bash` inline before the curl, then pipe to
  `/opt/homebrew/bin/bash`
**Alternatives**: Move SDKMAN to position 24 (after Homebrew packages install bash) —
  rejected because it requires renumbering and the inline install is self-contained.

#### [FRICTION] README placeholder text ran literally
...

### Summary
2 blockers, 1 friction point.
Recommended next step: `/opsx:propose` — changes span README, remote_install.sh,
and a chezmoi script, making a tracked change request worthwhile.
```
