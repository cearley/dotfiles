## Why

The one-command bootstrap (`remote_install.sh`) fails in three distinct ways on a fresh macOS VM: the README placeholder causes misdirected clone attempts, Homebrew re-installs on every run due to PATH not being set in the `sh -c` subprocess, and the SDKMAN installer exits immediately because macOS ships Bash 3.2 while SDKMAN requires Bash 4+. Together, these make a successful first-run bootstrap impossible without manual intervention.

## What Changes

- **README**: Replace the literal `export GITHUB_USERNAME="your-github-username"` placeholder pattern with a direct, unambiguous invocation format that cannot be run without substitution.
- **`remote_install.sh`**: Use absolute paths (`$HOMEBREW_PREFIX/bin/brew`, `$HOMEBREW_PREFIX/bin/chezmoi`) for existence checks and the final `exec`, so bootstrap is PATH-independent and idempotent across repeated invocations.
- **`run_once_before_darwin-20-install-sdkman.sh.tmpl`**: Ensure a Bash 4+ binary is available before invoking the SDKMAN installer, and pipe to that binary rather than the system `bash`. Install Homebrew's `bash` package inline if the modern binary is absent.

## Capabilities

### New Capabilities

None. These are correctness fixes to existing bootstrap behaviour.

### Modified Capabilities

- `package-management`: SDKMAN installation now has an explicit Bash 4+ prerequisite that is satisfied inline (no ordering change, no user-visible behaviour change — SDKMAN still installs at position 20).

## Impact

- `remote_install.sh` — logic change only; no interface change
- `home/.chezmoiscripts/run_once_before_darwin-20-install-sdkman.sh.tmpl` — adds one `brew install bash` step; idempotent (skipped if `/opt/homebrew/bin/bash` already exists)
- `README.md` — documentation only
- Tags affected: `dev` (SDKMAN is gated on the `dev` tag)
- No secrets, SIP restrictions, or permission changes involved
- No breaking changes

### Non-goals

- Automated GitHub authentication (SSH key setup, token management) during bootstrap — that is handled post-clone by existing scripts.
- Linux bootstrap support.
- Changing the script execution order (positions 20–29 remain unchanged).
