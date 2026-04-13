## Context

`darwin-23-install-packages.sh.tmpl` runs `brew bundle --file=/dev/stdin` with a heredoc containing all tag-selected packages. The script uses `set -euo pipefail`, so any non-zero exit from `brew bundle` immediately kills the script.

`brew bundle` fails the entire run if any single package cannot be downloaded — even if 90 others were fetched successfully. The net result: the pre-fetch phase populates the Homebrew cache but the install phase never runs. A fresh machine gets zero packages installed.

The failing package in the observed test (`postman`) had a DNS resolution failure for `dl.pstmn.io`. This is an external dependency outside our control.

## Goals / Non-Goals

**Goals:**
- Ensure all successfully-downloadable packages are installed even when one fails
- Surface a clear, actionable warning when partial failure occurs
- Keep the change minimal and contained to one file

**Non-Goals:**
- Automatic retry of failed packages
- Pre-flight network checks per-package
- Removal of any specific packages from `packages.yaml`
- Changing how `brew bundle` is invoked (still uses `--file=/dev/stdin` with heredoc)

## Decisions

### Decision: Capture exit code rather than suppress error

**Chosen**: Assign the `brew bundle` exit code to a variable using `|| brew_exit=$?`, then check and warn after the call returns.

```bash
brew_exit=0
brew bundle --file=/dev/stdin <<'BUNDLE_EOF' || brew_exit=$?
  ... packages ...
BUNDLE_EOF

if [ "$brew_exit" -ne 0 ]; then
    print_message "warning" "brew bundle completed with errors — some packages may not be installed."
    print_message "info" "Run 'chezmoi apply' again after resolving the issue."
fi
```

**Why not `|| true`**: Silent — gives no feedback that anything failed. A user wouldn't know to re-run.

**Why not removing `set -euo pipefail`**: The flag exists to catch real script bugs (missing files, bad commands). Removing it would reduce safety across the whole script. Scoped error handling is better.

**Why not splitting into per-package `brew install` calls**: ~90 packages would need individual calls, losing `brew bundle`'s parallel fetch, dependency resolution, and cask handling. Complexity outweighs the benefit.

**Why not `set +e` around the call**: `set +e` disables the trap globally for that subshell context; the `|| brew_exit=$?` pattern is more explicit and surgical.

### Decision: Warn-and-continue, not warn-and-fail

The bootstrap's job is to get the machine to a usable state as quickly as possible. Aborting for one optional cask (e.g., Postman) leaves the machine in a worse state than continuing. The user can always re-run `chezmoi apply` once the issue is resolved.

### Decision: No spec change for `dotnet-sdk6` / `dotnet-sdk8`

These virtual casks appeared in the Brewfile but were not individually confirmed in the fetch output. They resolved correctly (they're aliases to the versioned `-0-400` casks). No change needed.

## Risks / Trade-offs

- **Silent skip of failed packages**: A user who ignores the warning may not realize certain packages are missing until they need them. Mitigation: the warning message explicitly names the recovery action (`chezmoi apply`).
- **`brew bundle` exit code interpretation**: Non-zero can mean download failure, formula conflict, or cask quarantine issue. We treat all non-zero exits the same way (warn). This is acceptable — `brew bundle` output already describes what failed.
- **Heredoc quoting**: The heredoc delimiter is changed from bare `EOF` to quoted `'BUNDLE_EOF'` to prevent accidental shell expansion in the package list. This is a minor defensive improvement with no behavior change on normal Brewfiles.

## Migration Plan

1. Edit `darwin-23-install-packages.sh.tmpl` — wrap the `brew bundle` call with exit-code capture
2. Update `openspec/specs/package-management/spec.md` — add a requirement for partial failure resilience
3. Run `chezmoi execute-template` on the modified script to verify template output is valid
4. Test on VM to confirm partial failure no longer aborts the install

Rollback: Revert the single-file edit. No state changes on the target machine (Homebrew packages are not automatically removed).
