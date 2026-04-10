## Context

The dotfiles repo currently deploys `~/.ssh/id_ed25519` and `~/.ssh/id_ed25519.pub` from KeePassXC via chezmoi templates, and `~/.ssh/config` already contains the `UseKeychain yes` / `AddKeysToAgent yes` block for `github.com`. Git signing is configured in `dot_gitconfig.tmpl`. What's missing is a script that:
1. Ensures the key exists on disk (generating one if needed for a new machine)
2. Loads it into the SSH agent with the passphrase stored in macOS Keychain
3. Registers it with GitHub as both an authentication key and a signing key
4. Verifies the connection works

The existing script at position 97 tests connectivity but does none of the above setup. The GitHub auth script at position 45 handles PAT/GHCR/CLI auth and runs before this new script.

## Goals / Non-Goals

**Goals:**
- Idempotent SSH key setup: safe to re-run on every `chezmoi apply`
- Key generation fallback for new machines without a KeePassXC entry
- Non-interactive passphrase handling via `SSH_ASKPASS` (passphrase from KeePassXC)
- Register the key on GitHub as both `authentication` and `signing` types
- Absorb the connectivity test from the retiring 97 script
- Machine name baked in at template time as the GitHub key title

**Non-Goals:**
- Linux or Windows support (macOS only for now)
- Automatic round-trip of generated keys back into KeePassXC
- Managing multiple SSH keys per machine
- Rotating or revoking existing GitHub SSH keys

## Decisions

### Decision 1: Single script at position 46 (not split into setup + test)

The five phases (check/generate, agent, auth registration, signing registration, verify) form one logical workflow. Splitting into two scripts (46 + 47) adds a file without meaningful isolation — the test is only useful after setup and shares the same re-run trigger. A single script is simpler to maintain.

*Alternative considered:* Add SSH key registration to the existing 45 script. Rejected — 45 already handles PAT/GHCR/CLI concerns; mixing SSH key management further reduces cohesion and makes it harder to re-trigger independently.

### Decision 2: Passphrase baked in via KeePassXC template function

The passphrase is resolved at `chezmoi apply` time via `(keepassxc $sshEntryName).Password` — the same pattern used for `GH_PAT` in the 45 script. The git-tracked template source never contains the passphrase; the expanded script that runs is ephemeral. A temporary `SSH_ASKPASS` helper script is written, used, and deleted within the same function call.

*Alternative considered:* Let macOS show the Keychain dialog interactively. Rejected — `chezmoi apply` is designed to be non-interactive; relying on a GUI dialog breaks headless/automated provisioning.

### Decision 3: Idempotency via fingerprint comparison, not title matching

Before calling `gh ssh-key add`, the script compares the fingerprint of the local key (`ssh-keygen -lf`) against the fingerprint list returned by `gh ssh-key list --json key,type`. This is authoritative — GitHub key titles can be duplicated or changed, but fingerprints are stable.

### Decision 4: Hash public key file as the `run_onchange` trigger

The script hashes `~/.ssh/id_ed25519.pub` (already on disk, deterministic) rather than the private key. If the public key changes, the private key certainly changed. This avoids unnecessary reads of the private key file and is consistent with the 97 script's approach.

### Decision 5: Key generation uses machine name as `-C` comment

When generating a new key, the comment (`-C`) is set to the machine name (baked in at template time). This makes the key identifiable in `ssh-add -l` output and on GitHub's key list.

## Risks / Trade-offs

- **`gh` auth required at runtime** → The script runs at position 46, after `gh` auth is configured at 45. However, if the user runs this script in isolation without a valid `gh` session, it will fail at Phases 3/4. Mitigation: `require_tools gh` check at script start; clear error message if `gh` is not authenticated.

- **Generated key not stored in KeePassXC** → If the machine has no KeePassXC SSH entry and the script generates a fresh key, that key lives only on disk. If the machine is lost or wiped, the key is gone. Mitigation: the script prints an explicit reminder to store the key in KeePassXC after generation.

- **`SSH_ASKPASS` + temp file** → A temporary script containing the passphrase is written to disk briefly. It's created in a temp directory with 0700 permissions and deleted immediately after `ssh-add`. Mitigation: `trap` ensures cleanup on exit/error.

- **`--apple-use-keychain` not available on older macOS** → If the macOS SSH build predates the flag, `ssh-add` errors. Mitigation: fall back to plain `ssh-add` (the macOS Keychain dialog will appear once; subsequent uses are silent via `UseKeychain yes` in config).

## Migration Plan

1. Add new `run_onchange_after_darwin-46-setup-ssh-github.sh.tmpl`
2. Delete `run_onchange_after_darwin-97-test-ssh-github.sh.tmpl`
3. Run `chezmoi apply` — the new script executes, 97 is gone
4. No rollback complexity: both files are in source control; reverting is a git revert

## Open Questions

*(none — all decisions resolved in design review)*
