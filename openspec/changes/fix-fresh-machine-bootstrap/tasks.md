## 1. Fix Invalid Cask

- [x] 1.1 Remove `dotnet-sdk10-0-200` from the `dev.casks` list in `home/.chezmoidata/packages.yaml` (line 101)
- [x] 1.2 Verify `dotnet-sdk10` remains on the line immediately after (no other edits needed)
- [x] 1.3 Confirm the tap `isen-ng/dotnet-sdk-versions` is still listed under `darwin.taps` (provides `dotnet-sdk10`)

## 2. Fix uv Installer Ordering

- [x] 2.1 Rename `home/.chezmoiscripts/run_once_before_darwin-30-install-uv.sh.tmpl` → `run_once_before_darwin-21-install-uv.sh.tmpl` using `git mv`
- [x] 2.2 Verify template renders correctly: `chezmoi execute-template < home/.chezmoiscripts/run_once_before_darwin-21-install-uv.sh.tmpl`
- [x] 2.3 Confirm new script sorts between position 20 (SDKMAN) and position 23 (brew packages) in `ls home/.chezmoiscripts/ | sort`

## 3. Fix Brew Bundle Failure Propagation

- [x] 3.1 Add `set -euo pipefail` immediately after the shebang line in `home/.chezmoiscripts/run_onchange_before_darwin-23-install-packages.sh.tmpl`
- [x] 3.2 Verify template renders correctly: `chezmoi execute-template < home/.chezmoiscripts/run_onchange_before_darwin-23-install-packages.sh.tmpl`
- [x] 3.3 Confirm the rendered script contains `set -euo pipefail` before the `source shared-utils.sh` line

## 4. Fix README Placeholder

- [x] 4.1 Find the bootstrap command example in `README.md` (the `sh -c "$(curl ...)" -- init --apply <your-github-username>` line)
- [x] 4.2 Replace `<your-github-username>` with `YOUR_GITHUB_USERNAME`

## 5. Update Documentation

- [x] 5.1 Update CLAUDE.md script ordering table: change "**30**: UV manager" entry to "**21**: UV manager" and move it to the Package Management group line
- [x] 5.2 Update the `script-execution` spec's Design Decisions "Current Script Inventory" section to move uv from the Environment Managers (30-39) group to Package Management (20-29) group at position 21
