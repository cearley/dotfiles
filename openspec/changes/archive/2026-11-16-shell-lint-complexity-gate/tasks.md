# Tasks

## 1. Vendor shellmetrics

- [x] 1.1 Read the upstream `shellspec/shellmetrics` repository's actual `LICENSE` file (not just secondary metadata) to confirm its license; stop and flag if it's not MIT or doesn't permit vendoring a copy.
- [x] 1.2 `git mv bin/shellmetrics tests/bin/shellmetrics`; add a header comment immediately after the `#!/bin/bash` line recording the upstream URL (`https://github.com/shellspec/shellmetrics`), pinned version (`0.5.0`), the confirmed license from 1.1, and vendor date (2026-11-16); verify `tests/bin/shellmetrics --version` still prints `0.5.0` and `bin/shellmetrics` no longer exists.
- [x] 1.3 `git add tests/bin/shellmetrics` with the executable bit preserved; verify `git ls-files -s tests/bin/shellmetrics` shows mode `100755`.

## 2. Complexity layer in tests/lint-shell

- [x] 2.1 Add a `check_complexity` (or similarly named) step to `lint_file()` in `tests/lint-shell`, run after the syntax gate and independently of the lint/format layers (D2): parse `tests/bin/shellmetrics --csv` output for the already-rendered/plain file, fail if any row's `ccn` field exceeds 10, and label output with a `complexity` layer tag via the existing `label` helper; verify `tests/lint-shell tests/lint-shell` still exits 0 (self-check, as the existing `[lint]`/`[format]` layers already require).
- [x] 2.2 Update `tests/lint-shell`'s own header-comment usage text to list four layers instead of three; verify `tests/lint-shell --help`-equivalent (running it with no args) prints the updated text.
- [x] 2.3 Verify the independent-layer behavior (D2) with a scratch file that has both a shellcheck finding and a function over CCN 10: confirm `tests/lint-shell <scratch file>` reports both `[lint]` and `[complexity]` failures in one run.
- [x] 2.4 Verify the syntax-gate behavior is unchanged: a scratch file with a syntax error (e.g. `if then`) still reports only `[syntax]`, with no `[complexity]` line.

## 3. Refactor check_path() (home/dot_local/bin/executable_claude-tooling-write-guard.tmpl)

- [x] 3.1 Run `tests/claude-tooling-write-guard_test.sh` and record it passing before any change, as the behavior-preservation baseline.
- [x] 3.2 Extract `resolve_check_path()` (the `realpath`-with-dirname-fallback block) as its own function; verify the test suite (3.1) still passes.
- [x] 3.3 Extract `profile_mismatch_message()` (the active/target profile comparison producing the `mismatch` string) as its own function; verify the test suite still passes.
- [x] 3.4 Extract the `settings.json`-specific managed-file branch, including its nested old_string/new_string managed-key detection, into its own function(s) (e.g. `check_managed_settings_json()`, with the old_string/new_string detection as a nested helper); verify the test suite still passes.
- [x] 3.5 Extract the `plugins/`-under-scope branch and the `skills/`-under-scope branch into their own functions (e.g. `check_plugins_dir()`, `check_skills_dir()`); verify the test suite still passes.
- [x] 3.6 Confirm `check_path()` itself is now CCN ≤ 10 and every extracted function is too: `tests/run-template home/dot_local/bin/executable_claude-tooling-write-guard.tmpl | tests/bin/shellmetrics --csv -` (or equivalent) shows no function over 10. (Required two additional extractions beyond the five named above — `check_managed_file()` and `classify_in_scope_path()` — since those alone left `check_path` at CCN 12; all functions are now ≤ 9.)
- [x] 3.7 Run `tests/lint-shell home/dot_local/bin/executable_claude-tooling-write-guard.tmpl` directly (not through `--all`) and verify it passes all four layers.

## 4. Full lint run and exclude-list state

- [x] 4.1 Run `tests/lint-shell --all` and verify it exits 0 with zero new entries needed in `tests/lint-shell-exclude.txt` (per the baseline in design.md, the one actionable finding was fixed in section 3, not excluded); confirm `git diff tests/lint-shell-exclude.txt` shows no changes from this change's own work (the file's current uncommitted state, unrelated to this change, is left as-is).

## 5. Documentation

- [x] 5.1 Update `.claude/rules/home-scripts.md`'s "Shell Linting" section to describe four layers (syntax, lint, format, complexity) instead of three, including the CCN > 10 threshold; verify by reading the updated section back.

## Workflow follow-up

- Archive this change once implementation and verification above are complete, syncing the `shell-lint` delta spec into `openspec/specs/shell-lint/spec.md`.
- Verify the archived `shell-lint` spec reads correctly as a 4-layer capability (`openspec show shell-lint --type spec`).
