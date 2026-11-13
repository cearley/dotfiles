# shell-lint Specification

## Purpose

Runs layered static checks (syntax, shellcheck lint, shfmt format) over the repo's shell scripts, including chezmoi shell templates rendered first through the mock template harness, from a single small command, a pre-commit hook on touched files, and agent guidance.

## Requirements

### Requirement: Shell file discovery
With `--all`, the linter SHALL check under `home/` every `*.sh` file, every `*.sh.tmpl` file, and every other `*.tmpl` file whose source contains a `sh` or `bash` shebang line. It SHALL exclude `home/.chezmoitemplates/` and the paths listed in `tests/lint-shell-exclude.txt`.

#### Scenario: Plain shell script is discovered
- **WHEN** `home/scripts/shared-utils.sh` exists and isn't excluded
- **THEN** `--all` checks it directly, without rendering

#### Scenario: Extension-less shell template is discovered by shebang
- **WHEN** an extension-less template such as `executable_mcp-env-wrapper.tmpl` has a `#!/bin/bash` line
- **THEN** `--all` renders and checks it

#### Scenario: Non-shell template is ignored
- **WHEN** a `.tmpl` file has no sh/bash shebang line (e.g. JSON, TOML, a python script)
- **THEN** `--all` neither renders nor checks it

### Requirement: Exclude list
`tests/lint-shell-exclude.txt` SHALL list source paths, one per line (`#` comments allowed), that `--all` skips. It SHALL NOT affect files passed explicitly, so the pre-commit hook checks every touched file in full. The list is maintained by hand and only shrinks.

#### Scenario: Excluded file skipped by --all
- **WHEN** a failing file is listed in the exclude list
- **THEN** `tests/lint-shell --all` doesn't check it and doesn't fail because of it

#### Scenario: Excluded file checked when named
- **WHEN** `tests/lint-shell <excluded file>` is run
- **THEN** the file is checked and its failures fail the run

### Requirement: Templates are checked on rendered output
Templates SHALL be rendered through `tests/run-template` (mock secrets, never real KeePassXC or SOPS secrets), and every layer SHALL run on the exact rendered output, with no normalization. Findings SHALL name the source template path.

#### Scenario: Template with a shellcheck finding
- **WHEN** a template renders to a script with an unquoted variable expansion
- **THEN** the finding is reported against the source template path and the run exits non-zero

#### Scenario: Rendering reads no real secrets
- **WHEN** a template calls `keepassxc`, `keepassxcAttribute`, or the `sopsDecrypt` partial
- **THEN** rendering uses the mock fixtures and no unlock prompt appears

### Requirement: Render outcomes are classified
A template that renders to empty or whitespace-only output SHALL be skipped. A template that fails to render SHALL be a failure that shows chezmoi's error.

#### Scenario: Platform-gated template renders empty
- **WHEN** a template's content is wrapped in a condition that is false on this machine
- **THEN** it is skipped and the exit status is unaffected

#### Scenario: Template fails to render
- **WHEN** `tests/run-template` exits non-zero for a template
- **THEN** the linter reports a render failure with chezmoi's error and exits non-zero

### Requirement: Layered checks
Each file SHALL be checked in order: syntax, then lint, then format. A syntax failure SHALL skip the later layers for that file. Every failure line SHALL name its layer.

#### Scenario: Syntax error stops later layers
- **WHEN** a file contains `if then`
- **THEN** a syntax failure is reported, shellcheck and shfmt don't run on it, and the run exits non-zero

#### Scenario: Lint and format both run on valid syntax
- **WHEN** a file parses but has both a shellcheck finding and a format difference
- **THEN** both are reported, each labelled with its layer

### Requirement: Syntax check
The syntax layer SHALL parse without executing, using `sh -n` for a `sh` shebang and `bash -n` otherwise. Sourced files are not parsed as part of the sourcing file.

#### Scenario: Parse error is reported
- **WHEN** a file has an unterminated `if`
- **THEN** the syntax layer fails with the shell's error and line number

#### Scenario: Sourced library checked on its own
- **WHEN** a template sources `home/scripts/shared-utils.sh`
- **THEN** that library isn't parsed by the template's syntax check, and is checked as its own `*.sh` file

### Requirement: Shared shellcheck configuration
All shellcheck runs, local and CI, SHALL take their settings from the repo-root `.shellcheckrc`, which enables following sourced files. Callers SHALL NOT pass rule enables or disables on the command line.

#### Scenario: Sourced shared utilities are followed
- **WHEN** a rendered script sources `home/scripts/shared-utils.sh` by absolute path
- **THEN** shellcheck follows it rather than reporting SC1091

#### Scenario: CI uses the shared configuration
- **WHEN** the CI `shell_lint` job runs shellcheck
- **THEN** a rule disabled in `.shellcheckrc` is not reported in CI

### Requirement: Format check
The format layer SHALL run `shfmt -d` with settings from the repo-root `.editorconfig` (4-space indent, indented `case` items), resolved against the source path. Any difference SHALL fail the file. The linter SHALL NOT rewrite any file.

#### Scenario: Template blank-line artifact is reported
- **WHEN** a template renders with a doubled blank line left by a `{{ end }}` tag
- **THEN** the format layer fails with a diff showing the extra line

#### Scenario: Template fixed by whitespace control passes
- **WHEN** that tag is changed to `{{- end }}`
- **THEN** the format layer passes

#### Scenario: Check never rewrites
- **WHEN** the format layer finds differences
- **THEN** the file on disk is unchanged

### Requirement: Linter invocation
`tests/lint-shell` SHALL accept file paths or `--all`, skip non-shell files, and exit 0 only when no checked file fails.

#### Scenario: Explicit file
- **WHEN** `tests/lint-shell home/.chezmoiscripts/<script>.sh.tmpl` is run
- **THEN** only that file is checked

#### Scenario: Explicit non-shell file
- **WHEN** a path given to the linter is not a shell file
- **THEN** it is skipped, not failed

### Requirement: Manual check entry points
A root `Makefile` SHALL provide `lint-sh` (`--all`, or `FILES=...`), `lint` (all linters), `test` (isolated suites), `check` (`lint` plus `test`), `fmt` (rewrite plain `*.sh` outside `.chezmoitemplates/` with shfmt, never templates), and `hooks`.

#### Scenario: Lint everything
- **WHEN** `make lint` is run
- **THEN** every discovered, non-excluded shell file is checked, and make exits non-zero if any fails

#### Scenario: Lint specific files
- **WHEN** `make lint-sh FILES="a.sh.tmpl b.sh"` is run
- **THEN** only those files are checked, excluded or not

#### Scenario: Format plain scripts
- **WHEN** `make fmt` is run
- **THEN** plain `*.sh` files under `home/` are rewritten and no `*.tmpl` file is modified

### Requirement: Pre-commit hook
A tracked `.githooks/pre-commit` SHALL pass the staged (added, copied, modified, renamed) files under `home/` to `tests/lint-shell` and block the commit on any failure. Unstaged files and the exclude list play no part. The repository SHALL document `make hooks`; `git commit --no-verify` SHALL bypass the hook.

#### Scenario: Staged template with a finding
- **WHEN** a commit stages a `*.sh.tmpl` whose rendered output has a shellcheck finding
- **THEN** the commit is rejected and the finding is printed

#### Scenario: Touched excluded file must be clean
- **WHEN** a commit stages a change to a file listed in the exclude list that still fails
- **THEN** the commit is rejected

#### Scenario: Untouched backlog does not block
- **WHEN** a commit stages only clean shell files, or only non-shell files such as `packages.yaml`
- **THEN** the commit succeeds

### Requirement: Agent guidance
Agent-facing instructions loaded under `home/` SHALL tell agents to run `tests/lint-shell <file>` on each shell file or template they create or modify and fix all failures before reporting done, to remove fixed files from the exclude list, to never add files to it, that line numbers refer to rendered output (`tests/run-template <file>` shows it), and to fix template format with `{{-`/`-}}`.

#### Scenario: Agent edits a shell template
- **WHEN** an agent modifies a `*.sh.tmpl` file under `home/`
- **THEN** the loaded guidance directs it to run `tests/lint-shell <file>` and resolve all failures before completion
