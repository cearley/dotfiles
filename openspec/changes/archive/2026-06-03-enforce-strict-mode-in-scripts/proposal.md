## Why

Nine `run_onchange_` scripts lack full `set -euo pipefail` strict mode, leaving them vulnerable to silent failures: unset variables expand to empty strings, pipeline errors are swallowed, and unexpected non-zero exits continue execution rather than stopping. Four scripts have no error mode at all; two have `set -uo pipefail` (missing `-e`); two have `set -e` only (missing `-uo pipefail`). One script (38) also needs a small companion fix to its exit-code capture pattern, which breaks silently under `-e`.

## What Changes

- Add `set -euo pipefail` to the four scripts with no error mode: 24, 25, 26, 28
- Add `-e` flag to the two scripts with `set -uo pipefail`: 38, 39
- Add `-uo pipefail` to the two scripts with `set -e`: 45, 90
- Add `set -euo pipefail` to the one script with no error mode: 95
- Fix script 38's `_mcp_output=$(...)` / `_mcp_exit=$?` pattern to be `-e` safe: initialize `_mcp_exit=0` before each command-substitution assignment and use `|| _mcp_exit=$?` to capture failure without triggering exit

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `script-execution`: Adding a normative requirement that all `run_onchange_` scripts SHALL use `set -euo pipefail`.

## Impact

- **Affected files**: 9 scripts in `home/.chezmoiscripts/`
- **Tags affected**: `core` (24, 25, 26, 28, 45, 90, 95), `ai` (38, 39)
- **Behavioral change**: Previously silent failures now terminate the script immediately. All affected scripts already use `if !` guards and explicit `exit` for expected failure paths, so this should not change normal-path behavior.
- **Security**: No secrets involved.
- **Non-goals**: Does not add `set -euo pipefail` to `run_once_` scripts or other script types. Does not fix the `echo` vs `print_message` inconsistencies or syncthing `output` fragility.
