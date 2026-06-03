## Context

The affected scripts span two tag groups (`core` package management and `ai` Claude tooling) and three current states: no error mode, partial `-uo pipefail`, and partial `-e`. All are `run_onchange_` scripts that chezmoi re-runs on content change. Making them fail-fast ensures that a broken tool install or failed service restart surfaces immediately rather than silently corrupting environment state.

Script 38 (`install-claude-mcp-servers`) is the only one requiring a companion code change beyond adding the flag line. It captures MCP server registration output via `_mcp_output=$(claude mcp add ... 2>&1)` and immediately reads `$?` into `_mcp_exit`. Under `set -e`, a non-zero exit from the command substitution terminates the script before `$?` is read — breaking the intentional error-handling logic that decides whether to retry, warn, or skip.

## Goals / Non-Goals

**Goals:**
- Uniform `set -euo pipefail` across all 9 affected `run_onchange_` scripts
- Fix script 38's exit-code capture to be `-e` compatible

**Non-Goals:**
- `run_once_` scripts (different risk profile — one-shot, often interactive)
- Syncthing `output` fragility fix (separate concern)
- `echo` vs `print_message` cleanup

## Decisions

**D1: Always use the full `set -euo pipefail` triple, never partial**

Scripts with `set -uo pipefail` get `-e` added; scripts with `set -e` get `uo pipefail` added; scripts with nothing get the full line. Using a consistent single form eliminates future confusion about which flags are active in which script.

**D2: Fix script 38 with `_mcp_exit=0; _mcp_output=$(…) || _mcp_exit=$?`**

This is the standard bash idiom for capturing a command's output and exit status together under `set -e`. Initializing `_mcp_exit=0` before the substitution means an unexecuted path always has a defined value; `|| _mcp_exit=$?` captures a non-zero exit without being a simple command that triggers exit. This applies to both `_mcp_output=$(…)` occurrences in `_register_mcp_for_env()` (lines 92 and 99 after the last refactor).

Alternative considered: `{ _mcp_output=$(…); } || _mcp_exit=$?` — equivalent but less clear that `_mcp_exit` should start at 0.

**D3: Place `set -euo pipefail` immediately after `#!/bin/bash`, before any sourcing**

This is the established position in all scripts that already have the line (e.g., scripts 23, 27, 37, 40). Consistent placement makes it easy to audit with grep.

## Risks / Trade-offs

- **[Risk] Existing `|| true` patterns become load-bearing**: If any affected script has a command that was silently failing and relying on execution continuing, adding `-e` will now surface that failure. → Mitigation: audited all 9 scripts; none have bare commands that are expected to fail silently. All existing failure paths use `if !`, `|| true`, or explicit `exit`.
- **[Risk] `-u` catches unset variable bugs**: Any template variable that expands to an unset shell variable will now error. → Mitigation: all scripts use template-time expansion (chezmoi renders values before the shell runs them), so shell variables are always defined before use.
- **[Risk] Script 38 second `_mcp_output=` call (the retry path)**: Same pattern on line 99 needs the same fix. → Both occurrences are fixed together in the same task.
