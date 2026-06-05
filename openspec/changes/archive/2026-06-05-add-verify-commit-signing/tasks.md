## 1. Implement verify_commit_signing function

- [x] 1.1 Add `verify_commit_signing` function to `run_onchange_after_darwin-46-setup-ssh-github.sh.tmpl` after `register_github_key` and before `test_ssh_connection`
- [x] 1.2 Read `gpg.format` from global git config; print warning and return if not `ssh`
- [x] 1.3 Read `user.signingkey` from global git config; resolve leading `~` to `$HOME`; print warning and return if path is empty or file does not exist
- [x] 1.4 Run `echo "test" | ssh-keygen -Y sign -n git -f "$signingkey" -` and capture exit code; print warning with stderr on failure, success message on pass

## 2. Wire into main()

- [x] 2.1 Call `verify_commit_signing` in `main()` after `register_github_key signing` and before the `test_ssh_connection` call

## 3. Update spec

- [x] 3.1 Append the new "Commit signing verification" requirement from the delta spec into `openspec/specs/ssh-github-setup/spec.md`

## 4. Verify

- [x] 4.1 Run `chezmoi execute-template < home/.chezmoiscripts/run_onchange_after_darwin-46-setup-ssh-github.sh.tmpl` (via `tests/run-template`) to confirm the template renders without errors
- [x] 4.2 Manually confirm the rendered function logic matches all four spec scenarios
