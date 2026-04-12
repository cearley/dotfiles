## Context

A fresh macOS VM bootstrap test exposed four issues ranging from a docs typo to a complete package installation failure. The test ran `sh -c "$(curl ...)" -- init --apply cearley` on a clean ARM64 macOS VM and failed during `chezmoi apply`.

The existing `package-management` spec (line 541-543) even documents the broken ordering with a NOTE: "This assumes UV is available through another mechanism (e.g., Homebrew in packages.yaml)." That assumption was never implemented, so every fresh-machine apply has been silently broken for UV tool installation.

## Goals / Non-Goals

**Goals:**
- Fix the two blockers so `chezmoi apply` completes on a fresh machine
- Make brew bundle failures visible (exit non-zero so chezmoi doesn't silently mark as done)
- Prevent the README angle-bracket placeholder from causing a zsh parse error

**Non-Goals:**
- Changing which packages are installed
- Reorganizing the overall script execution architecture
- Fixing any other brew bundle packages beyond the one invalid cask

## Decisions

### Move uv installer from position 30 → 21

**Decision**: Rename `run_once_before_darwin-30-install-uv.sh.tmpl` to `run_once_before_darwin-21-install-uv.sh.tmpl`.

**Rationale**: Script 25 (`run_onchange_before_darwin-25-install-tools.sh.tmpl`) calls `require_tools uv` and exits 1 if uv is absent. On a fresh machine, uv is not installed by any prior step. The existing spec documents this as intentional with a NOTE claiming UV would come from Homebrew — but it's not in the Homebrew package list.

Position 21 is chosen because:
- It falls within the package-management group (20-29), where other tool installers live
- It runs after SDKMAN (20) which is independent
- It runs before Homebrew packages (23), Homebrew-installed tools don't interfere
- No existing script occupies position 21

**Alternatives considered**:
- **Rename script 25 → 31**: Also works, but inverts semantics — uv install should precede uv tool install in reading order
- **Add uv to Homebrew packages.yaml**: Would work but uses a different installation path than the project's chosen method (official astral.sh installer); Homebrew uv may lag behind current release
- **Install uv inline within script 25**: Violates single-responsibility and would mean brew-installed packages (positions 23+) are already past by then

### Remove `dotnet-sdk10-0-200` cask from packages.yaml

**Decision**: Delete the `dotnet-sdk10-0-200` entry from `home/.chezmoidata/packages.yaml`. Keep `dotnet-sdk10`.

**Rationale**: The `isen-ng/dotnet-sdk-versions` tap does not provide a cask named `dotnet-sdk10-0-200`. Having both `dotnet-sdk10-0-200` AND `dotnet-sdk10` in the list was already redundant — `dotnet-sdk10` is the correct generic .NET 10 installer from the same tap. The invalid entry causes `brew bundle` to abort at the fetch phase, leaving ALL packages uninstalled.

**Alternatives considered**:
- **Find the correct cask name for .NET 10.0.200**: The specific-version pattern exists for .NET 6 and 8 (e.g., `dotnet-sdk6-0-400`, `dotnet-sdk8-0-400`). For .NET 10, the SDK 10.0.200 preview may not be published to the tap yet. The generic `dotnet-sdk10` is the appropriate reference until a stable specific version is available.
- **Pin to a preview tag**: Unnecessary complexity; the generic cask tracks the stable channel.

### Add explicit exit-code propagation to brew bundle script

**Decision**: Add `set -euo pipefail` to `run_onchange_before_darwin-23-install-packages.sh.tmpl`, or capture and re-emit the brew bundle exit code.

**Rationale**: Without this, `brew bundle` failures are swallowed — the script exits 0 regardless, chezmoi marks the `run_onchange` script as complete, and the failure will not be retried on the next `chezmoi apply` (until packages.yaml changes again). This is a silent correctness failure.

**Mechanism**: Adding `set -euo pipefail` at the top of the generated script is the simplest approach. The script currently has no such guard.

**Risk**: `set -e` may cause the script to exit on non-fatal warnings from brew. Mitigation: test with `brew bundle --no-lock` and confirm exit codes for partial-install scenarios.

### Fix README placeholder formatting

**Decision**: Replace `<your-github-username>` with `YOUR_GITHUB_USERNAME` in the README install command.

**Rationale**: In zsh, `<text>` is interpreted as an input redirect operator, causing `zsh: parse error near '\n'`. The uppercase no-brackets convention is a widely recognized placeholder format that has no shell metacharacter collisions.

## Risks / Trade-offs

- **uv rename is a `run_once` script** → On existing machines the script has already run under the old name. The new name will be treated as a never-executed script and run again. This is safe because the script is idempotent (it self-updates if uv is already installed). No stale state risk.
- **`set -euo pipefail` in script 23** → If brew outputs a warning that causes a non-zero exit from a subshell, it could abort the script prematurely. Monitor first run after change.
- **`dotnet-sdk10` cask availability** → Assumes the tap publishes this cask. If the tap is also broken, that's a separate issue. The existing test confirms `dotnet-sdk10-0-200` doesn't exist; we haven't confirmed `dotnet-sdk10` does.

## Migration Plan

1. Remove `dotnet-sdk10-0-200` from `packages.yaml`
2. Rename the uv install script file (git mv)
3. Add `set -euo pipefail` to install-packages script
4. Update README placeholder
5. Update CLAUDE.md script ordering table (position 21 for uv, remove from 30-39)
6. Verify: `chezmoi execute-template < run_once_before_darwin-21-install-uv.sh.tmpl` produces valid output

**Rollback**: All changes are file edits tracked in git; reverting the commit restores prior state. The renamed script would need manual chezmoi state reset if rollback occurs after the new script has run.

## Open Questions

- Does `dotnet-sdk10` exist in the `isen-ng/dotnet-sdk-versions` tap? (Can be verified with `brew search isen-ng/dotnet-sdk-versions/dotnet-sdk`)
- Should `set -e` be added globally to all package scripts for consistency, or just script 23? (Out of scope for this change but worth a follow-up issue)
