## 1. Script Change

- [x] 1.1 In `home/.chezmoiscripts/run_onchange_before_darwin-23-install-packages.sh.tmpl`, replace the unguarded `brew update && brew bundle --file=/dev/stdin <<EOF` call with a version that captures the exit code: initialize `brew_exit=0`, run `brew bundle ... || brew_exit=$?`, then check and warn if `brew_exit` is non-zero
- [x] 1.2 Quote the heredoc delimiter (`'BUNDLE_EOF'` instead of bare `EOF`) to prevent accidental shell expansion in the package list

## 2. Verification

- [x] 2.1 Run `chezmoi execute-template < home/.chezmoiscripts/run_onchange_before_darwin-23-install-packages.sh.tmpl` and confirm the rendered script is valid shell (no template errors)
- [x] 2.2 Visually confirm the rendered script contains `brew_exit=0`, the `|| brew_exit=$?` guard, and the warning `print_message` call

## 3. Spec Update

- [x] 3.1 Merge the delta from `openspec/changes/brew-bundle-resilient-failures/specs/package-management/spec.md` into `openspec/specs/package-management/spec.md` — add the three new scenarios under a new "Homebrew Bundle Partial Failure Resilience" requirement
