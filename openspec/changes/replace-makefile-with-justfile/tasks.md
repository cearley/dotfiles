# Tasks

## 1. Add the justfile

- [x] 1.1 Create a root `justfile` with `default` (`@just --list`), `lint`, `fmt`, `test`,
      `check`, and `hooks` recipes mirroring the current Makefile targets (same
      `TEST_SUITES`/`PYTHON_TEST_SUITES` lists, same `check` semantics of running both `lint`
      and `test` and failing if either fails, same multi-line shell semantics for the `test`
      loop). Verify with `just --list` showing all six recipes.
- [x] 1.2 Add the `lint-sh` recipe with a variadic `*files` parameter (`tests/lint-shell --all`
      when no files given, `tests/lint-shell {{files}}` otherwise). Verify `just lint-sh` matches
      `make lint-sh`'s output and exit code, and `just lint-sh <some file>.sh` matches
      `make lint-sh FILES="<some file>.sh"`'s output and exit code, on the same file(s).
- [x] 1.3 Run `just lint`, `just fmt` (on a scratch copy, or confirm via `git status` it only
      touches plain `*.sh`, never `*.tmpl`), `just test`, `just check`, and `just hooks`
      side-by-side with their `make` equivalents and confirm identical output/exit codes before
      removing the Makefile.

## 2. Update documentation and scripts that reference `make`

- [x] 2.1 Update `README.md`'s shell-linting section (`make hooks`/`lint`/`check`/`fmt` →
      `just` equivalents). Verify with `grep -n "make " README.md` returning no hits.
- [x] 2.2 Update the `.githooks/pre-commit` header comment ("Enable once per clone with
      `make hooks`" → `just hooks`). Verify with `grep -n "make " .githooks/pre-commit`
      returning no hits.
- [x] 2.3 Update `.claude/rules/home-scripts.md`'s references to `make fmt`, `make lint`, and
      `make hooks`. Verify with `grep -n "make " .claude/rules/home-scripts.md` returning no
      hits.
- [x] 2.4 Update the `.github/workflows/ci.yml` comment referencing `make lint` to say
      `just lint`. Verify the workflow file still parses (`yamllint .github/workflows/ci.yml` or
      equivalent) since this is a comment-only edit.
- [x] 2.5 Update `AGENTS.md`'s "Run `make lint`" line. Verify with `grep -n "make " AGENTS.md`
      returning no hits.
- [x] 2.6 Update `.claude/skills/session-completion/SKILL.md`'s references to `make`. Verify
      with `grep -n "make " .claude/skills/session-completion/SKILL.md` returning no hits.

## 3. Remove the Makefile and verify parity

- [x] 3.1 Delete the root `Makefile`. Verify with
      `grep -rln "make lint\|make test\|make check\|make fmt\|make hooks" --include="*.md"
      --include="*.tmpl" --include="*.sh" --include="*.yml" .` (excluding
      `openspec/changes/replace-makefile-with-justfile/`) returning no files.
- [x] 3.2 Run `just check` end-to-end on the repo as it now stands and confirm it exits 0 (or
      shows only the same pre-existing failures `make check` showed before this change, if any).

## Workflow follow-up

- Run `/opsx:verify` to confirm the implementation matches proposal.md, the shell-lint spec
  delta, and design.md.
- Archive the change (`/opsx:archive`) once review requirements are satisfied.
