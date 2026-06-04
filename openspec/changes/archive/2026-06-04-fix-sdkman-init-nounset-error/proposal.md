## Why

`run_onchange_before_darwin-24-install-sdks.sh.tmpl` now runs under `set -euo pipefail` (added in the 2026-06-03 enforce-strict-mode change). When the script sources `~/.sdkman/bin/sdkman-init.sh`, that third-party script references `$ZSH_VERSION` without a default value. Under bash with `set -u`, this is a fatal "unbound variable" error, causing `chezmoi apply` to abort at script 24.

## What Changes

- Bracket the `source sdkman-init.sh` call in `darwin-24` with `set +u` / `set -u` to suspend nounset mode during the third-party sourcing operation only.
- Update the `script-execution` spec to document the approved pattern for sourcing third-party scripts that are not nounset-safe.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `script-execution`: Add a scenario covering the approved `set +u` / source / `set -u` bracket pattern when sourcing third-party scripts that do not guard their internal variable references.

## Impact

- **File changed**: `home/.chezmoiscripts/run_onchange_before_darwin-24-install-sdks.sh.tmpl` (one-line guard around source call)
- **Spec updated**: `openspec/specs/script-execution/spec.md` (new scenario under Strict Error Mode requirement)
- **Tags affected**: `dev` (darwin-24 is gated on `has "dev" .tags`)
- **Security**: No secrets involved; no permission changes; no SIP implications.
- **Non-goals**: Fixing upstream `sdkman-init.sh`; applying this pattern to any script other than darwin-24; suppressing `-e` or `-o pipefail` (only `-u` is bracketed, and only for the duration of the source call).
