## 1. Rename the shared template

- [x] 1.1 `git mv home/.chezmoitemplates/persona-list home/.chezmoitemplates/profile-list`;
  rename its internal `$personas` → `$profiles` (object shape `{name, dir, baseline}`
  unchanged).
- [x] 1.2 Update `home/.chezmoitemplates/CLAUDE.md`'s catalog entry (template name, example
  variable name).
- [x] 1.3 Smoke-test: `tests/run-template --inline '{{ includeTemplate "profile-list" . }}'`
  against a fixture with `claude_envs` set and one without; confirm valid JSON, same shape as
  before the rename.

## 2. Migrate the five `profile-list` call sites

- [x] 2.1 `executable_check-claude-overrides.tmpl`: `PERSONA_NAMES`/`PERSONA_DIRS`/
  `PERSONA_BASELINES` → `PROFILE_NAMES`/`PROFILE_DIRS`/`PROFILE_BASELINES`;
  `detect_persona_drift` → `detect_profile_drift`; `resolve_current_persona_index` →
  `resolve_current_profile_index`; `$persona` loop/local var → `$profile`; the `--fix
  <persona> ...` placeholder in help text and error messages → `--fix <profile> ...` (the
  `--fix` flag itself and argument order are unchanged); `includeTemplate "persona-list"` →
  `"profile-list"`. Render before/after and confirm the diff is substitutions only.
- [x] 2.2 `executable_uninstall-claude-plugin-everywhere.tmpl`: `PERSONA_DIRS` →
  `PROFILE_DIRS`; `$persona` loop var → `$profile`; template include updated.
- [x] 2.3 `audit-claude-code.sh.tmpl`: `CLAUDE_PERSONA_DIRS` → `CLAUDE_PROFILE_DIRS`;
  `$personas` → `$profiles`; `_claude_persona_dir` → `_claude_profile_dir`; update its
  "persona"-worded comments; template include updated.
- [x] 2.4 `run_onchange_after_darwin-44-migrate-claude-md-symlinks.sh.tmpl`: `PERSONA_DIRS` →
  `PROFILE_DIRS`; `$personas` → `$profiles`; template include updated. This script is
  `run_onchange_`-tracked — confirm the rendered content hash changes only because of this
  edit, not spuriously on a later unrelated apply.
- [x] 2.5 `executable_claude-tooling-write-guard.tmpl`: `$personaList` → `$profileList`;
  `$personas` → `$profiles`; the `"wrong persona"` comment and the guard's emitted message
  text (`"This machine runs independent personas (...)"` → `"...independent profiles (...)"`)
  updated; template include updated.

## 3. Migrate downstream consumers of the renamed identifiers

- [x] 3.1 `clean-claude-orphans/scripts/executable_list-claude-orphans.sh.tmpl`: update its
  loop over `CLAUDE_PERSONA_DIRS` to the new `CLAUDE_PROFILE_DIRS` name from task 2.3.
- [x] 3.2 `which-skill/SKILL.md`: `<other persona>` → `<other profile>`.
- [x] 3.3 `which-skill/scripts/executable_list-skills.sh`: update the "shared across every
  persona"/"this persona's settings.json" comments.

## 4. Update prose-only files (no identifiers, terminology only)

- [x] 4.1 `home/dot_claude/rules/claude-tooling.md.tmpl` — this is the canonical source
  `GLOSSARY.md` points to; update its defining paragraph (`"personas"`) and every later
  reference (symlink-sharing section, `check-claude-overrides --fix <persona>` example).
- [x] 4.2 `home/dot_claude/rules/global-preferences.md.tmpl` — update the `"personas"`
  reference and the write-guard cross-reference.
- [x] 4.3 `home/.chezmoitemplates/claude-settings-modifier` — update the
  `check-claude-overrides --fix <persona> <kind> <key>` example.
- [x] 4.4 `home/.chezmoitemplates/claude-pattern-a`, `claude-pattern-b`, `claude-pattern-c` —
  update the "never a persona" / "persona-settings mechanism" comments (all three share
  near-identical wording).
- [x] 4.5 `home/.chezmoitemplates/claude-pattern-c-devcontainer/devcontainer.json` — update
  the "persona settings ledger" comment.
- [x] 4.6 `home/dot_local/bin/executable_apply-claude-pattern.tmpl` — update the "independent
  axis from persona" / "never touch a persona's settings" comments.
- [x] 4.7 `home/dot_claude/.chezmoiexternal.toml.tmpl` — update the "each persona's" /
  "per persona" comments.
- [x] 4.8 `home/private_dot_config/claude-omc/config.jsonc` — update "read by every persona".
- [x] 4.9 `home/scripts/shared-utils.sh` — update the "shell's exported persona" comment.
- [x] 4.10 `tests/test-claude-tooling-write-guard.sh` — update the "persona settings.json"
  comment at line 81.
- [x] 4.11 `tests/test-claude-settings-ledger.sh` — update the "persona" comments and the
  `persona-$name.sh` scratch-filename convention and its check-label text.

## 5. Update repo-level docs

- [x] 5.1 `CLAUDE.md` — "Claude Code persona settings" → "Claude Code profile settings"
  (Essential Files bullet); update the `GLOSSARY.md` pointer bullet's wording.
- [x] 5.2 `GLOSSARY.md` — replace the `persona` entry with a `profile` entry (same canonical
  pointer, updated definition text — no longer needs to disambiguate against "UX persona"
  explicitly, but should still note the deliberate distinction from this repo's own
  "environment" terminology).

## 6. Spec sync

- [x] 6.1 This change's `specs/` deltas (nine capabilities) are already drafted; after tasks
  1-5 land, run `openspec validate rename-claude-persona-to-profile --strict` and fix any
  issues.
- [x] 6.2 `openspec archive rename-claude-persona-to-profile --yes` (or `/opsx:sync` +
  `/opsx:archive`) to fold the deltas into `openspec/specs/**`.

## 7. Verify

- [x] 7.1 `grep -rlw "persona\|personas\|PERSONA" home CLAUDE.md GLOSSARY.md openspec/specs` —
  must return zero matches. (`openspec/changes/archive/**` and this change's own `specs/`
  deltas, before step 6.2 folds them in, are expected to still show up and are out of scope.)
- [x] 7.2 Run `tests/run-template` against every `.tmpl` file touched in tasks 1-4; confirm
  each renders without error.
- [x] 7.3 Run `tests/test-claude-tooling-write-guard.sh` and `tests/test-claude-settings-ledger.sh`;
  both must still pass.
- [x] 7.4 On this machine, run `check-claude-overrides` (no args) and `check-claude-overrides
  --help`/usage output; confirm the renamed placeholder reads correctly and the tool still
  finds all declared profiles.
- [x] 7.5 Run `audit-claude-code` (or whatever sources `audit-claude-code.sh.tmpl`) end-to-end
  and confirm output is unchanged in substance (same profiles reported, only "persona" → 
  "profile" in any printed text).
