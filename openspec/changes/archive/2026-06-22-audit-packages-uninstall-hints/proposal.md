## Why

When `audit-packages` finds orphans, the user must manually construct the correct uninstall command for each package manager before they can act on the report. Adding ready-to-use uninstall commands directly to the output removes that friction and makes the audit immediately actionable.

## What Changes

- `home/scripts/audit-packages.sh` gains a new `print_uninstall_hint` helper function
- Each manager section that finds orphans appends a suggested uninstall command (or one command per orphan for managers where multi-arg uninstall is not standard)
- Uninstall hints are emitted to stderr via the same channel as other formatted messages, preserving stdout pipe-friendliness for the orphan list itself
- Managers that join all orphans onto one command (`one_line` mode): Homebrew formulae, Homebrew casks, UV tools, Bun global packages, Cargo crates
- Managers that emit one command per orphan (`per_line` mode): Homebrew taps, SDKMAN candidates, Claude Code plugins, Claude Code plugin marketplaces, Claude Code MCP servers, Claude Code skills
- No flags or configuration are added; hints always appear when orphans are found

## Capabilities

### New Capabilities

_(none — this is a pure enhancement to the existing package-audit capability)_

### Modified Capabilities

- `package-audit`: Adding a new requirement — **Uninstall Hint Output** — that specifies when and how the audit prints suggested removal commands after each orphan list.

## Impact

- `home/scripts/audit-packages.sh` — implementation changes only; no interface or schema changes
- `openspec/specs/package-audit/spec.md` — new requirement section added
- No changes to `packages.yaml`, chezmoi templates, or any other scripts
- Affects all tags that run the audit (all tags — the script is always available)
- No security implications; the script remains strictly read-only and never executes the suggested commands

## Non-goals

- Auto-remediation (running the uninstall commands automatically)
- A `--fix` or `--prune` flag that acts on orphans
- Hints for managers not already covered by the audit
