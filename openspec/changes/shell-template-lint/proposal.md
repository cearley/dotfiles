# Proposal

## Why

Most shell scripts in this repo are chezmoi templates (`*.sh.tmpl`). They can already be checked by rendering them through the mock harness first (e.g. `tests/run-template <f> | shellcheck -x -a -`), but that's a manual, one-file-at-a-time step that nothing runs: no hook, no single command, and no agent guidance. CI shellchecks only the 9 non-templated `setup-memory-workflow` scripts. Separately, `core.hooksPath` points at a stale, missing `.beads/hooks` directory, so no git hooks run in this clone today.

Baseline on 2026-11-12 (this machine) over the 38 `*.sh.tmpl` files and 12 plain `*.sh` files:
- **Syntax (`bash -n`):** 0 errors in rendered templates.
- **shellcheck:** 10 templates with findings; 2 templates fail to render under the mock harness.
- **Format (`shfmt`, 4-space indent, indented `case` items):** diffs in all 12 plain `*.sh` files and in 32 of 35 rendered templates. For templates, most diffs are doubled or trailing blank lines left by template tags (`{{ if }}`/`{{ end }}`).

## What Changes

- Add a small `tests/lint-shell` command (under 150 lines) that runs three check layers, in order, on each shell file. Templates are rendered first through the existing mock harness.
  1. **Syntax:** `bash -n` (or `sh -n` for `sh` shebangs) parses without executing.
  2. **Lint:** shellcheck.
  3. **Format:** `shfmt -d` reports differences as a diff and never rewrites.

  It covers plain `*.sh` files, `*.sh.tmpl` files, and extension-less templates whose rendered output has a `sh`/`bash` shebang (e.g. `executable_*.tmpl`, `modify_*.tmpl`). It takes file paths, or `--all` to check every shell file under `home/`.
- Add repo-root `.shellcheckrc` and `.editorconfig` (4-space indent, indented `case` items) so every caller and editor shares one shellcheck and shfmt configuration.
- Format differences in templates are fixed in the template source, typically with whitespace control (`{{-`, `-}}`). Rendered output isn't normalized before checking, and templates are never rewritten automatically.
- Add a root `Makefile` with `lint-sh`, `lint`, `check`, and `fmt` targets. `fmt` rewrites plain `*.sh` files only.
- Add a tracked `.githooks/pre-commit` that passes the staged files under `home/` to the linter (touched files only, no widening), and repoint `core.hooksPath` from the missing `.beads/hooks` to `.githooks`.
- Make the CI `shell_lint` job's shellcheck step use the shared `.shellcheckrc`, and raise that job's setup-memory-workflow line budget from 100 to 160 (shfmt-clean versions of three scripts exceed 100 lines).
- Declare `shfmt` in `home/.chezmoidata/packages.yaml` under the `dev` tag next to `shellcheck`. It's installed on this machine but not declared.
- Extend the mock `keepassxc-cli` to answer whole-entry `show` requests (standard `Title`/`UserName`/`Password`/`URL`/`Notes` fields), so templates that call `(keepassxc "<entry>").UserName` render under test. This fixes the 2 render failures.
- Make agents aware of the check: add a section to `.claude/rules/home-scripts.md`, a line in `AGENTS.md`, and a quality-gate step in the `session-completion` skill.
- Add a plain exclude list (`tests/lint-shell-exclude.txt`, one path per line) that `--all` / `make lint` skips. It's seeded with today's failing files so `make lint` passes, is edited by hand, and only shrinks. Files passed explicitly, including every file the hook checks, are never excluded.
- Backlog policy: clean up when touched. The hook checks every staged shell file at full strictness, so a file you change must be clean; remove it from the exclude list in the same commit. Untouched files never block a commit.

## Non-goals

- Fixing the existing shellcheck and format backlog as part of this change. It's listed in the exclude list and cleaned up when touched; plain `*.sh` files can be batch-fixed later with `make fmt`.
- A known-failures baseline with counts, prune or stale detection, and re-checking every file when a shared input (partials, data, mocks) changes. Both were built and then removed: together they grew `tests/lint-shell` to 511 lines (see design.md D16).
- Normalizing rendered template output (collapsing blank lines, etc.) before checking.
- Rewriting templates automatically with shfmt.
- Rendering each template under multiple tag/machine profiles. Linting uses this machine's chezmoi data, so branches for other tags aren't checked.
- Rendering templates, or running the syntax and format layers, in GitHub Actions CI. The Ubuntu runner has no chezmoi config or darwin data; only the existing shellcheck step changes, to use the shared config.
- Mapping reported line numbers back to template source lines.
- Adopting a hook framework (pre-commit, lefthook) or a task runner other than `make`.

## Capabilities

### New Capabilities
- `shell-lint`: layered static checks (syntax, lint, format) of the repo's shell scripts and rendered shell templates, covering file discovery, the render-then-check pipeline, shared tool configuration, the manual entry points, the pre-commit hook, and CI's use of the shared shellcheck config.

### Modified Capabilities
- `template-testing`: the mock `keepassxc-cli` must answer whole-entry `show` requests (no `--attributes`) with standard-field output, so the chezmoi `keepassxc` template function works under the harness.

## Impact

- **New files:** `tests/lint-shell`, `tests/lint-shell-exclude.txt`, `.shellcheckrc`, `.editorconfig`, `Makefile`, `.githooks/pre-commit`.
- **Modified:** `tests/bin/keepassxc-cli`, `.github/workflows/ci.yml` (`shell_lint` job), `home/.chezmoidata/packages.yaml`, `.claude/rules/home-scripts.md`, `AGENTS.md`, `.claude/skills/session-completion/SKILL.md`, and possibly `README.md` (one-time hook setup).
- **Local git config:** `core.hooksPath` changes in `.git/config`. This is per clone and has to be set once on every machine.
- **Tags:** `dev` gains the `shfmt` Homebrew formula (core Homebrew, not a third-party tap, so no `trusted:` entry). The linting tooling itself is repo-side and installs nothing else on target machines, but lint results depend on the tags of the machine doing the rendering.
- **Dependencies:** `shellcheck` and `shfmt` (both Homebrew, `dev`), `jq` (already used by the mock), `bash` and `make` (part of the system).
- **Security:** rendering stays on the mock harness, so no real KeePassXC or SOPS secrets are read and rendered output never contains them. Rendered temp files go in a `mktemp -d` directory and are deleted on exit. `bash -n` parses without executing, and no layer runs the rendered scripts.
