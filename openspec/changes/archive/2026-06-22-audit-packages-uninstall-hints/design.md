## Context

`audit-packages` is a read-only script that lists installed-but-undeclared packages across eight managers. Before this change, the user had to look up the correct uninstall command for each manager manually. The script already has a `print_message` helper (via `shared-utils.sh`) and a `report_orphans` helper that both detects and prints orphan lists — making it a natural extension point for hints.

## Goals / Non-Goals

**Goals:**
- Print a ready-to-copy uninstall command immediately after each orphan list
- Keep stdout pipe-friendly (orphan names only, no change)
- Work consistently across all eight managers without new flags or config

**Non-Goals:**
- Executing the suggested commands
- A `--fix`/`--prune` flag
- Suppressing hints via a flag

## Decisions

### Decision: Emit hints to stderr, not stdout

Hints use the same output channel (`>&2`) as all other `print_message` calls. This preserves the existing guarantee that stdout is pipe-friendly (plain orphan names only). A downstream `| grep` or `> file` pipe on the audit output remains unaffected.

_Alternative considered: stdout with a prefix._ Rejected — it would break any script that pipes the orphan list for further processing.

### Decision: Two hint modes — `one_line` and `per_line`

- **`one_line`**: all orphan names appended to a single command (`brew uninstall pkg1 pkg2 …`). Used for managers whose CLIs natively accept multiple space-separated arguments: Homebrew formulae, casks, UV tools, Bun globals, Cargo crates.
- **`per_line`**: one command per orphan. Used where the syntax is ambiguous, multi-arg support is unconfirmed, or argument structure is non-trivial: Homebrew taps (`brew untap owner/repo`), SDKMAN (`sdk uninstall candidate version`), and all Claude Code subcommands.

_Alternative considered: always `per_line`._ Rejected — `one_line` is more convenient for the common case (brew formulae, cargo) where you want to review and delete individual items from a single command.

### Decision: Add `print_uninstall_hint` as a new standalone helper

Rather than inlining hint logic at every call site, a single `print_uninstall_hint(prefix, mode, orphans)` function is added above `report_orphans`. `report_orphans` gains two optional parameters (`uninstall_prefix`, `uninstall_mode`); callers that don't pass them get no hint (backward-compatible). Custom audit sections (UV, Bun, SDKMAN, skills) call the helper directly after their orphan-counting logic.

### Decision: Hint format uses 💡 prefix matching `print_message "tip"`

Consistent with the existing emoji-aware formatting in `shared-utils.sh`. Falls back to `[TIP]` in non-UTF-8 locales.

## Risks / Trade-offs

- **Risk**: A manager's multi-arg uninstall syntax may not work as expected → **Mitigation**: per-line mode used for all uncertain cases; the hint is advisory, not executed.
- **Risk**: Claude CLI subcommand names change → **Mitigation**: hints are strings; if the command is wrong the user edits before pasting. The audit itself does not break.
- **Trade-off**: `one_line` mode joins orphans with spaces, which breaks for package names containing spaces → accepted, as no supported manager has space-containing package names.
