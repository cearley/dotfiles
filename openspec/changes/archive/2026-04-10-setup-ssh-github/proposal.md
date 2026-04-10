## Why

The dotfiles repo deploys SSH key files and SSH config for GitHub, but never registers those keys with GitHub or loads them into the SSH agent — leaving every new or re-provisioned machine requiring manual steps to become fully operational. A chezmoi script at position 46 closes this gap and replaces the existing connectivity-only test script (97).

## What Changes

- **New script** `run_onchange_after_darwin-46-setup-ssh-github.sh.tmpl`: checks for the SSH key, generates one if missing, loads it into the SSH agent via macOS Keychain, registers it with GitHub as both an authentication key and a signing key, and verifies connectivity.
- **Delete** `run_onchange_after_darwin-97-test-ssh-github.sh.tmpl`: its connectivity test and error-handling logic are absorbed into the new script.
- No changes to managed SSH key files (`private_id_ed25519.tmpl`, `id_ed25519.pub.tmpl`) or `~/.ssh/config`.
- No changes to `.gitconfig.tmpl` (SSH signing already configured there).

## Capabilities

### New Capabilities

- `ssh-github-setup`: End-to-end setup of an SSH key for GitHub — key presence check/generation, SSH agent loading with macOS Keychain integration, GitHub authentication key registration, GitHub signing key registration, and connectivity verification. Passphrase sourced from KeePassXC; machine name baked in at template time as the GitHub key title.

### Modified Capabilities

*(none — existing specs' requirements are unchanged)*

## Impact

- **Scripts affected**: `run_onchange_after_darwin-46-setup-ssh-github.sh.tmpl` (new), `run_onchange_after_darwin-97-test-ssh-github.sh.tmpl` (deleted)
- **Dependencies**: `gh` CLI (authenticated at step 45), KeePassXC (passphrase + optional key deployment), `ssh-keygen`, `ssh-add`
- **Security**: Passphrase baked into script via `keepassxc` template function at expand time — never stored in the git repo. Temporary `SSH_ASKPASS` helper deleted immediately after use.
- **Tags affected**: All tags (SSH setup is universal across machine profiles)
- **Non-goals**: Linux/Windows support (macOS only for now); storing generated keys back into KeePassXC automatically; managing multiple SSH keys per machine.
