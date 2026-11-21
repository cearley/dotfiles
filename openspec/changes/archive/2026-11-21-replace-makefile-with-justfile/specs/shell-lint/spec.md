# Spec Delta

## MODIFIED Requirements

### Requirement: Manual check entry points
A root `justfile` SHALL provide `lint-sh` (`--all`, or a space-separated list of file paths), `lint` (all linters), `test` (isolated suites), `check` (`lint` plus `test`), `fmt` (rewrite plain `*.sh` outside `.chezmoitemplates/` with shfmt, never templates), and `hooks`.

#### Scenario: Lint everything
- **WHEN** `just lint` is run
- **THEN** every discovered, non-excluded shell file is checked, and the recipe exits non-zero if any fails

#### Scenario: Lint specific files
- **WHEN** `just lint-sh a.sh.tmpl b.sh` is run
- **THEN** only those files are checked, excluded or not

#### Scenario: Format plain scripts
- **WHEN** `just fmt` is run
- **THEN** plain `*.sh` files under `home/` are rewritten and no `*.tmpl` file is modified

### Requirement: Pre-commit hook
A tracked `.githooks/pre-commit` SHALL pass the staged (added, copied, modified, renamed) files under `home/` to `tests/lint-shell` and block the commit on any failure. Unstaged files and the exclude list play no part. The repository SHALL document `just hooks`; `git commit --no-verify` SHALL bypass the hook.

#### Scenario: Staged template with a finding
- **WHEN** a commit stages a `*.sh.tmpl` whose rendered output has a shellcheck finding
- **THEN** the commit is rejected and the finding is printed

#### Scenario: Touched excluded file must be clean
- **WHEN** a commit stages a change to a file listed in the exclude list that still fails
- **THEN** the commit is rejected

#### Scenario: Untouched backlog does not block
- **WHEN** a commit stages only clean shell files, or only non-shell files such as `packages.yaml`
- **THEN** the commit succeeds
