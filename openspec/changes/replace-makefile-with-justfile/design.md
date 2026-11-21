# Design

## Context

See `proposal.md` - Why. The current `Makefile` (repo root) defines `help` (default), `lint-sh`,
`lint`, `fmt`, `test`, `check`, and `hooks`, plus two variable lists (`TEST_SUITES`,
`PYTHON_TEST_SUITES`) naming the isolated suites `test`/`check` run. `just` is already declared
in `home/.chezmoidata/packages.yaml` (`dev` tag) but unused by the repo itself.

## Goals / Non-Goals

**Goals:**
- Preserve exact current behavior of every target/recipe; only the invocation syntax changes.
- Keep the justfile as close to a 1:1 translation as `just`'s recipe model allows, rather than
  restructuring the task list.

**Non-Goals:**
- No new recipes beyond the Makefile's existing seven targets.
- No change to `tests/lint-shell`, `shfmt`, or the test suites themselves.
- No compatibility shim (e.g. a stub `Makefile` that forwards to `just`) — the point of the
  change is to stop requiring Make, and a forwarding shim just adds a second thing to maintain.

## Decisions

**File-list argument: `FILES="a.sh b.sh.tmpl"` → variadic positional args**
`make lint-sh FILES="a.sh.tmpl b.sh"` relies on Make's variable-override mechanism. `just`
recipes take parameters directly, so `lint-sh` becomes a recipe with a variadic parameter
(`*files`): `just lint-sh a.sh.tmpl b.sh`, falling back to `tests/lint-shell --all` when no
files are given. *Alternative considered*: keep an env-var style (`FILES=... just lint-sh`) —
rejected, it fights `just`'s parameter model and reads worse in docs than plain positional args.

**Default recipe: hand-written `help` → `just --list`**
The Makefile's `help` target is hand-maintained `@echo` lines kept in sync with the target list
by hand. `just` auto-generates a recipe listing (with each recipe's doc-comment) via
`just --list`, so the `default` recipe becomes `@just --list`, giving bare `just` the same
discoverability as bare `make` previously without a second description to maintain.
*Alternative considered*: a literal `help` recipe wrapping `echo` lines — rejected as duplicated
maintenance that `just --list` already does for free.

**`check` composition: explicit sequential calls, not recipe dependencies**
The Makefile's `check` runs `$(MAKE) lint || rc=1; $(MAKE) test || rc=1; exit $$rc` specifically
so a `lint` failure doesn't prevent `test` from also running. `just` recipe dependencies
(`check: lint test`) stop at the first failing dependency, which would change this behavior, so
`check`'s body keeps the same explicit "run both, fail if either failed" shell logic, just
invoking `just lint`/`just test` instead of `$(MAKE)`.

**Recipe shell semantics for multi-line bodies (`test`, `check`)**
Make runs each recipe line in its own shell by default, same as `just`, but the Makefile's
`test` target uses `@set -e; for t in $(TEST_SUITES); do ...; done` as a single line to keep
the loop and `set -e` in one shell invocation. The justfile recipes for `test` and `check` carry
the same pattern (a single-line `set -e; for ...` invocation, or a `#!/usr/bin/env bash` shebang
body for readability) so the fail-fast loop semantics are unchanged.

**Removal is atomic, no deprecation window**
The `Makefile` is deleted in the same change that adds the `justfile` and updates every doc that
references `make <target>` (listed in `proposal.md` - Impact). This is a single-maintainer
personal repo with no external consumers relying on `make` specifically, so there's no benefit
to a transition period.

## Risks / Trade-offs

- [Risk] Muscle memory: typing `make lint` after the Makefile is gone fails outright (or, if a
  system-wide `Makefile`-less default exists, with "No targets specified"). → Mitigation: every
  doc/comment that currently tells the reader to run `make <target>` is updated in this same
  change (see `proposal.md` - Impact); no shim is added (see Non-Goals).
- [Risk] A machine with this repo checked out but no `chezmoi apply` since `just` was added to
  `packages.yaml` won't have `just` on `PATH` yet. → Mitigation: this is the same bootstrap
  dependency already true of `shfmt`/`shellcheck`; no new handling needed, just note it if it
  comes up.
- [Risk] Subtly different recipe-body shell semantics between `make` and `just` could silently
  change `test`/`check` behavior. → Mitigation: addressed directly above by keeping the same
  single-shell-invocation pattern Make already required; verify with `just check` locally before
  committing.

## Migration Plan

1. Add the `justfile` with all seven recipes.
2. Update `README.md`, `.githooks/pre-commit`, `.claude/rules/home-scripts.md`,
   `.github/workflows/ci.yml` (comment), `AGENTS.md`, and
   `.claude/skills/session-completion/SKILL.md` to reference `just` instead of `make`.
3. Remove the `Makefile`.
4. Run `just check` locally to confirm behavior parity before committing.

Rollback is a plain `git revert` of the commit — `Makefile` and `justfile` are never required to
coexist, so there's no data/state migration to unwind.
