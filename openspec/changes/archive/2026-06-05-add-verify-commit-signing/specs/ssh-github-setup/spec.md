## ADDED Requirements

### Requirement: Commit signing verification
After registering the GitHub signing key, the script SHALL verify that git's SSH commit signing configuration is correct and that the local SSH agent can produce a valid signature. The script SHALL read `user.signingkey` from global git config, resolve any leading `~` to `$HOME`, confirm the key file exists and is readable, and then invoke `ssh-keygen -Y sign -n git -f <keyfile> -` on a throwaway string. If any check fails, the script SHALL print a `warning` message identifying the specific failure and continue (non-fatal). If all checks pass, the script SHALL print a `success` message.

#### Scenario: All signing checks pass
- **WHEN** `git config --global gpg.format` returns `ssh`
- **AND** `git config --global user.signingkey` returns a path that resolves to an existing readable file
- **AND** `ssh-keygen -Y sign -n git -f <keyfile> -` exits 0 on a throwaway input
- **THEN** the script SHALL print a success message confirming commit signing is operational

#### Scenario: gpg.format is not ssh
- **WHEN** `git config --global gpg.format` does not return `ssh` (or is unset)
- **THEN** the script SHALL print a warning message identifying `gpg.format` as misconfigured and return without running `ssh-keygen`

#### Scenario: user.signingkey is unset or file missing
- **WHEN** `git config --global user.signingkey` is empty or the resolved path does not exist on disk
- **THEN** the script SHALL print a warning message naming the missing key path and return without running `ssh-keygen`

#### Scenario: ssh-keygen signing fails
- **WHEN** `git config --global gpg.format` is `ssh` and the key file exists
- **AND** `ssh-keygen -Y sign -n git -f <keyfile> -` exits non-zero
- **THEN** the script SHALL print a warning message with the `ssh-keygen` error output and suggest running `ssh-add` to ensure the key is loaded in the agent
