# Manual check entry points for shell linting (openspec: shell-template-lint).
# Tool settings live in .shellcheckrc and .editorconfig, not here.

# Isolated suites run by `just test` (D9). Each was audited: it uses a mktemp
# scratch dir, runs a repo script directly (not mock-rendered), and sets HOME to
# the scratch dir.
test_suites := "tests/test-basic-memory-write-guard.sh"
python_test_suites := "tests/test_memory_workflow.py tests/test_memory_workflow_hook_messages.py"

# Excluded from `test` (not confirmed isolated):
#   tests/test-claude-settings-ledger.sh      executes mock-rendered scripts (run-template
#                                             output) and does not sandbox HOME/PATH
#   other tests/test_*.py                     Python tests; runner not yet confirmed
#                                             isolated, so they stay out of `check`

# List available recipes
default:
    @just --list

# Lint shell files (all, or pass specific files)
lint-sh *files:
    tests/lint-shell {{ if files == "" { "--all" } else { files } }}

# Run all linters (currently lint-sh)
lint: lint-sh

# Rewrite plain home/**/*.sh with shfmt (never *.tmpl)
fmt:
    find home -name '*.sh' -not -path 'home/.chezmoitemplates/*' -print0 | xargs -0 shfmt -w

# Run the isolated tests/test-*.sh suites
test:
    @set -e
    @for t in {{ test_suites }}; do echo "== $t"; bash $t; done
    @for t in {{ python_test_suites }}; do echo "== $t"; python3 $t; done

# lint + test (runs both; fails if either fails)
check:
    @rc=0; just lint || rc=1; just test || rc=1; exit $rc

# Set core.hooksPath to .githooks
hooks:
    git config core.hooksPath .githooks
