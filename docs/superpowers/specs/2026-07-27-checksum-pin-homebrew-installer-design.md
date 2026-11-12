# Checksum-Pin the Homebrew Installer in `remote_install.sh` — Design

## Context

An audit of this repo against an external "AI-aware dotfiles" article's five-pillar
framework flagged the SLSA/Sigstore-provenance pillar as the biggest gap: the
one-command bootstrap (`remote_install.sh`) fetches and executes Homebrew's official
installer with no integrity verification —

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

`HEAD` here means the tip of Homebrew/install's default branch — a moving target with
nothing stable to checksum against. This design pins that reference and adds an
integrity check before execution.

## Constraint

`remote_install.sh` is fetched **standalone**, before any repo clone exists — the
documented usage is `sh -c "$(curl -fsSL https://raw.githubusercontent.com/cearley/dotfiles/remote_install.sh)"`.
Only this one file crosses the network at that point, so the pinned commit SHA and its
checksum must live inline in `remote_install.sh` itself — no external data file is
reachable at that stage.

## Decision

**Manual, documented bump strategy.** Pin a specific Homebrew/install commit SHA and
the SHA256 of that exact commit's `install.sh`, both inline. A comment directly above
the pin gives the exact regeneration command. Updates happen on the user's own
schedule, with the diff reviewed each time — no Renovate automation. This matches the
low change-frequency of Homebrew's installer and keeps the mechanism simple and fully
auditable for a single-user repo, rather than adding a custom Renovate regex manager
plus a checksum-recompute CI step to track it automatically.

## Components

All inline in `remote_install.sh`, in the `Darwin)` case branch, replacing the current
Homebrew-install block:

```sh
# Pinned to a specific Homebrew/install commit (not HEAD, which moves) so its
# content can be checksummed. To bump to a newer installer:
#   1. Pick a commit from https://github.com/Homebrew/install/commits/HEAD
#   2. curl -fsSL https://raw.githubusercontent.com/Homebrew/install/<sha>/install.sh | shasum -a 256
#   3. Update both values below and review the diff of installer behavior.
HOMEBREW_INSTALL_SHA="<pinned commit SHA — filled in at implementation time>"
HOMEBREW_INSTALL_SHA256="<sha256 of that commit's install.sh — filled in at implementation time>"

if ! test -x "$HOMEBREW_PREFIX/bin/brew"; then
    echo "Installing Homebrew..."
    installer=$(curl -fsSL "https://raw.githubusercontent.com/Homebrew/install/${HOMEBREW_INSTALL_SHA}/install.sh")
    actual_sha256=$(printf '%s' "$installer" | shasum -a 256 | cut -d' ' -f1)
    if [ "$actual_sha256" != "$HOMEBREW_INSTALL_SHA256" ]; then
        echo "❌ Homebrew installer checksum mismatch — refusing to run it"
        echo "   expected: $HOMEBREW_INSTALL_SHA256"
        echo "   actual:   $actual_sha256"
        exit 1
    fi
    /bin/bash -c "$installer"
    (
        echo
        echo "eval \"\$($HOMEBREW_PREFIX/bin/brew shellenv)\""
    ) >>"$HOME"/.zprofile
    eval "$($HOMEBREW_PREFIX/bin/brew shellenv)"
    echo "Homebrew installed successfully!"
fi
```

The actual pinned SHA and checksum values are determined at implementation time by
running the two-step regeneration command above against the current tip of
Homebrew/install, not left as an open design question — the mechanism, not the value,
is what this spec fixes.

## Data Flow

```
remote_install.sh runs (Darwin, Homebrew not yet installed)
  → curl fetches install.sh from the pinned commit SHA (not HEAD)
  → compute SHA256 of fetched content
  → matches HOMEBREW_INSTALL_SHA256?
      yes → execute via /bin/bash -c
      no  → print expected vs. actual, exit 1, do not execute
```

## Error Handling

Fail closed, no override, no interactive prompt. This runs at the very start of
bootstrap before anything is installed — there is nothing to roll back and no
legitimate reason to execute content that doesn't match the pin. A genuine staleness
issue is resolved by deliberately re-pinning (the documented bump command above), not
by bypassing the check in place.

## Side Benefit

`ci.yml`'s `test_remote_install` job currently exercises whatever `HEAD` happens to be
on the day CI runs, so an unrelated upstream change to Homebrew's installer could fail
CI for reasons unconnected to any change in this repo. Pinning removes that source of
flakiness — CI now exercises a fixed, known-good installer version until the pin is
deliberately bumped. No change to `ci.yml` itself is required.

## Testing

- Run the updated `remote_install.sh` against the real pinned SHA/checksum and confirm
  Homebrew installs successfully (happy path; also validates the pin is correct at
  implementation time).
- Temporarily corrupt `HOMEBREW_INSTALL_SHA256` and confirm the script aborts with
  exit 1, prints expected-vs-actual, and does not execute the installer.
- Confirm `ci.yml`'s `test_remote_install` job still passes unmodified.

## Out of Scope

- Checksumming `chezmoi` itself or any other tool `remote_install.sh` installs via
  Homebrew (`brew install chezmoi`) — Homebrew's own package integrity model covers
  that once `brew` itself is trusted; only the bootstrap-before-Homebrew-exists step
  lacked verification.
- Automated (Renovate-driven) pin bumping — explicitly rejected in favor of manual,
  reviewed bumps for this repo's scale.
- Linux/WSL bootstrap — `remote_install.sh` already exits early with "not implemented"
  for Linux, unchanged by this design.
