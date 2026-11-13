# Manual check entry points for shell linting (openspec: shell-template-lint).
# Tool settings live in .shellcheckrc and .editorconfig, not here.
# Portable to GNU make 3.81 (macOS /usr/bin/make).

.DEFAULT_GOAL := help
.PHONY: help lint-sh lint fmt test check hooks

# Isolated suites run by `make test` (D9). Each was audited: it uses a mktemp
# scratch dir, runs a repo script directly (not mock-rendered), and sets HOME to
# the scratch dir.
TEST_SUITES := tests/test-basic-memory-write-guard.sh

# Excluded from `test` (not confirmed isolated):
#   tests/test-claude-settings-ledger.sh      executes mock-rendered scripts (run-template
#                                             output) and does not sandbox HOME/PATH
#   tests/test-claude-tooling-write-guard.sh  executes a mock-rendered guard that calls the
#                                             real `chezmoi managed` and reads the real
#                                             $HOME/.claude; HOME is not sandboxed
#   tests/test_*.py                           Python tests; runner not yet confirmed
#                                             isolated, so they stay out of `check`

help:
	@echo "Targets:"
	@echo "  lint-sh  Lint shell files (all, or FILES=\"a.sh b.sh.tmpl\")"
	@echo "  lint     Run all linters (currently lint-sh)"
	@echo "  fmt      Rewrite plain home/**/*.sh with shfmt (never *.tmpl)"
	@echo "  test     Run the isolated tests/test-*.sh suites"
	@echo "  check    lint + test (runs both; fails if either fails)"
	@echo "  hooks    Set core.hooksPath to .githooks"

lint-sh:
	tests/lint-shell $(if $(FILES),$(FILES),--all)

lint: lint-sh

fmt:
	find home -name '*.sh' -not -path 'home/.chezmoitemplates/*' -print0 | xargs -0 shfmt -w

test:
	@set -e; for t in $(TEST_SUITES); do echo "== $$t"; bash $$t; done

check:
	@rc=0; $(MAKE) lint || rc=1; $(MAKE) test || rc=1; exit $$rc

hooks:
	git config core.hooksPath .githooks
