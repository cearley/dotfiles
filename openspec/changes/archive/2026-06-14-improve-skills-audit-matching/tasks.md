## 1. Rewrite audit_claude_skills()

- [x] 1.1 Replace the function body with two-pass matching logic: build a set of deterministic skill names from path-style specs (`*/skills/<name>`) and `--skill <name>` flags; collect remaining specs as collection wildcards
- [x] 1.2 For each installed skill directory, classify as: direct match → skip; unmatched but skill name starts with wildcard's org-derived prefix → wildcard-covered; otherwise → orphan
- [x] 1.3 Emit orphan lines in plain stdout format (no `print_message` wrapper), matching other manager sections
- [x] 1.4 Emit `print_message "success" "No orphans"` when all skills are accounted for
- [x] 1.5 When wildcards cover unmatched skills, emit a `print_message "info"` note naming the wildcard spec(s) — but do not list individual skills attributed to the wildcard

## 2. Verify and test

- [x] 2.1 Run `audit-packages` locally and confirm the skills section now reports orphans (or "No orphans") instead of the dual-list display
- [x] 2.2 Confirm `microsoft-foundry` (or any other genuinely untracked skill) surfaces as an orphan if no wildcard covers it
- [x] 2.3 Confirm wondelai skills and `memory-notes` are matched deterministically and not flagged
- [x] 2.4 Confirm `specstoryai/agent-skills -all` is recognized as a wildcard and suppresses orphan output only for skills whose name starts with the derived prefix `specstory` — unrelated skills (e.g. `integrate-worktrees`) are still reported as orphans
