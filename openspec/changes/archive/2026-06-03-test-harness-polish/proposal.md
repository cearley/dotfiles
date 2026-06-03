## Why

Two UX rough edges were identified during verification of `keepassxc-mock-test-harness`: the fixture file's `_comment` key appears as a spurious entry in `ls` output, and the runner gives a confusing chezmoi error when a template path is misspelled (instead of a clear runner-level message).

## What Changes

- Filter keys starting with `_` from the mock's `ls|list` output so `_comment` (and any future metadata keys) don't appear as KeePassXC entries
- Add an explicit file-existence check in `tests/run-template` for the template file argument, producing a clear error before chezmoi is invoked

## Capabilities

### New Capabilities

<!-- none -->

### Modified Capabilities

- `template-testing`: Two usability improvements to the runner and mock binary

## Impact

- `tests/bin/keepassxc-cli`: one-line change to `ls|list` case
- `tests/run-template`: one guard clause added after arg parsing
- No behaviour change to any `keepassxcAttribute` lookup path
