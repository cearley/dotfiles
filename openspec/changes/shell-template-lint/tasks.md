# Tasks

## 1. Mock whole-entry `show` (template-testing)

- [x] 1.1 In `tests/bin/keepassxc-cli` `handle_show_args`, print `Title`/`UserName`/`Password`/`URL`/`Notes` as `Key: value` lines via `lookup` when no `--attributes` is given (D5); verify `tests/run-template --inline '{{ (keepassxc "atuin").UserName }}'` prints `mock:atuin:UserName`
- [x] 1.2 Verify attribute mode is unchanged: `tests/run-template home/private_dot_ssh/id_ed25519.pub.tmpl` still renders the fixture public key, and `tests/run-template --inline '{{ keepassxcAttribute "GitHub" "Access Token" }}'` prints `mock:GitHub:Access Token`
- [x] 1.3 Verify a fixture override wins: with a scratch fixtures file defining `{"atuin":{"Password":"pw"}}`, `tests/run-template --fixtures <tmp> --inline '{{ (keepassxc "atuin").Password }}'` prints `pw`
- [x] 1.4 Verify both former render failures now render: `tests/run-template home/.chezmoiscripts/run_once_after_darwin-83-login-atuin.sh.tmpl` and `.../run_onchange_after_darwin-46-setup-ssh-github.sh.tmpl` exit 0
- [x] 1.5 Update the `tests/run-template` header comment to mention whole-entry `keepassxc` support; verify `tests/run-template --help` shows it

## 2. Shared configs and tool dependency

- [x] 2.1 Add repo-root `.shellcheckrc` with `external-sources=true` and `source-path=SCRIPTDIR`, no disables (D4); verify `shellcheck home/scripts/shared-utils.sh` runs with it (e.g. a temporary `disable=SC2086` line silences a known SC2086, then remove it)
- [x] 2.2 Add repo-root `.editorconfig` with `root = true` and `[*.{sh,sh.tmpl}]` → `indent_style = space`, `indent_size = 4`, `switch_case_indent = true` (D12); verify `shfmt -d --filename x.sh.tmpl < <(printf 'case a in\na) :;;\nesac\n')` proposes a 4-space indented case item
- [x] 2.3 Add `'shfmt'` to `home/.chezmoidata/packages.yaml` under the `dev` brews, next to `'shellcheck'` (core Homebrew formula, so no `trusted:` entry); verify `tests/run-template home/.chezmoiscripts/run_onchange_before_darwin-23-install-packages.sh.tmpl | grep shfmt` shows it on this `dev` machine

## 3. `tests/lint-shell`

- [x] 3.1 Create executable `tests/lint-shell` with a header-comment usage, `--all` / `--staged` / file args, `--keep`, `-h`, and `mktemp -d` + `trap` cleanup (D1, D2); verify `tests/lint-shell --help` prints usage and no temp dir survives a normal run
- [x] 3.2 Implement discovery (D3): `*.sh` direct, `*.sh.tmpl` render, other `*.tmpl` under `home/` rendered only if the source contains `#!` and the rendered line 1 is a sh/bash shebang; exclude `home/.chezmoitemplates/`; verify `--all` covers `home/scripts/shared-utils.sh`, all 38 `*.sh.tmpl`, and `home/dot_local/bin/executable_mcp-env-wrapper.tmpl`, and no JSON/TOML templates
- [x] 3.3 Render each template to a temp file by redirection, without `$(...)` capture, and classify: empty → skipped, render error → failure with the chezmoi message (D2); verify `run_onchange_after_darwin-48-setup-azure-auth-personal.sh.tmpl` reports skipped and a scratch template with a bad template function reports a render failure
- [x] 3.4 Implement the syntax layer (D11): `sh -n` for `#!/bin/sh`, else `bash -n`, on the rendered or plain file; on failure skip the later layers (D10); verify a scratch `*.sh` containing `if then` reports `[syntax]` with the line number and no `[lint]`/`[format]` lines
- [x] 3.5 Implement the lint layer: shellcheck on the temp file, with paths rewritten to the source path; verify `tests/lint-shell home/.chezmoiscripts/run_onchange_after_darwin-36-3-install-claude-mcp-servers.sh.tmpl` reports `[lint]` SC2086/SC2088 against that source path with no SC1091
- [x] 3.6 Implement the format layer (D12, D13): `shfmt -d --filename <source path>` on the rendered bytes for templates, `shfmt -d <file>` for plain files, run from the repo root with no formatting flags; verify (a) `run_onchange_after_darwin-36-2-install-claude-skills.sh.tmpl` reports a `[format]` blank-line diff, (b) a scratch copy fixed with `{{-`/`-}}` passes, (c) `git status` shows no file modified by the check
- [x] 3.7 Print a passed/failed/skipped summary and exit 0 only when nothing failed; verify on a known-clean file (exit 0) and a known-failing one (exit 1)
- 3.8 (superseded by D16) Implement `--staged` with widening on shared inputs (D6, including `.editorconfig`/`.shellcheckrc`) and the partially-staged warning (D7); verify on a throwaway branch: staging only a clean `*.sh.tmpl` checks just that file; staging a `home/.chezmoitemplates/` file checks all; staging only a `.md` file checks nothing and exits 0; staging a file with extra unstaged edits prints the warning
- [x] 3.9 Self-check the linter: discovery covers `home/` only, so run `bash -n`, `shellcheck`, and `shfmt -d` directly on `tests/lint-shell`; verify all three exit 0
- [x] 3.10 Run `tests/lint-shell --all` and record per-layer counts (syntax/lint/format failures, skipped, passed) and the failing files in a `## Baseline` note appended to design.md; verify the lint failure count is at most 10 plus any newly discovered extension-less templates

## 4. Makefile entry points

- [x] 4.1 Add root `Makefile` with `.PHONY` targets `help` (default), `lint-sh` (`tests/lint-shell $(if $(FILES),$(FILES),--all)`), `lint` (→ `lint-sh`), `fmt` (`shfmt -w` on `find home -name '*.sh'`, never `*.tmpl`), and `hooks` (`git config core.hooksPath .githooks`); verify `make lint-sh FILES=home/scripts/shared-utils.sh` checks one file, `make` prints help, and `make -n fmt` lists no `.tmpl` path
- [x] 4.2 Audit each `tests/test-*.sh` for environment isolation (sandboxed `HOME`/`GIT_CONFIG_GLOBAL`/`PATH`, no writes outside temp dirs) and add the isolated ones to a `test` target; add `check` = `lint` + `test`, with excluded suites listed in a Makefile comment (D9); verify `make test` passes and leaves `git status` and `~/.claude*` unchanged

## 5. Pre-commit hook

- [x] 5.1 Add executable `.githooks/pre-commit` that passes the staged files under `home/` to `tests/lint-shell` from the repo root (D16; originally `--staged`); verify `bash -n`, `shellcheck`, and `shfmt -d` pass on it
- [x] 5.2 Run `make hooks` and verify `git config core.hooksPath` prints `.githooks`
- [x] 5.3 Verify blocking on a throwaway branch: commit a `*.sh.tmpl` with an unquoted `$var` (rejected, `[lint]`); commit one with only a doubled blank line from a `{{ end }}` (rejected, `[format]`); commit a clean script (succeeds); confirm `--no-verify` bypasses; then delete the branch
- [x] 5.4 Document the one-time `make hooks` setup and the `make lint` / `make check` / `make fmt` commands in `README.md` under "Using This Repository"; verify the documented commands run as written

## 6. CI

- [x] 6.1 Confirm the `shell_lint` job's `shellcheck home/dot_claude/skills/setup-memory-workflow/scripts/*.sh` picks up the root `.shellcheckrc` (D14): locally, from the repo root, a temporary `disable=` line in `.shellcheckrc` silences a matching finding in one of those scripts (revert afterwards); add a comment in `ci.yml` above the step naming `.shellcheckrc` as the only place for shellcheck settings; verify `shellcheck` still exits 0 on those scripts with the final `.shellcheckrc`
- [x] 6.2 After pushing (only with the user's approval), check the `shell_lint` job log for a shellcheck version ≥ 0.8 and a passing step; if the version is older, add an install step for a pinned version and verify it passes

## 7. Agent awareness

- [x] 7.1 Add a "Shell Linting" subsection to `.claude/rules/home-scripts.md` (after Template Testing) covering:
  - run `tests/lint-shell <file>` on every created or modified shell file or template before reporting done;
  - the three layers and that a syntax failure stops the rest;
  - line numbers refer to rendered output (`--keep` to inspect);
  - template format diffs are fixed with `{{-`/`-}}`, never by running shfmt on a template;
  - `make fmt` is for plain `*.sh` only;
  - results reflect this machine's tags;
  - the hook enforces it on commit.

  Verify the file keeps its `paths: home/**` frontmatter.
- [x] 7.2 Add a one-line pointer to `make lint` / `tests/lint-shell` in `AGENTS.md` outside the beads block; verify the beads `BEGIN/END` markers are untouched
- [x] 7.3 Make step 1 of `.claude/skills/session-completion/SKILL.md` name `make check` as the quality gate; verify the skill's frontmatter is unchanged
- [x] 7.4 Add `shell-lint` to the `CLAUDE.md` "When to Reference openspec/" list only if it fits the existing pattern; otherwise note why it was skipped

## 8. Integration

- [x] 8.1 Run `openspec validate shell-template-lint --strict` and fix any errors
- [x] 8.2 End-to-end: `make check` runs all three layers, reports the backlog by layer, and exits non-zero only because of files recorded in the 3.10 baseline; `git status` shows only intended changes and no file rewritten by the check

## Superseded (D16)

Groups 9 (known-failures baseline) and 10 (count ratchet), and task 3.8 (`--staged` widening and the partial-staging warning), were implemented and then removed by D16. Their checked boxes were taken out here so progress reflects the current design. Leftover scratch clone from 9.7 for the user to delete: `/private/tmp/claude-501/-Users-craig--local-share-chezmoi/93ff9281-ea8e-4e6a-afba-fd09cd398411/scratchpad/clone`.

## 11. Simplify `tests/lint-shell` (D16)

- [x] 11.1 Rewrite `tests/lint-shell` to the D16 shape: file args or `--all`; discovery (`*.sh`, `*.sh.tmpl`, other `home/*.tmpl` with a sh/bash shebang line in the source; skip `home/.chezmoitemplates/` and, for `--all` only, paths in `tests/lint-shell-exclude.txt`); render templates by redirect to a temp file via `tests/run-template` (empty → skip, error → fail with chezmoi's message); layers syntax (`sh -n`/`bash -n`) → `shellcheck --rcfile=<repo>/.shellcheckrc -f gcc` → `shfmt -d --filename <source path>` (extension-less templates get a `.sh` name), syntax failure skips the rest, every failure line labelled with its layer and the source path; skip non-shell paths; non-zero exit on any failure. Remove `--staged`, `--keep`, the baseline, prune, summary counters, the missing-tool check and cwd path resolution. Verify `wc -l tests/lint-shell` < 150 and the self-check passes (`bash -n`, `shellcheck`, `shfmt -d --filename tests/lint-shell.sh < tests/lint-shell`)
- [x] 11.2 Replace `tests/lint-shell-baseline.txt` with `tests/lint-shell-exclude.txt` (header comment: one path per line, `--all` only, edit by hand, only shrinks), seeded with the 55 files that fail `tests/lint-shell --all` with an empty exclude list; verify the seeded run lists exactly 55 failing files and that `tests/lint-shell --all` then exits 0
- [x] 11.3 Verify behaviors with scratch files: `if then` → `[syntax]` only, exit 1; unquoted `$var` template → `[lint]` against the source path; `{{ end }}` doubled blank line → `[format]`, and a `{{- end }}` copy passes; a template with `{{ nosuchfunc }}` → render failure; a platform-gated empty render → skipped, exit 0; a JSON template and `README.md` → skipped; an excluded file passed explicitly is still checked and fails
- [x] 11.4 Rewrite `.githooks/pre-commit` to pass `git diff --cached --name-only --diff-filter=ACMR -- home/` to `tests/lint-shell` (no-op when empty); verify `bash -n`/`shellcheck` pass on it, and in a scratch clone (delete afterwards; if deletion is denied, report the path): staging only `home/.chezmoidata/packages.yaml` commits; staging a new template with an unquoted `$var` is rejected; staging a trivial change to an excluded failing file is rejected
- [x] 11.5 `Makefile`: remove `lint-strict` and `lint-baseline-prune`; keep `help`, `lint-sh` (`$(if $(FILES),$(FILES),--all)`), `lint`, `test`, `check`, `fmt`, `hooks`; verify `make lint` and `make check` exit 0 and `make` lists only those targets
- [x] 11.6 Update guidance to D16: `.claude/rules/home-scripts.md` "Shell Linting" (run `tests/lint-shell <file>` on touched files and fix all failures; remove fixed files from the exclude list; never add files; `tests/run-template <file>` to see rendered line numbers; `{{-`/`-}}` for template format; no baseline or `--keep` wording), the README "Shell linting" block, and the `tests/lint-shell` header; verify frontmatter unchanged and no remaining mention of `baseline`, `--staged`, `--keep`, `lint-strict` or `prune` in those files (`grep`)
- [x] 11.7 Run `openspec validate shell-template-lint --strict` and `make check`; verify both pass and `git status` shows `tests/lint-shell-exclude.txt` present and `tests/lint-shell-baseline.txt` gone

## Workflow follow-up

- Fix backlog files as they're touched and remove them from `tests/lint-shell-exclude.txt`.
- Batch-format plain `*.sh` with `make fmt` in its own commit. For `setup-memory-workflow` scripts, go through that skill's version-bump/sweep process because of cross-project drift.
- Run `make hooks` on Mac Studio and Mac mini.
- Separate cleanup: remove the stale beads block from `AGENTS.md`.
- Archive with `openspec archive shell-template-lint --yes` after review.
