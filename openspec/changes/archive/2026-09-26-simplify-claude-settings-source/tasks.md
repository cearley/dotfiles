# Tasks

## 1. Source files and modifier

- [x] 1.1 Add the per-persona source JSON files (now `home/dot_claude*/.claude-settings.json`, see 4.3c), each equal (`jq -S`) to the persona's previously rendered `extra_settings` apart from the empty placeholder dicts.
- [x] 1.2 Rewrite `home/.chezmoitemplates/claude-settings-modifier`: the `claudeSettings` JSON param, the recursive `apply`/`retract`, and the string ledger; delete the legacy-hook migration.
- [x] 1.3 Reduce each `home/dot_claude*/modify_settings.json.tmpl` to a one-line caller.

## 2. Tests

- [x] 2.1 Port `tests/fixtures/claude-settings-ledger/*`: rename `extra.json` to `managed.json`, convert the ledgers to the string form, delete migration fixtures 26–30, and repurpose 11 (the old array ledger retracts nothing) and 12 (an unparseable ledger retracts nothing).
- [x] 2.2 Harness: compare ledgers as parsed JSON, check that the ledger is absent or a string, drop the `extra_settings` line check, and add a check that each persona's real source file renders and applies to `{}`. The suite passes (79/79).

## 3. check-claude-overrides

- [x] 3.1 Read the baselines from each persona's `.claude-settings.json`, and remove the render step and the runtime `chezmoi` dependency.
- [x] 3.2 Make `--fix` a `jq` write with temp-copy verification, and let it create a missing `kind` object.
- [x] 3.3 Verify in a sandbox (fake persona dir, scratch baseline copy): detect, `--session-start` pointer, `--fix`, and a clean state after the fix.

## 4. Docs and verification

- [x] 4.1 Update `home/.chezmoitemplates/CLAUDE.md` and `home/dot_claude/rules/claude-tooling.md.tmpl`.
- [x] 4.2 Dry-run each persona's rendered modifier on a copy of its live `settings.json`: the output, apart from the ledger, is byte-identical to the input, the output is idempotent, and the parsed ledger equals the source file.
- [x] 4.3 Simulate the Mac Studio path (the `origin/main` partial, then the new one) on a legacy file: no duplicate hook groups.
- [x] 4.3a Independent review. Fixed: `--fix` died silently with exit 141 (SIGPIPE from `awk … exit` under `pipefail`) when a persona had more than one drift entry, a pre-existing bug, now fixed with an `ENVIRON`-keyed awk that doesn't exit early; the write-guard DENY messages pointed at the removed `$extra` dict; a non-object source file now fails at render; the source files moved from `.chezmoitemplates/claude-settings/` to `.claude-settings/`, because chezmoi parsed them as templates and a `{{` would have broken every render.
- [x] 4.3b Design review (idiom and least surprise): verdict keep, with adjustments. Done:
  - caller comments warn against `chezmoi add`/`re-add` and say that managed values overwrite
    runtime changes;
  - added a README (since folded into the partial's header, 4.3c) and a root `CLAUDE.md` pointer;
  - fixed the dot-less `claude-settings/` path strings;
  - the write guard denies `chezmoi add`/`re-add` on a persona `settings.json` (tests 12/12);
  - `check-claude-overrides` flags managed `permissions`/`env` scalars changed at runtime, and
    `--fix` accepts those kinds (sandbox-verified).
- [x] 4.3c Move each source file next to its caller as `home/dot_claude*/.claude-settings.json`:
  - the callers are the identical line `includeTemplate "claude-settings-modifier" .`, and the
    partial finds the sibling file via `.chezmoi.sourceFile`;
  - the README content became the partial's header, with user-facing points also in
    `claude-tooling.md`;
  - the harness renders the real callers;
  - checker baselines and the write guard's messages name the exact file;
  - `chezmoi cat` shows no pending change for any persona.
- [x] 4.4 `chezmoi apply` the four `settings.json` targets (after the user's go-ahead), then confirm `chezmoi status` is clean for them and a new session loads without a settings warning.
- [x] 4.5 After archiving, update the "Chezmoi Current Status" note: close the legacy-migration follow-up, and replace the `claude-settings-modifier` environment fact.
