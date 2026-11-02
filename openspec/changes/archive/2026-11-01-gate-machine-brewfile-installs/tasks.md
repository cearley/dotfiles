# Tasks

- [x] 1.1 Add missing-only `brew bundle check --no-upgrade --verbose` gate with y/N prompt (non-TTY → skip) before `brew bundle install --no-upgrade` in darwin-28.
- [x] 1.2 Render darwin-28 via `tests/run-template` and run `bash -n` on the output.
- [x] 1.3 Run `openspec validate gate-machine-brewfile-installs --strict`.
- [x] 1.4 Live check: `chezmoi apply` on a machine with a missing Brewfile entry shows the install prompt, and declining skips the install.
