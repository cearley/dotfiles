# Proposal

## Why

The repo already treats `just` as its intended command runner — it's declared in
`home/.chezmoidata/packages.yaml` (`dev` tag) with the comment "Command runner for per-project
recipes (justfile)" — but the root still ships a GNU `make`-based `Makefile`. Consolidating onto
`just` removes Make's tab-sensitive syntax and `$(MAKE)` recursion footguns and makes the repo's
actual entry points match the tool it has already declared as standard.

## What Changes

- Add a `justfile` at the repo root with recipes equivalent to the current Makefile targets:
  `lint-sh` (optional file list), `lint`, `fmt`, `test`, `check`, `hooks`, and a `default` recipe
  that lists available recipes (replacing `help`).
- Remove the `Makefile`.
- Update every doc/script that documents or invokes a `make <target>` command to its `just`
  equivalent: `README.md`, `.githooks/pre-commit` (comment), `.claude/rules/home-scripts.md`,
  `.github/workflows/ci.yml` (comment only — CI doesn't invoke `make` itself), `AGENTS.md`,
  `.claude/skills/session-completion/SKILL.md`.
- **BREAKING**: `make <target>` stops working. Contributors and automation must use
  `just <target>` and have `just` installed (already declared under the `dev` tag in
  `packages.yaml`).

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `shell-lint`: requirement scenarios currently name `make lint`, `make lint-sh FILES=...`,
  `make fmt`, and `make hooks` as the commands that trigger linting, formatting, and pre-commit
  hook setup. These scenarios are updated to their `just` equivalents (`just lint`,
  `just lint-sh a.sh.tmpl b.sh`, `just fmt`, `just hooks`). No linting/formatting/hook behavior
  changes — only the invocation syntax the requirements are written against.

## Impact

- **Affected files**: `Makefile` (removed), new `justfile`, `README.md`,
  `.githooks/pre-commit`, `.claude/rules/home-scripts.md`, `.github/workflows/ci.yml`,
  `AGENTS.md`, `.claude/skills/session-completion/SKILL.md`,
  `openspec/specs/shell-lint/spec.md` (via delta spec).
- **Dependencies**: `just` is already declared in `home/.chezmoidata/packages.yaml` (`dev` tag,
  Homebrew) — no new package to add, just confirming it's in place before the Makefile goes away.
- **Tags**: `dev` only, where `just` is already scoped; this change doesn't alter tag
  membership.
- **CI**: `.github/workflows/ci.yml` runs `tests/lint-shell` directly rather than through `make`,
  so no CI step logic changes — only a comment referencing `make lint` is updated for
  consistency.
- **Security**: none — no secrets, permissions, or SIP implications.

## Non-goals

- Not changing the lint/format/test logic itself (`tests/lint-shell`, `shfmt`, the bash/Python
  test suites) — only the command-runner syntax that invokes them.
- Not restructuring `tests/lint-shell-exclude.txt` or test-suite selection.
- Not removing GNU `make` from the system — other tools/formulae may still depend on its
  presence; this only stops this repo's own workflow from requiring a `Makefile`.
- Not adding recipes beyond what the current Makefile already provides.
