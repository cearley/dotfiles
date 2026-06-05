## Why

The darwin-46 SSH setup script registers the SSH key as both an authentication and signing key on GitHub, but never verifies that commit signing itself is correctly wired end-to-end. Git signing config (`gpg.format`, `user.signingkey`) could be misconfigured without the script detecting it, leaving users with registered keys that still can't sign commits.

## What Changes

- Add a `verify_commit_signing` function to `run_onchange_after_darwin-46-setup-ssh-github.sh.tmpl` that runs after `register_github_key signing`
- The function checks three things without making any commits or network writes:
  1. `git config gpg.format` is `ssh`
  2. `git config user.signingkey` resolves to an existing, readable public key file
  3. `ssh-keygen -Y sign` can produce a valid signature using that key (dry-run, signs a throwaway string)
- On failure, the function prints an actionable error message pointing to the misconfiguration
- On success, prints a `success` message confirming end-to-end signing readiness

## Capabilities

### New Capabilities

*(none)*

### Modified Capabilities

- `ssh-github-setup`: Add a commit-signing verification phase after signing key registration. New requirement: after registering the signing key, the script SHALL verify git's SSH signing config and exercise `ssh-keygen -Y sign` to confirm the full signing pipeline is operational.

## Impact

- **Modified file**: `home/.chezmoiscripts/run_onchange_after_darwin-46-setup-ssh-github.sh.tmpl`
- **Modified spec**: `openspec/specs/ssh-github-setup/spec.md` — one new requirement block added
- **No secrets involved**: signing verification uses only the public key and key already loaded in the agent
- **Tags affected**: any machine running the darwin-46 script (requires `has_keepassxc_db` and macOS)
- **Non-goals**: does not validate that GitHub's "verified" badge appears on past commits; does not test GPG (classic PGP) signing; does not create a test commit or push anything
