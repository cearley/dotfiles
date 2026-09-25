# Tasks

## 1. Rename the partial

- [ ] 1.1 Save the current `managed_hooks` JSON from `home/.chezmoitemplates/claude-settings-hooks-modifier` to the session scratchpad as `managed-hooks.json`, for comparison in task 3.1. Verify with `jq 'keys' managed-hooks.json`, which should list the five events.
- [ ] 1.2 `git mv home/.chezmoitemplates/claude-settings-hooks-modifier home/.chezmoitemplates/claude-settings-modifier`. Update the `includeTemplate` name in the four `home/dot_claude*/modify_settings.json.tmpl` files, in `tests/test-claude-settings-ledger.sh`, and in the partial's own header example. Verify:
  - `tests/test-claude-settings-ledger.sh` still passes all 19 cases unchanged;
  - `chezmoi execute-template < home/dot_claude-personal/modify_settings.json.tmpl` renders;
  - `grep -rn claude-settings-hooks-modifier --exclude-dir=archive --exclude-dir=.git .` lists only `openspec/changes/claude-tooling-plugin/`, this change's own artifacts, and the prose references fixed in task 2.3.

## 2. Hooks through the ledger, with migration

- [ ] 2.1 Test harness: remove the `del(.hooks)` strip from `tests/test-claude-settings-ledger.sh` (design D5), and remove the five injected managed hooks from fixture `09-unmanaged-and-hooks/expected.json`. Add fixtures under `tests/fixtures/claude-settings-ledger/`, one per new spec scenario:
  - `20-hook-written`
  - `21-hook-edit-replaces-group`
  - `22-hook-removed-retracted`
  - `23-foreign-hooks-keep-position` (with an `exact` marker)
  - `24-merged-group-not-recognized`
  - `25-no-source-hooks-untouched`
  - `26-migration-replaces-legacy` (it must assert that `claude-tooling-write-guard` is present in the output)
  - `27-migration-removes-retired-guard`
  - `28-migration-keeps-foreign-hooks` (`bd prime` and the iTerm `cc-status` command)
  - `29-migration-inner-hook-removal`
  - `30-migration-does-not-repeat`

  Every fixture is also checked for idempotence by the existing re-run. Verify the new cases fail against the renamed but unchanged partial (the expected red), while 01–08 and 10–19 still pass.
- [ ] 2.2 In `home/.chezmoitemplates/claude-settings-modifier`, delete the hook stage: `managed_hooks`, `retired_commands`, the retired-command filter, and the per-event upsert reduce. Add the D2 migration after `$prev` is computed and before retraction:
  - it runs only when `$prev` has no element with `path[0] == "hooks"`;
  - it removes inner hooks whose `command` is on the frozen six-command list;
  - it drops groups left with an empty `hooks` array and keeps event arrays.

  Keep `extra_settings='…'` as a single standalone line. Verify:
  - `tests/test-claude-settings-ledger.sh` passes every case, including idempotence and the single-line check;
  - `wc -l` on the partial is lower than before the change;
  - `grep -c 'retired_commands\|managed_hooks'` on the partial prints 0.
- [ ] 2.3 Docs:
  - rewrite the partial's header comment: all managed settings, hooks included, come from `claudeExtraSettings`; describe the D2 migration and its planned removal; delete the upsert and `retired_commands` paragraph;
  - update the `home/.chezmoitemplates/CLAUDE.md` catalog entry (new name, no hook stage);
  - update `home/dot_claude/rules/claude-tooling.md.tmpl` (the partial name, and hooks being declared per persona);
  - update the comment at `home/dot_local/bin/executable_check-claude-overrides.tmpl:67`.

  Verify by reading each edited passage back, and with the task 1.2 grep, which should then list only `claude-tooling-plugin` and this change.

## 3. Declare hooks in each persona

- [ ] 3.1 Add a `"hooks" (dict …)` entry to `$extra` in all four `home/dot_claude*/modify_settings.json.tmpl` files. Write it in Go `dict`/`list` style (design D1), placed after the existing keys so the `"skillOverrides" (dict` and `"enabledPlugins" (dict` anchors that `check-claude-overrides --fix` looks for stay the first matches. The default `~/.claude` template gets the hooks too. Verify:
  - for each persona, `chezmoi execute-template < <template> | grep "^extra_settings='"`, with its JSON `.hooks` extracted, equals the scratchpad `managed-hooks.json` under `jq -S`;
  - `grep -c '"skillOverrides" (dict\|"enabledPlugins" (dict'` inside each template's hooks block is 0.
- [ ] 3.2 Run `check-claude-overrides` for every persona. Verify every baseline resolves (no skip notices) and the `## drift` output matches its output before the change. This covers the claude-override-audit scenario "Hooks in the baseline do not affect drift".

## 4. Rollout

- [ ] 4.1 For each of the four personas:
  - render its `modify_settings.json.tmpl` to a script in the scratchpad (`chezmoi execute-template`);
  - pipe a scratchpad copy of its live `settings.json` through the script, twice;
  - do not apply anything.

  Verify:
  - apart from `_chezmoiManaged`, the output equals the live file, except that any `claude-tooling-guard` group is gone;
  - the ledger gains exactly 5 hook entries;
  - the `PreToolUse` `claude-tooling-write-guard` group is present;
  - the second pass is byte-identical to the first.
- [ ] 4.2 Run `chezmoi apply` scoped to the four `settings.json` targets. Do not use `--exclude=templates`, and use `chezmoi status` rather than `chezmoi diff`, which needs a TTY. Verify:
  - each persona's ledger has 5 `hooks` entries;
  - `chezmoi status` shows no pending change for those targets afterward;
  - in a new session, the `SessionStart` drift check runs, and the write guard's notice appears when a tooling path is read.
- [ ] 4.3 Open a `bd` follow-up issue: "Delete the legacy-hook migration from claude-settings-modifier once every ai machine has applied generalize-claude-settings-ledger". List the machines, the migration block, and fixtures 26–30. Verify with `bd show <id>`.
- [ ] 4.4 At archive time, update the `## Purpose` of `openspec/specs/claude-settings-ledger/spec.md` so it covers all managed settings, hooks included, not only "extra-settings entries". Delta specs cannot change Purpose. Verify with `openspec validate --specs claude-settings-ledger --strict`.
