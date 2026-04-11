## Context

The one-command bootstrap (`remote_install.sh` + chezmoi scripts) fails in three ways when tested on a fresh macOS VM:

1. **README placeholder**: The `export GITHUB_USERNAME="your-github-username"` example was run literally, causing chezmoi to target a non-existent GitHub repository and prompt for credentials (which GitHub rejects — password auth has been unsupported since 2021).
2. **Homebrew re-installation**: `remote_install.sh` uses `command -v brew` to detect Homebrew, but `sh -c "..."` spawns a non-login, non-interactive subprocess. `/opt/homebrew/bin` is not in PATH until the user opens a new terminal. On every re-invocation from the same terminal session, the check fails and the Homebrew installer runs again (interactively).
3. **SDKMAN bash version check**: macOS ships Bash 3.2 (GPLv2 restriction). SDKMAN's official installer hard-exits when it detects Bash < 4. The chezmoi script at position 20 runs before Homebrew packages (position 23), so modern bash is not yet available.

## Goals / Non-Goals

**Goals:**
- Make `remote_install.sh` idempotent across repeated invocations regardless of the caller's PATH
- Eliminate the SDKMAN Bash version failure on a fresh macOS machine
- Clarify the README so the bootstrap command cannot be run without substituting the username

**Non-Goals:**
- Automated GitHub SSH key or token provisioning during bootstrap
- Linux bootstrap support
- Changing the overall script execution order (positions 20–29)
- Fixing other interactive prompts during bootstrap (Homebrew ENTER prompt, Rust installer, etc.)

## Decisions

### Decision 1: Absolute-path detection in `remote_install.sh`

**Chosen**: Check `"$HOMEBREW_PREFIX/bin/brew"` directly (and similarly for chezmoi) instead of relying on `command -v brew`.

**Why**: The script already computes `$HOMEBREW_PREFIX` based on architecture. Using that path is more reliable than depending on PATH, works in non-login shells, and avoids the re-installation problem entirely. The `exec` at the bottom should also use the absolute path so the chezmoi invocation is guaranteed.

**Alternatives considered**:
- Source `~/.zprofile` before the check — fragile; `.zprofile` is zsh-specific, `sh` won't source it.
- Use `/etc/paths.d/homebrew` — `path_helper` only runs in login shells; same problem.
- Detect Homebrew via `test -x "$HOMEBREW_PREFIX/bin/brew"` — equivalent to chosen approach, slightly more explicit.

### Decision 2: Inline bash installation in the SDKMAN script

**Chosen**: In `run_once_before_darwin-20-install-sdkman.sh.tmpl`, check for `/opt/homebrew/bin/bash`. If absent, run `brew install bash` inline. Then pipe the SDKMAN installer to `/opt/homebrew/bin/bash` rather than to `bash`.

**Why**: The SDKMAN script already runs at position 20 (before Homebrew packages at 23), so we cannot rely on bash being pre-installed. An inline `brew install bash` is a one-liner, idempotent (Homebrew skips if already present), and self-contained — no ordering changes required. The shebang (`#!/bin/bash`) only affects the script itself; the key fix is the curl pipe target.

**Alternatives considered**:
- Add `bash` to `packages.yaml` and move SDKMAN to position 24 (after packages) — requires renumbering; SDKMAN currently at 20 installs before SDK setup at 24, and that ordering is intentional.
- Move SDKMAN to position 25 and shift everything — cascading renaming with no benefit.
- Use `env bash` in the curl pipe — resolves to whichever `bash` is first in PATH, which may still be 3.2. Not reliable.

### Decision 3: README rewrite for the bootstrap command

**Chosen**: Remove the `export GITHUB_USERNAME=...` pattern. Show the username substituted directly in the command, with the placeholder in angle brackets (`<your-github-username>`) to signal it must be replaced.

**Why**: The env-var pattern gave a false sense of safety — users exported the placeholder literally then used it. Angle-bracket placeholders are a widely understood convention (man pages, GitHub docs) that cannot be executed as-is without modification. The second line using `$GITHUB_USERNAME` will also be updated to inline the value.

**Alternatives considered**:
- Keep the env-var export but add a bold warning — warnings get ignored; restructuring removes the failure mode.
- Use a shell function approach — unnecessary complexity for a one-time command.

## Risks / Trade-offs

- **`brew install bash` adds a dependency** → Mitigation: Homebrew is already required and installed at this point in the bootstrap; this adds only ~5MB and is skipped on re-runs.
- **Absolute path in exec makes chezmoi non-discoverable from PATH** → Non-issue: bootstrap only runs once; the absolute path is deterministic based on architecture.
- **SDKMAN script shebang still uses `/bin/bash`** → Acceptable: the script itself only uses POSIX/Bash 3.2-compatible constructs. Only the SDKMAN installer requires Bash 4+, and it's invoked via explicit path.

## Migration Plan

All changes are backwards-compatible and safe to apply:
1. Edit `remote_install.sh` — takes effect on next invocation.
2. Edit `run_once_before_darwin-20-install-sdkman.sh.tmpl` — the `run_once` prefix means this re-runs only on a fresh machine. Existing installs are unaffected.
3. Edit `README.md` — documentation only.

No rollback strategy needed; all changes are reversible edits with no data mutation.

## Open Questions

None. All decisions are resolved.
