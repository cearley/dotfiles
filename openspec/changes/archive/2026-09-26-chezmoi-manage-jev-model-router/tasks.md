# Tasks

## 1. Vendor jev-model-router's files via chezmoiexternal

- [x] 1.1 Create `home/dot_claude/.chezmoiexternal.toml.tmpl`, gated on
      `{{- if and (eq .chezmoi.os "darwin") (has "ai" .tags) -}}`, with four
      `type = "file"` entries (each with `refreshPeriod = "168h"`) pointing
      at `raw.githubusercontent.com/davila7/claude-code-templates/main/cli-tool/components/mods/productivity/jev-model-router/...`
      for `.claude-plugin/plugin.json`, `hooks/hooks.json`,
      `hooks/jev-model-router.ts`, and `hooks/policy.ts`, targeting
      `skills/jev-model-router/<same-relative-path>`. Verify with
      `tests/run-template home/dot_claude/.chezmoiexternal.toml.tmpl` (or
      `chezmoi execute-template <` for the parts with no `keepassxcAttribute`
      calls) that it renders valid TOML with all four `[skills/jev-model-router/...]`
      table keys present.
- [x] 1.2 Run `chezmoi diff` and confirm it proposes creating exactly those
      four files under `~/.claude/skills/jev-model-router/`; then `chezmoi
      apply` and verify with `ls -la ~/.claude-personal/skills/jev-model-router/`
      (or any other declared persona) that the files are reachable there too,
      through the existing `skills/` symlink, with no persona-specific
      externals entry added.

## 2. Enable function hooks in both shells

- [x] 2.1 In `home/dot_zshrc.tmpl`, add
      `{{- if has "ai" .tags }}\nexport CLAUDE_CODE_ENABLE_FUNCTION_HOOKS=1\n{{- end }}`
      near the existing `CLAUDE_CONFIG_DIR` export (same template-variable
      block, its own tag condition — not nested inside the `$claudeDefault`
      check). Verify with `tests/run-template home/dot_zshrc.tmpl` that the
      export line appears in the rendered output.
- [x] 2.2 Make the equivalent addition to `home/dot_bashrc.tmpl`. Verify with
      `tests/run-template home/dot_bashrc.tmpl` the same way.

## 3. Declare jev-model-router's non-secret options per persona

- [x] 3.1 Add a `pluginConfigs.jev-model-router.options` object (`provider:
      "typesafe"`, `typesafeBaseUrl: "https://openrouter.ai/api"`,
      `typesafeModel: "~typesafe/jev-latest"`, plus the tier/threshold/switch
      defaults from `design.md` - Decisions) to
      `home/dot_claude/.claude-settings.json`. Verify with `jq .
      home/dot_claude/.claude-settings.json` that the file is still valid
      JSON and contains the new key.
- [x] 3.2 Make the identical addition to
      `home/dot_claude-personal/.claude-settings.json`. Verify the same way.
- [x] 3.3 Make the identical addition to
      `home/dot_claude-work/.claude-settings.json`. Verify the same way.
- [x] 3.4 Make the identical addition to
      `home/dot_claude-bedrock/.claude-settings.json`. Verify the same way.
- [x] 3.5 Confirm none of the four files declares `typesafeApiKey` or
      `gatewayApiKey` (or any other field `jev-model-router`'s
      `.claude-plugin/plugin.json` marks `sensitive`) by checking the
      vendored `plugin.json`'s `userConfig` against each edited
      `.claude-settings.json` with `jq '.pluginConfigs["jev-model-router"].options
      | keys'`.

## 4. Integration verification

- [x] 4.1 Run `chezmoi apply` for the whole machine. Verify with `jq
      '.pluginConfigs["jev-model-router"]' "$dir/settings.json"` (for each of
      `~/.claude`, `~/.claude-personal`, `~/.claude-work`,
      `~/.claude-bedrock`) that every persona's live `settings.json` now
      carries the options block, and that `_chezmoiManaged` in each file
      includes the new keys.
- [x] 4.2 Open a fresh interactive zsh session and a fresh interactive bash
      session; verify `echo $CLAUDE_CODE_ENABLE_FUNCTION_HOOKS` prints `1` in
      both, regardless of which persona's `CLAUDE_CONFIG_DIR` is active.
