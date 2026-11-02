# Tasks

- [x] 1.1 Gate the upgrade prompt in darwin-23 and darwin-28 on `brew bundle check --no-upgrade` passing first; print a skip notice otherwise.
- [x] 1.2 darwin-23: write the combined Brewfile once to a temp file (`trap` cleanup) and reuse it for both checks and the upgrade.
- [x] 1.3 Render both scripts via `tests/run-template` and `bash -n` the output.
- [x] 1.4 Exercise the gate against real Brewfiles: studio + nonexistent formula → skip; studio as committed → nothing to do; darwin-23 combined set → upgrade prompt offered (genuinely outdated packages).
- [x] 1.5 Run `openspec validate skip-upgrade-prompt-when-missing --strict`.
