## 1. Script Scaffolding

- [x] 1.1 Create `home/dot_local/bin/executable_check-claude-overrides.tmpl` (no `.sh` in the
      filename — chezmoi only strips `.tmpl`, so a literal `.sh` would deploy as
      `check-claude-overrides.sh` instead of the intended `check-claude-overrides`; caught
      via `chezmoi target-path` during implementation): shebang, `set -euo pipefail`, bake in
      `{{ .chezmoi.sourceDir }}`-derived `PACKAGES_YAML`/`NATIVE_SKILLS_DIR` and the
      `{{ range $claudeEnvs }}`-derived `PERSONA_NAMES`/`PERSONA_DIRS`/`PERSONA_TEMPLATES`
      arrays at render time, mirroring `executable_claude-tooling-guard.tmpl`'s pattern in
      the same directory — not `audit-packages.sh`'s symlink-into-`home/scripts/` pattern,
      which can't carry template logic (`home/scripts/` is `.chezmoiignore`'d). Add a
      `--help` usage message.
- [x] 1.2 ~~Create a separate `symlink_*.tmpl`~~ — not needed: `executable_` deploys the
      rendered file directly to `~/.local/bin/check-claude-overrides`, no symlink involved.
- [x] 1.3 `chezmoi apply ~/.local/bin/check-claude-overrides` and confirm it's a real,
      executable, rendered file (not a symlink), and `check-claude-overrides --help` runs
      from an arbitrary working directory once `~/.local/bin` is on PATH.

## 2. Persona Enumeration and Baseline Extraction

- [x] 2.1 Resolve `claude_envs` at chezmoi-apply render time via
      `{{ range $claudeEnvs }}` (from `includeTemplate "machine-settings" . | fromJson`),
      baking the persona-name list directly into a bash array literal — not a runtime
      `chezmoi execute-template` call. (An earlier implementation pass tried the latter,
      reasoning live resolution was "more current"; reverted after review — see design.md
      Decisions for why deploy-time baking is actually the correct freshness model here.)
- [x] 2.2 Bake the unnamed default persona (`~/.claude` →
      `{{ .chezmoi.sourceDir }}/dot_claude/modify_settings.json.tmpl`) unconditionally as the
      first array entry, independent of `claude_envs`.
- [x] 2.3 For each `claude_envs` entry, bake its persona name, live config dir
      (`$HOME/.claude-<name>`), and source template path
      (`{{ .chezmoi.sourceDir }}/dot_claude-<name>/modify_settings.json.tmpl`) into the
      parallel `PERSONA_NAMES`/`PERSONA_DIRS`/`PERSONA_TEMPLATES` arrays at render time.
- [x] 2.4 Implement a reusable render-and-extract function: `chezmoi execute-template <
      <path>` *at runtime* (this part must stay dynamic — a template's content can change
      without a `chezmoi apply` having run), then extract the `extra_settings='...'` JSON
      literal from the rendered output via a stable prefix match, then validate it with `jq`
      (fail loudly, not silently-empty, on a non-match).
- [x] 2.5 Implement graceful skip: a persona whose baked-in template path doesn't exist on
      disk, or whose render/extraction fails, emits a skip notice to stderr and processing
      continues with remaining personas.

## 3. Drift Detection

- [x] 3.1 Read the native skill list from `{{ .chezmoi.sourceDir }}/dot_claude/skills/*`
      (directory names), baked in as `NATIVE_SKILLS_DIR`.
- [x] 3.2 Read the declared plugin list from `packages.yaml`'s `claude_code.plugins`
      (`PACKAGES_YAML`, baked in as `{{ .chezmoi.sourceDir }}/.chezmoidata/packages.yaml`)
      via `yq`/`jq`.
- [x] 3.3 For each checked persona, read its live `settings.json`'s `skillOverrides` and
      `enabledPlugins` objects.
- [x] 3.4 Flag `skillOverrides.<skill>: "off"` entries where `<skill>` is in the native skill
      list (3.1) and the persona's baseline (2.4) has no matching `"off"` entry.
- [x] 3.5 Flag `enabledPlugins.<id>: false` entries where `<id>` is in the declared plugin
      list (3.2) and the persona's baseline (2.4) has no matching `false` entry.
- [x] 3.6 Emit a `## drift` section as tab-separated `persona kind key value` lines (3.4 and
      3.5 combined); print the header with no rows when nothing is flagged.

## 4. Fix Mode

- [x] 4.1 Parse `--fix <persona> <skillOverrides|enabledPlugins> <key>` from argv.
- [x] 4.2 Re-run the relevant slice of detection (3.3-3.5) scoped to that one
      persona/kind/key; exit non-zero with a clear message if it is not currently flagged.
- [x] 4.3 Read the live value for that persona/kind/key straight from its `settings.json`
      (never accept it as a CLI argument).
- [x] 4.4 Locate the target `modify_settings.json.tmpl`; search for the `"<kind>" (dict`
      anchor line. If the anchor (or the whole `$extra` dict) is absent, exit non-zero with a
      message pointing at a one-time manual bootstrap.
- [x] 4.5 Copy the target file to a temp file; insert `"<key>" <value>` (value quoted per
      type — bare `true`/`false` for booleans, quoted string otherwise) as a new line
      immediately after the anchor line, matching the anchor line's indentation plus two
      spaces. Preserves the source file's trailing-newline state so a fix never introduces a
      spurious whitespace-only diff line.
- [x] 4.6 Render the temp file with the function from 2.4; confirm the extracted JSON now
      contains `<kind>.<key>` set to the expected value.
- [x] 4.7 On successful verification, overwrite the real `modify_settings.json.tmpl` with the
      temp file's content, print a success message naming the file changed, and remove the
      temp file.
- [x] 4.8 On failed verification (render error, or key/value missing/mismatched), exit
      non-zero, leave the real file byte-for-byte untouched, print the failure reason, and
      remove the temp file.

## 5. Documentation Cross-References

- [x] 5.1 Edit `home/dot_claude/rules/claude-tooling.md.tmpl`'s "Checking for Override Drift"
      section: replace the manual per-file comparison step with a pointer to run
      `check-claude-overrides`; add a pointer to `check-claude-overrides --fix <persona>
      <kind> <key>` for the "keep" resolution; state explicitly that the "drop" resolution
      remains the existing manual `/skill`/`/plugin` command.
- [x] 5.2 Edit `home/dot_claude/skills/clean-claude-orphans/SKILL.md.tmpl`: add a one-line,
      non-blocking cross-reference to `check-claude-overrides` as the complementary check for
      the opposite drift direction.

## 6. Verification

- [x] 6.1 `chezmoi execute-template <` each touched/added `.tmpl` file:
      `executable_check-claude-overrides.tmpl`, `claude-tooling.md.tmpl`,
      `clean-claude-orphans/SKILL.md.tmpl`.
- [x] 6.2 `shellcheck` the rendered `check-claude-overrides` output (the source `.tmpl`
      contains Go template syntax, so shellcheck runs against `chezmoi execute-template`'s
      output, not the source file directly).
- [x] 6.3 `chezmoi apply` on a real multi-persona machine; run `check-claude-overrides` and
      confirm output against at least one known-clean persona and one persona with a
      deliberately introduced drift entry.
- [x] 6.4 Exercise `--fix` end-to-end against a deliberately introduced drift entry; confirm
      the temp-verify-then-overwrite path leaves a single clean line inserted (`git diff`),
      and confirm a repeat `check-claude-overrides` run no longer flags that entry.
- [x] 6.5 `openspec validate claude-override-drift-check --strict`.
