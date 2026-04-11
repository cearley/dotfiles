## 1. Fix `remote_install.sh` Homebrew Detection

- [x] 1.1 Replace `command -v brew` check with `test -x "$HOMEBREW_PREFIX/bin/brew"` so detection is PATH-independent
- [x] 1.2 Replace `command -v chezmoi` check with `test -x "$HOMEBREW_PREFIX/bin/chezmoi"` for the same reason
- [x] 1.3 Change `chezmoi=chezmoi` to `chezmoi="$HOMEBREW_PREFIX/bin/chezmoi"` so the final `exec` uses an absolute path
- [ ] 1.4 Verify idempotency: run the script twice in the same terminal session (without opening a new shell) and confirm Homebrew install is skipped on the second run  *(manual VM test — deferred)*

## 2. Fix SDKMAN Script — Bash 4+ Prerequisite

- [x] 2.1 In `home/.chezmoiscripts/run_once_before_darwin-20-install-sdkman.sh.tmpl`, add a check for `/opt/homebrew/bin/bash` before the SDKMAN installer curl
- [x] 2.2 If `/opt/homebrew/bin/bash` is absent, run `brew install bash` using `print_message "info"` for consistent output
- [x] 2.3 Change the SDKMAN installer invocation from `curl -s "https://get.sdkman.io" | bash` to `curl -s "https://get.sdkman.io" | /opt/homebrew/bin/bash`
- [x] 2.4 Verify template renders correctly: `cat home/.chezmoiscripts/run_once_before_darwin-20-install-sdkman.sh.tmpl | chezmoi execute-template`

## 3. Update README Bootstrap Instructions

- [x] 3.1 Replace the `export GITHUB_USERNAME="your-github-username"` + two-line pattern with a single command using an angle-bracket placeholder: `sh -c "$(curl -fsSL https://raw.githubusercontent.com/cearley/dotfiles/main/remote_install.sh)" -- init --apply <your-github-username>`
- [x] 3.2 Update the verbose variant (`--keep-going --verbose`) to use the same angle-bracket format
- [x] 3.3 Confirm the Requirements section accurately reflects that Xcode CLT is no longer a hard prerequisite (Homebrew now installs it automatically)
