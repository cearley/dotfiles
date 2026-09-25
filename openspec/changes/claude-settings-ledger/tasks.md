# Tasks

## 1. Pre-implementation check

- [ ] 1.1 In a throwaway `CLAUDE_CONFIG_DIR` (a scratch copy of `~/.claude-personal`, never the live directory), add a top-level `"_chezmoiManaged": []` key, start `claude`, and run `/doctor`. Verify there is no settings validation error, and that saving a change through `/permissions` keeps the key. If either check fails, switch design D1 to the `env.CHEZMOI_CLAUDE_MANAGED` fallback and update the spec's ledger scenario before continuing.
- [ ] 1.2 Confirm `claude-tooling-plugin` has landed: the modifier contains only the legacy-hook removal plus `. * $extra`. Verify with `grep -c 'managed_hooks' home/.chezmoitemplates/claude-settings-hooks-modifier`, which should print 0.

## 2. Test harness and implementation

- [ ] 2.1 Add `tests/fixtures/claude-settings-ledger/` with input and expected-output JSON pairs, one per spec scenario:
  - ledger contents
  - idempotence
  - scalar retraction
  - a user-changed scalar is kept
  - array element retraction
  - entries still in source keep their key and element positions (with an externally added allow entry after a managed one)
  - an emptied container is kept
  - the first run without a ledger retracts nothing
  - union keeps an externally added allow entry, with no duplicates
  - unmanaged keys (including `hooks`) are preserved
  - pass-through on a machine without the `ai` tag

  Add `tests/test-claude-settings-ledger.sh`: for each case it renders the partial with `tests/run-template` (overriding `claudeExtraSettings`), pipes the input through, and diffs the result against the expected output. Verify it fails against the current partial (the expected red).
- [ ] 2.2 In `home/.chezmoitemplates/claude-settings-hooks-modifier`, replace `. * $extra` with the retract (previous ledger minus current) → apply (union) → write-ledger pipeline from D1–D3, keeping `extra_settings='…'` as an unchanged standalone line and the legacy-hook removal as is. Verify that every fixture in `tests/test-claude-settings-ledger.sh` passes, including idempotence.
- [ ] 2.3 Update the partial's header comment (describe the ledger and union semantics) and the `home/.chezmoitemplates/CLAUDE.md` catalog. Add one line on ledger ownership to the tooling context template `home/dot_config/claude-tooling/claude-tooling.md.tmpl`. Verify by reading the header back and checking the rendered context stays at 80 lines or fewer.
- [ ] 2.4 Run `check-claude-overrides` for every persona. Verify every baseline still resolves (no skip notices) and the `## drift` output matches its output before the change.

## 3. Rollout

- [ ] 3.1 For each of the four personas, render the modifier with `tests/run-template` and pipe the live `settings.json` through it without applying. Diff the result against the live file and verify the only difference is the new `_chezmoiManaged` key.
- [ ] 3.2 Run `chezmoi apply` scoped to the four `settings.json` targets. Then audit each persona's `skillOverrides`, `enabledPlugins`, `env`, and `permissions` against source for stale keys left by earlier removals, and remove confirmed ones by hand with the user. Verify the ledger exists in each persona and that a second apply produces no diff.
