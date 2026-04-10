## 1. Create the new script

- [x] 1.1 Create `home/.chezmoiscripts/run_onchange_after_darwin-46-setup-ssh-github.sh.tmpl` with the platform guard (`{{- if and (eq .chezmoi.os "darwin") .has_keepassxc_db -}}`) and `set -euo pipefail`
- [x] 1.2 Add template preamble: resolve `machine-settings`, extract `$sshEntryName` and `SSH_PASSPHRASE` (from KeePassXC Password field), bake in `MACHINE_NAME` via `machine-name` template
- [x] 1.3 Add `run_onchange` hash trigger: include `sha256sum` of `~/.ssh/id_ed25519.pub` as a comment in the template
- [x] 1.4 Source `shared-utils.sh` and call `require_tools gh ssh-keygen ssh-add`

## 2. Implement Phase 1 — key check and generation

- [x] 2.1 Implement `check_or_generate_key()`: skip if `~/.ssh/id_ed25519` exists; otherwise call `ssh-keygen -t ed25519 -C "$MACHINE_NAME"`
- [x] 2.2 Implement non-interactive passphrase injection via temporary `SSH_ASKPASS` script (created in `$(mktemp)`, permissions `700`, deleted after use); add `trap` for cleanup on exit
- [x] 2.3 Handle the no-KeePassXC-entry fallback: if `$sshEntryName` is empty, run `ssh-keygen` interactively without `SSH_ASKPASS`
- [x] 2.4 After generation, print a reminder to store the new key in KeePassXC
- [x] 2.5 Implement `check_key_permissions()`: warn if `~/.ssh/id_ed25519` permissions are not `600` (non-fatal)

## 3. Implement Phase 2 — SSH agent loading

- [x] 3.1 Implement `load_ssh_agent()`: compare local key fingerprint (`ssh-keygen -lf ~/.ssh/id_ed25519.pub | awk '{print $2}'`) against `ssh-add -l` output; skip if already loaded
- [x] 3.2 Run `ssh-add --apple-use-keychain ~/.ssh/id_ed25519` using the `SSH_ASKPASS` helper when passphrase is available
- [x] 3.3 Implement fallback: if `--apple-use-keychain` is unsupported (option error), retry with plain `ssh-add ~/.ssh/id_ed25519`
- [x] 3.4 Handle no-passphrase case: run `ssh-add` without `SSH_ASKPASS` and let the macOS Keychain dialog appear

## 4. Implement Phases 3 & 4 — GitHub key registration

- [x] 4.1 Implement `get_local_fingerprint()`: return the SHA256 fingerprint of `~/.ssh/id_ed25519.pub`
- [x] 4.2 Implement `is_key_registered()`: call `gh ssh-key list --json key,type`, compute fingerprints of each returned key, compare against local fingerprint for a given type (`authentication` or `signing`)
- [x] 4.3 Implement `register_github_key()`: call `gh ssh-key add ~/.ssh/id_ed25519.pub --type "$1" --title "$MACHINE_NAME"` only if `is_key_registered` returns false
- [x] 4.4 Call `register_github_key authentication` then `register_github_key signing` in `main()`

## 5. Implement Phase 5 — connectivity test

- [x] 5.1 Port `test_ssh_connection()` from the retiring 97 script: `ssh -T -o ConnectTimeout=5 -o BatchMode=yes git@github.com`
- [x] 5.2 Port `analyze_ssh_output()`: treat exit code 1 + "successfully authenticated" as success; dispatch to error helpers otherwise
- [x] 5.3 Port error helpers: `print_permission_denied_help()`, `print_network_error_help()`, `print_unknown_error_help()`
- [x] 5.4 Handle timeout exit codes (124 / 142) with a clear timeout message

## 6. Validate the new script

- [x] 6.1 Run `chezmoi execute-template < home/.chezmoiscripts/run_onchange_after_darwin-46-setup-ssh-github.sh.tmpl` and verify the output contains the resolved machine name, no raw template markers, and no passphrase leaked into the output beyond the variable assignment
- [x] 6.2 Run `shellcheck` on the expanded script output
- [x] 6.3 Run `chezmoi diff` to confirm the new script appears in the diff as a new managed file

## 7. Retire the old script

- [x] 7.1 Delete `home/.chezmoiscripts/run_onchange_after_darwin-97-test-ssh-github.sh.tmpl`
- [x] 7.2 Run `chezmoi diff` to confirm script 97 is no longer referenced
- [x] 7.3 Update `CLAUDE.md` script ordering table: replace "97: SSH test" with "46: SSH GitHub setup"
