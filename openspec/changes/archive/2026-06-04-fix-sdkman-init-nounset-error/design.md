## Context

The 2026-06-03 `enforce-strict-mode-in-scripts` change added `set -euo pipefail` to `run_onchange_before_darwin-24-install-sdks.sh.tmpl`. That change's risk analysis noted: *"all scripts use template-time expansion…so shell variables are always defined before use."* This held for our own variables but did not account for third-party scripts sourced at runtime. `sdkman-init.sh` checks `$ZSH_VERSION` via `[[ -n "$ZSH_VERSION" ]]` to detect the shell; in bash, `ZSH_VERSION` is simply never set, which causes a fatal nounset error under `set -u`.

## Goals / Non-Goals

**Goals:**
- Restore `chezmoi apply` to a working state for `dev`-tagged machines.
- Document the approved pattern for sourcing third-party scripts that are not nounset-safe.
- Keep the strict-mode invariant intact for all of our own script logic.

**Non-Goals:**
- Modifying or forking `sdkman-init.sh`.
- Suppressing `-e` or `-o pipefail` — only `-u` is relaxed, and only for the duration of the source call.
- Applying this pattern preemptively to other scripts (apply only where a confirmed incompatibility exists).

## Decisions

**D1: `set +u` / source / `set -u` bracket — not `export ZSH_VERSION=""`**

Alternatives considered:
- `export ZSH_VERSION=""` — works but is semantically wrong: it injects a fake variable into the environment that could confuse any subsequent zsh-detection logic downstream.
- Wrap in a subshell `( source ... )` — isolates nounset exposure but `sdk` function definitions from `sdkman-init.sh` are needed in the parent shell to satisfy the `require_tools sdk` check; subshell export won't propagate functions.
- `set +u` / source / `set -u` — surgical: nounset is suspended only for the third-party source call; all our code before and after retains `-u`. This is the same class of explicit handling as the `_mcp_exit=0; cmd || _mcp_exit=$?` pattern established in D2 of the prior change.

**D2: Comment explains the WHY inline**

A one-line comment above `set +u` states that `sdkman-init.sh` references `$ZSH_VERSION` without a default. Future maintainers need to understand why the deviation exists before removing it.

**D3: Script-execution spec gains a new scenario, not a new requirement**

The Strict Error Mode requirement already covers the expected behavior. Adding a scenario for "Third-party sourced script is not nounset-safe" documents the approved exception pattern without weakening the rule.

## Risks / Trade-offs

- **[Risk] `-u` suspension window includes any code in sdkman-init.sh that silently swallows unset variables** → Mitigation: the window is a single `source` call; `set -u` is restored on the very next line. sdkman-init.sh is a mature, widely-used script with no history of silent variable bugs relevant to our use case.
- **[Risk] Future sdkman-init.sh versions add new unguarded variable references** → Mitigation: the bracket already covers all of sdkman-init.sh; no additional change needed if SDKMAN adds more such references.
- **[Risk] Copy-paste of this pattern without justification** → Mitigation: the inline comment and the spec scenario explicitly tie the pattern to a concrete rationale, making it harder to cargo-cult.
