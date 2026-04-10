## ADDED Requirements

### Requirement: SSH key presence check
The script SHALL verify that `~/.ssh/id_ed25519` exists before proceeding to later phases. If the file is present, key generation SHALL be skipped.

#### Scenario: Key file already deployed by chezmoi
- **WHEN** `~/.ssh/id_ed25519` exists on disk
- **THEN** the script SHALL skip key generation and proceed to Phase 2 (SSH agent)

#### Scenario: Key file missing
- **WHEN** `~/.ssh/id_ed25519` does not exist
- **THEN** the script SHALL generate a new ed25519 key and proceed

### Requirement: SSH key generation with passphrase
When no key file exists, the script SHALL generate a new `ed25519` key. The `-C` comment SHALL be set to the machine name (baked in at template time). If a KeePassXC SSH entry exists for the machine, the passphrase SHALL be sourced from KeePassXC non-interactively. If no KeePassXC entry exists, the script SHALL run `ssh-keygen` interactively and allow the user to enter a passphrase manually. After generation, the script SHALL print a reminder to store the new key in KeePassXC.

#### Scenario: KeePassXC entry available
- **WHEN** the machine has a KeePassXC SSH entry with a Password field
- **THEN** the script SHALL generate the key non-interactively using the KeePassXC passphrase via `SSH_ASKPASS`

#### Scenario: No KeePassXC entry
- **WHEN** no KeePassXC SSH entry is found for the machine
- **THEN** the script SHALL run `ssh-keygen` interactively, prompting the user for a passphrase
- **THEN** the script SHALL print a reminder to store the key in KeePassXC after generation

### Requirement: SSH key permission check
After confirming the key exists, the script SHALL check that `~/.ssh/id_ed25519` has permissions `600`. If permissions are incorrect, the script SHALL print a warning and the fix command (`chmod 600`).

#### Scenario: Correct permissions
- **WHEN** `~/.ssh/id_ed25519` has permissions `600`
- **THEN** the script SHALL proceed silently

#### Scenario: Incorrect permissions
- **WHEN** `~/.ssh/id_ed25519` has permissions other than `600`
- **THEN** the script SHALL print a warning message and the fix command, then continue (non-fatal)

### Requirement: SSH agent loading with macOS Keychain
The script SHALL ensure the SSH key is loaded in the SSH agent. If the key is already loaded (fingerprint present in `ssh-add -l` output), loading SHALL be skipped. If not loaded, the script SHALL run `ssh-add --apple-use-keychain ~/.ssh/id_ed25519` to load the key and store the passphrase in macOS Keychain. The passphrase SHALL be provided non-interactively via a temporary `SSH_ASKPASS` script when the KeePassXC passphrase is available. The temporary `SSH_ASKPASS` file SHALL be deleted immediately after use, and a `trap` SHALL ensure cleanup on unexpected exit.

#### Scenario: Key already in agent
- **WHEN** the key fingerprint is present in `ssh-add -l`
- **THEN** the script SHALL skip `ssh-add` and print a skip message

#### Scenario: Key not in agent, KeePassXC passphrase available
- **WHEN** the key is not loaded and a KeePassXC passphrase is available
- **THEN** the script SHALL create a temporary `SSH_ASKPASS` script, run `ssh-add --apple-use-keychain`, then delete the temporary file

#### Scenario: Key not in agent, no passphrase available
- **WHEN** the key is not loaded and no KeePassXC passphrase is available
- **THEN** the script SHALL run `ssh-add` without `SSH_ASKPASS`, allowing the macOS Keychain dialog to appear

#### Scenario: `--apple-use-keychain` not supported
- **WHEN** `ssh-add --apple-use-keychain` fails with an unsupported option error
- **THEN** the script SHALL fall back to plain `ssh-add ~/.ssh/id_ed25519`

### Requirement: GitHub authentication key registration
The script SHALL register the SSH public key with GitHub as an `authentication` key using `gh ssh-key add ~/.ssh/id_ed25519.pub --type authentication`. Before adding, the script SHALL compare the local key fingerprint against all authentication keys returned by `gh ssh-key list`. If the key is already registered, the `gh ssh-key add` call SHALL be skipped. The GitHub key title SHALL be the machine name baked in at template time.

#### Scenario: Key not yet registered as authentication key
- **WHEN** the local key fingerprint is not found in `gh ssh-key list` for type `authentication`
- **THEN** the script SHALL call `gh ssh-key add --type authentication --title "<machine-name>"`
- **THEN** the script SHALL print a success message

#### Scenario: Key already registered as authentication key
- **WHEN** the local key fingerprint is already present in `gh ssh-key list` for type `authentication`
- **THEN** the script SHALL skip registration and print a skip message

### Requirement: GitHub signing key registration
The script SHALL register the SSH public key with GitHub as a `signing` key using `gh ssh-key add ~/.ssh/id_ed25519.pub --type signing`. Idempotency and title rules are identical to the authentication key requirement. Both registration phases use the same `.pub` file.

#### Scenario: Key not yet registered as signing key
- **WHEN** the local key fingerprint is not found in `gh ssh-key list` for type `signing`
- **THEN** the script SHALL call `gh ssh-key add --type signing --title "<machine-name>"`
- **THEN** the script SHALL print a success message

#### Scenario: Key already registered as signing key
- **WHEN** the local key fingerprint is already present in `gh ssh-key list` for type `signing`
- **THEN** the script SHALL skip registration and print a skip message

### Requirement: GitHub SSH connectivity verification
After all registration phases, the script SHALL test the SSH connection to `git@github.com`. GitHub returns exit code 1 on successful authentication (no shell access); the script SHALL treat exit code 1 with "successfully authenticated" in the output as success. On timeout, permission denied, or network errors, the script SHALL print an actionable error message.

#### Scenario: Successful connection
- **WHEN** `ssh -T git@github.com` exits with code 1 and output contains "successfully authenticated"
- **THEN** the script SHALL print a success message and exit 0

#### Scenario: Connection timeout
- **WHEN** the SSH command times out after the configured timeout period
- **THEN** the script SHALL print a timeout error message with network troubleshooting steps

#### Scenario: Permission denied
- **WHEN** the SSH output contains "Permission denied"
- **THEN** the script SHALL print a permission-denied error with steps to add the key to GitHub

#### Scenario: Network error
- **WHEN** the SSH output contains "Could not resolve hostname" or "Connection refused"
- **THEN** the script SHALL print a network error message with DNS/firewall troubleshooting steps

### Requirement: Script re-run trigger
The script SHALL be a `run_onchange_after` script. The template SHALL include a hash of `~/.ssh/id_ed25519.pub` as a comment, so that chezmoi re-runs the script whenever the deployed public key changes.

#### Scenario: Public key unchanged
- **WHEN** chezmoi applies and the public key hash is unchanged
- **THEN** the script SHALL NOT re-run

#### Scenario: Public key changed
- **WHEN** chezmoi applies and the public key hash has changed (new key deployed from KeePassXC)
- **THEN** the script SHALL re-run all phases

### Requirement: Prerequisite tool check
The script SHALL verify that `gh` and `ssh-keygen` and `ssh-add` are available before proceeding. If any required tool is missing, the script SHALL exit with a clear error message.

#### Scenario: All tools present
- **WHEN** `gh`, `ssh-keygen`, and `ssh-add` are all available
- **THEN** the script SHALL proceed normally

#### Scenario: Missing tool
- **WHEN** any required tool is not found
- **THEN** the script SHALL exit with a non-zero status and print which tool is missing
