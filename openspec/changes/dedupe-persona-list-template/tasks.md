## 1. Create the shared template

- [ ] 1.1 Add `home/.chezmoitemplates/persona-list`: resolves `claude_envs` (via
  `includeTemplate "machine-settings" .`, same source every current call site already uses)
  into a JSON array of `{name, dir, baseline}` objects, unnamed default first.
- [ ] 1.2 Add its catalog entry to `home/.chezmoitemplates/CLAUDE.md`, matching the
  `package-layer-items` entry's format (description + usage snippet).
- [ ] 1.3 Smoke-test the template alone: `tests/run-template --inline '{{ includeTemplate "persona-list" . }}'`
  against at least one fixture with `claude_envs` set and one without, confirm valid JSON and
  expected field values.

## 2. Migrate `check-claude-overrides.tmpl` (all three arrays)

- [ ] 2.1 Capture current rendered output of lines 29-31 (`PERSONA_NAMES`/`PERSONA_DIRS`/
  `PERSONA_BASELINES`) via `tests/run-template` for diffing.
- [ ] 2.2 Replace the three inline `range $claudeEnvs` expressions with one
  `includeTemplate "persona-list" . | fromJson` plus three `range`-based extractions (name,
  dir, baseline) into the same three array variable names.
- [ ] 2.3 Re-render and diff against 2.1's capture — must be byte-identical.
- [ ] 2.4 Run `tests/test-claude-settings-ledger.sh`.

## 3. Migrate `uninstall-claude-plugin-everywhere.tmpl`

- [ ] 3.1 Capture current rendered `PERSONA_DIRS` line.
- [ ] 3.2 Replace with `includeTemplate "persona-list" . | fromJson` + `dir` extraction.
- [ ] 3.3 Diff against 3.1 — byte-identical.

## 4. Migrate `audit-claude-code.sh.tmpl`

- [ ] 4.1 Capture current rendered `CLAUDE_PERSONA_DIRS` line.
- [ ] 4.2 Replace with `includeTemplate "persona-list" . | fromJson` + `dir` extraction.
- [ ] 4.3 Diff against 4.1 — byte-identical.
- [ ] 4.4 Run `audit-packages` (which sources this library) end-to-end on this machine and
  confirm output is unchanged from a pre-change baseline run.

## 5. Migrate `run_onchange_after_darwin-44-migrate-claude-md-symlinks.sh.tmpl`

- [ ] 5.1 Capture current rendered `PERSONA_DIRS` line.
- [ ] 5.2 Replace with `includeTemplate "persona-list" . | fromJson` + `dir` extraction.
- [ ] 5.3 Diff against 5.1 — byte-identical. Note: this script is content-hash-tracked
  (`run_onchange_`); confirm the rendered content hash is unchanged so this edit does not
  itself trigger a spurious re-run on next apply.

## 6. Migrate `claude-tooling-write-guard.tmpl`

- [ ] 6.1 Capture current rendered `$personaList` value.
- [ ] 6.2 Replace the inline `range $claudeEnvs` join with
  `includeTemplate "persona-list" . | fromJson` + a `range`-based join over `name`.
- [ ] 6.3 Diff against 6.1 — byte-identical.

## 7. Spec and validation

- [ ] 7.1 Add the `claude-override-audit` delta spec (included in this change under
  `specs/claude-override-audit/spec.md`) updating the "Persona Environment Enumeration"
  requirement's implementation note.
- [ ] 7.2 Run `openspec validate dedupe-persona-list-template --strict` and fix any issues.
- [ ] 7.3 Confirm no other file in the repo still contains the inline
  `trimPrefix "~/.claude-"` pattern outside the new `persona-list` template itself
  (`grep -rn 'trimPrefix "~/.claude-"' home`).
- [ ] 7.4 After apply, sync the spec delta (`openspec archive dedupe-persona-list-template --yes`
  or `/opsx:sync` + `/opsx:archive`).
