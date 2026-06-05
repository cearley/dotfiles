## Context

`run_onchange_after_darwin-46-setup-ssh-github.sh.tmpl` already registers the SSH public key on GitHub as both an authentication key and a signing key. However, it never validates that git's signing configuration is correct or that the local SSH agent can actually produce a valid signature. Misconfiguration in `.gitconfig` (wrong `gpg.format`, stale or missing `user.signingkey` path) would go undetected.

The fix is a lightweight `verify_commit_signing` function added at the end of `main()`, after `register_github_key signing` and before the SSH connectivity test.

## Goals / Non-Goals

**Goals:**
- Detect misconfigured git signing config (`gpg.format`, `user.signingkey`)
- Exercise `ssh-keygen -Y sign` to confirm the SSH agent can produce signatures
- Emit actionable error messages pointing at the specific misconfiguration
- Produce a `success` message when everything is correctly wired

**Non-Goals:**
- Does not create a test commit or push anything to GitHub
- Does not validate the "Verified" badge on GitHub (that requires a push)
- Does not support GPG/classic PGP signing (project uses SSH signing)
- Does not check repo-level `commit.gpgsign` overrides (global config only)

## Decisions

### Non-fatal on verification failure

The function prints a `warning` (not `error`) and returns non-zero from the inner check, but `main()` continues. This mirrors the key-permission check: signing verification is a sanity check, not a hard requirement for the SSH agent/auth setup to have value.

**Alternative considered**: Fatal exit. Rejected because a correctly registered key and working SSH auth are still valuable even if the git config verification step fails (e.g., on a machine where the gitconfig hasn't been applied yet).

### Use `ssh-keygen -Y sign` not a real git commit

`ssh-keygen -Y sign -n git -f <key> -` signs stdin using the same namespace git uses. This exercises the exact code path git calls when signing commits, without touching any repo or remote.

**Alternative considered**: `git commit --dry-run` with signing enabled — rejected because `git commit --dry-run` does not exercise signing even with `gpg.sign = true`.

### Read `user.signingkey` from global git config

The function reads `git config --global user.signingkey` to get the key path. This matches what git itself reads for signing and avoids hardcoding the path.

### Resolve `~` in signingkey path

Git allows `~` in the `user.signingkey` path but `ssh-keygen -Y sign -f` requires an absolute path. The function replaces a leading `~` with `$HOME` before passing to `ssh-keygen`.

## Risks / Trade-offs

- **Agent not loaded**: If `ssh-add` has not loaded the key, `ssh-keygen -Y sign` will prompt for the passphrase or fail silently. Mitigation: `verify_commit_signing` runs after `load_ssh_agent`, so the key should be in-agent by this point.
- **`ssh-keygen` version differences**: The `-Y sign` flag requires OpenSSH 8.0+. macOS ships a sufficiently recent version, but the function should check the exit code rather than parse version strings. Mitigation: treat any non-zero exit from `ssh-keygen -Y sign` as a failure with a message to check `ssh-keygen` version.
- **Passphrase-protected key without agent**: On a fresh bootstrap before `load_ssh_agent` runs successfully, signing will fail. This is expected; the warning message should suggest running `ssh-add` first.
