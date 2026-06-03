## 1. Add `for_each_claude_env` to shared-utils.sh

- [x] 1.1 Add the `for_each_claude_env` function to `scripts/shared-utils.sh` — accepts a callback function name as first argument, then the raw env dirs as variadic args; handles `~` expansion and missing-dir skip internally
- [x] 1.2 Verify the function exists and is syntactically valid: `bash -n scripts/shared-utils.sh`

## 2. Refactor Script 37 (Claude Skills)

- [x] 2.1 In `run_onchange_after_darwin-37-install-claude-skills.sh.tmpl`, define a local `_install_skills_for_env()` function that takes `env_dir` as `$1` and contains the current loop body
- [x] 2.2 Replace the `for env_dir in{{ range ... }}; do ... done` block with a single `for_each_claude_env _install_skills_for_env{{ range $claudeEnvs }} "{{ . }}"{{ end }}` call
- [x] 2.3 Verify template renders cleanly: `chezmoi execute-template < home/.chezmoiscripts/run_onchange_after_darwin-37-install-claude-skills.sh.tmpl | bash -n`

## 3. Refactor Script 38 (MCP Servers)

- [x] 3.1 In `run_onchange_after_darwin-38-install-claude-mcp-servers.sh.tmpl`, define a local `_register_mcp_for_env()` function containing the current loop body (the `_mcp_entry` parsing and `claude mcp add` calls)
- [x] 3.2 Replace the `for env_dir in{{ range ... }}; do ... done` block with `for_each_claude_env _register_mcp_for_env{{ range $claudeEnvs }} "{{ . }}"{{ end }}`
- [x] 3.3 Verify template renders cleanly: `chezmoi execute-template < home/.chezmoiscripts/run_onchange_after_darwin-38-install-claude-mcp-servers.sh.tmpl | bash -n`

## 4. Refactor Script 39 (Claude Plugins)

- [x] 4.1 In `run_onchange_after_darwin-39-install-claude-plugins.sh.tmpl`, define a local `_install_plugins_for_env()` function containing the current loop body (marketplace add + plugins install calls)
- [x] 4.2 Replace the `for env_dir in{{ range ... }}; do ... done` block with `for_each_claude_env _install_plugins_for_env{{ range $claudeEnvs }} "{{ . }}"{{ end }}`
- [x] 4.3 Verify template renders cleanly: `chezmoi execute-template < home/.chezmoiscripts/run_onchange_after_darwin-39-install-claude-plugins.sh.tmpl | bash -n`

## 5. Add `warn_icloud_not_signed_in` to shared-utils.sh

- [x] 5.1 Add `warn_icloud_not_signed_in` to `scripts/shared-utils.sh` — calls `is_icloud_signed_in`; if not signed in, emits `print_message "warning" "Not signed into iCloud - Mac App Store packages will be skipped"` and returns 1; returns 0 if signed in
- [x] 5.2 Verify the function is syntactically valid: `bash -n scripts/shared-utils.sh`

## 6. Refactor Script 23 (Install Packages) — iCloud guard

- [x] 6.1 In `run_onchange_before_darwin-23-install-packages.sh.tmpl`, replace the three template-time iCloud lines (lines 16-20: `$icloudAccountId`, `$icloudSignedIn`, `{{ if not $icloudSignedIn }}` warning block) with a runtime bash call: `warn_icloud_not_signed_in || true`
- [x] 6.2 Verify template renders cleanly: `chezmoi execute-template < home/.chezmoiscripts/run_onchange_before_darwin-23-install-packages.sh.tmpl | bash -n`

## 7. Refactor Script 28 (Brew Bundle Install) — iCloud guard

- [x] 7.1 In `run_onchange_before_darwin-28-brew-bundle-install.sh.tmpl`, replace the three template-time iCloud setup lines (lines 49-55) with a runtime bash block:
  ```bash
  if ! warn_icloud_not_signed_in; then
      export HOMEBREW_BUNDLE_MAS_SKIP=1
      print_message "info" "Sign in to iCloud in System Settings, then run 'chezmoi apply' again to install App Store apps"
  fi
  ```
  Remove the second `{{ if not $icloudSignedIn }}` block at the end of the script (lines 60-62) — the info message is now emitted in the unified block above.
- [x] 7.2 Verify template renders cleanly: `chezmoi execute-template < home/.chezmoiscripts/run_onchange_before_darwin-28-brew-bundle-install.sh.tmpl | bash -n`

## 8. Make `claude-environments` Color Mapping Data-Driven

- [x] 8.1 In `home/.chezmoitemplates/claude-environments`, replace the hardcoded `case` statement for p10k color with a Go template map lookup:
  - Add `{{- $defaultColors := dict "work" 33 "personal" 76 "bedrock" 208 }}`
  - Read machine-level override: `{{- $colors := default $defaultColors (index $settings "claude_env_colors") }}`
  - Replace `case "$label" in ... esac` with a bash variable set from template expansion: `color={{ default 244 (index $colors $suffix) }}`
  - Note: `$settings` is already available in the partial from the `machine-settings` lookup at the top of the file
- [x] 8.2 Add an example `claude_env_colors` entry (commented out) to `home/.chezmoidata/config.yaml` or the relevant machine block in that file as documentation — no actual values needed unless a machine wants non-default colors
- [x] 8.3 Verify the partial renders cleanly: `chezmoi execute-template < home/.chezmoitemplates/claude-environments` (or via the run-template test harness if KeePassXC functions are used)

## 9. Migrate Script 40 to `machine-settings`

- [x] 9.1 In `run_onchange_after_darwin-40-load-claude-launchagent.sh.tmpl`, replace the two separate `includeTemplate "machine-config" (merge (dict "setting" "claude_default") .)` calls with a single `machine-settings` lookup at the top of the template block:
  - Add `{{- $settings := includeTemplate "machine-settings" . | fromJson }}`
  - Replace line 16 trigger comment: `# claude_default={{ index $settings "claude_default" }}`
  - Replace line 22 variable assignment: `{{- $claudeDefault := index $settings "claude_default" }}`
- [x] 9.2 Verify the template renders cleanly: `chezmoi execute-template < home/.chezmoiscripts/run_onchange_after_darwin-40-load-claude-launchagent.sh.tmpl | bash -n`

## 10. Final Verification

- [x] 10.1 Run `bash -n scripts/shared-utils.sh` — zero errors
- [x] 10.2 Run `git diff --stat` to confirm only expected files changed (shared-utils.sh, 5 scripts, claude-environments partial)
- [x] 10.3 Confirm the Claude env loop no longer appears verbatim in scripts 37/38/39: `grep -n 'env_dir/#\\~' home/.chezmoiscripts/run_onchange_after_darwin-3{7,8,9}-*.tmpl`
