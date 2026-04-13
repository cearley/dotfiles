## Why

A fresh macOS VM bootstrap test revealed two blockers that prevent `chezmoi apply` from completing on a new machine, plus a silent failure mode that masks package installation errors. All four issues are independently fixable with small, targeted changes.

## What Changes

- Remove the invalid Homebrew cask `dotnet-sdk10-0-200` from `packages.yaml` — it does not exist in the `isen-ng/dotnet-sdk-versions` tap, causing `brew bundle` to abort before installing any packages
- Rename `run_once_before_darwin-30-install-uv.sh.tmpl` → `run_once_before_darwin-21-install-uv.sh.tmpl` to install uv before the tools script (position 25) that requires it
- Add explicit exit-code propagation to the brew bundle script so failures surface as errors rather than silently succeeding
- Update the README install command example to use a non-shell-metacharacter placeholder (`YOUR_GITHUB_USERNAME` instead of `<your-github-username>`)
- Update CLAUDE.md script ordering table to reflect position 21 for uv install

## Capabilities

### New Capabilities
<!-- None — all changes are fixes to existing behavior -->

### Modified Capabilities
- `package-management`: script execution order requirement changes (uv installer must run before position 25); brew bundle must propagate failures
- `script-execution`: uv installer position moves from group 30-39 (env managers) to group 20-29 (package management)

## Impact

- **Affected tags**: `dev` (brew bundle failure affects all tags; uv ordering affects any tag that installs uv tools)
- **Affected files**:
  - `home/.chezmoidata/packages.yaml` — remove one invalid cask entry
  - `home/.chezmoiscripts/run_once_before_darwin-30-install-uv.sh.tmpl` — rename to position 21
  - `home/.chezmoiscripts/run_onchange_before_darwin-23-install-packages.sh.tmpl` — add `set -euo pipefail` or explicit exit-code check
  - `README.md` — fix placeholder formatting
  - `CLAUDE.md` — update script ordering table
- **Breaking changes**: None — all changes are fixes; existing machines that already ran the scripts are unaffected (run_once scripts track by hash)
- **Security**: No impact — no credential or permission changes
- **Non-goals**: Fixing any other brew bundle packages; adding new packages; changing which packages are installed; modifying the SDKMAN or nvm installer ordering
