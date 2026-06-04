## 1. Fix darwin-24 script

- [x] 1.1 In `home/.chezmoiscripts/run_onchange_before_darwin-24-install-sdks.sh.tmpl`, add `set +u` before `source sdkman-init.sh` and `set -u` after, with a comment explaining the `$ZSH_VERSION` issue
- [x] 1.2 Verify the change renders correctly: `tests/run-template home/.chezmoiscripts/run_onchange_before_darwin-24-install-sdks.sh.tmpl`

## 2. Update script-execution spec

- [x] 2.1 Apply the delta from `openspec/changes/fix-sdkman-init-nounset-error/specs/script-execution/spec.md` into `openspec/specs/script-execution/spec.md` (add the new requirement under "Strict Error Mode in run_onchange Scripts")

## 3. Archive the change

- [x] 3.1 Run `openspec archive fix-sdkman-init-nounset-error --yes` to move the change to the archive
