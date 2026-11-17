# Proposal

## Why

`tests/lint-shell` checks syntax, shellcheck lint, and shfmt formatting, but nothing in the repo measures structural complexity. A shell function can pass all three existing layers while still being hard to reason about or modify safely — the kind of thing a cyclomatic-complexity count catches that style/lint tools don't. A `shellmetrics` binary (vendored from GitHub, currently sitting untracked at `bin/shellmetrics`) already does this for bash; this change wires it into the existing linter as a fourth layer instead of leaving it as a loose file nobody runs.

## What Changes

- Move the vendored `shellmetrics` script from `bin/shellmetrics` to `tests/bin/shellmetrics` (tracked in git, executable), with a short header comment recording its upstream source (`https://github.com/shellspec/shellmetrics`), pinned version (`0.5.0`), and the date vendored (2026-11-16). This is the first *real* vendored tool in `tests/bin/` — the two files already there (`sops`, `keepassxc-cli`) are test mocks, not real tools, and that distinction is called out in design.md.
- Add a fourth, independent **complexity** layer to `tests/lint-shell`, run after the syntax gate (a syntax failure still skips it, like lint/format), alongside lint and format rather than depending on them — a complexity finding is reported even on a file that also fails shellcheck/shfmt. It runs `tests/bin/shellmetrics --csv` against the same rendered bytes the other layers already check, and fails the file if any function's CCN (cyclomatic complexity number) exceeds **10**.
- Seed `tests/lint-shell-exclude.txt` with the one function this baseline run found over threshold among files **not already excluded** for shellcheck/shfmt reasons — see design.md's baseline. Everything already in the exclude list stays excluded regardless of reason, so it needs no separate complexity seeding.
- Refactor `check_path()` in `home/dot_local/bin/executable_claude-tooling-write-guard.tmpl` (CCN 21, the one function the baseline found over threshold) into smaller functions, each under the CCN 10 threshold, with **no change in behavior** — verified against the existing `tests/claude-tooling-write-guard_test.sh` suite. This keeps that file off the exclude list rather than undoing the shellcheck/shfmt cleanup already done to it this session.
- Extend the `shell-lint` openspec capability's requirements for the new layer (delta spec below).
- Update agent-facing guidance that already documents the three layers (`.claude/rules/home-scripts.md`, `AGENTS.md` if it enumerates them) to mention the fourth.

## Non-goals

- Fixing any other pre-existing complexity violation as part of this change. Only `check_path()` is in scope (see above); any other function that newly exceeds CCN 10 once this gate exists would already be in `tests/lint-shell-exclude.txt` for an unrelated shellcheck/shfmt reason, so it's unaffected by `--all` either way.
- Wiring the complexity layer, or `tests/lint-shell --all` generally, into GitHub Actions CI. `--all` isn't run in CI today (only via the pre-commit hook and `make lint`); this change doesn't alter that.
- Declaring `shellmetrics` in `home/.chezmoidata/packages.yaml` or installing it on any machine. It's vendored source, invoked by its tracked repo path (`tests/bin/shellmetrics`), not a machine-installed tool.
- Establishing a repo-wide vendoring convention/directory for third-party scripts in general. The header-comment approach here is scoped to this one file; a broader convention is out of scope.
- Changing any requirement of the `claude-tooling-write-guard` capability. The `check_path()` refactor is purely internal structure; its documented deny/ask tiers are unchanged and no delta spec is filed for that capability.

## Capabilities

### New Capabilities
(none)

### Modified Capabilities
- `shell-lint`: adds a fourth "complexity" check layer (shellmetrics, CCN > 10 fails), amends the "Layered checks" requirement from three layers to four, and notes the new vendored-tool dependency.

## Impact

- `tests/lint-shell` (new layer, ~20-30 added lines).
- `bin/shellmetrics` → `tests/bin/shellmetrics` (moved, tracked, header comment added).
- `tests/lint-shell-exclude.txt` (no new entries needed, per the baseline — see design.md).
- `home/dot_local/bin/executable_claude-tooling-write-guard.tmpl` (internal refactor of `check_path()`; behavior-preserving, covered by its existing test suite).
- `.claude/rules/home-scripts.md` / `AGENTS.md` (doc update to mention the fourth layer).
- No package/tag impact: nothing is added to `home/.chezmoidata/packages.yaml`, no new machine dependency.
- No secrets, permissions, or SIP implications — `shellmetrics` only reads shell source text; it has no network or privileged-file access.
