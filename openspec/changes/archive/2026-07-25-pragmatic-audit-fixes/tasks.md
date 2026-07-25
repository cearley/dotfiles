# Tasks for Pragmatic audit fixes — reduce complexity, remove dead code, fix DRY violations

## 1. High-priority structural fixes

- [x] **1.1** Restructure MCP server entries in `packages.yaml` from opaque string DSL to structured YAML maps (`name`, `command`, `env`), and rewrite the script 38 template to use direct field access instead of the hand-rolled token-loop parser
- [x] **1.2** Move machine-specific data under a `machines:` key in `config.yaml`; rewrite `machine-config` and `machine-settings` templates to use `index .machines $computerName` instead of root-key iteration with exclusion lists
- [x] **1.3** Delete `run_onchange_before_darwin-33-transition-skills-to-symlinks.sh.tmpl` (one-time migration already complete; carries `rm -rf` risk)

## 2. Medium-priority cleanup

- [x] **2.1** Consolidate iCloud status check to runtime-only: remove template-time `icloud-account-id` usage in script 23; use `warn_icloud_not_signed_in` from `shared-utils.sh` consistently
- [x] **2.2** Remove duplicate AWS knowledge MCP entry from `tools.json.tmpl` (keep whichever client is current; remove the other)
- [x] **2.3** Replace manual date re-run trigger in script 41 with `time-bucket`; add comment documenting manual clone prerequisite for `specstory-cli`
- [x] **2.4** Remove dead `zsh-defer` conditional in `dot_zshrc.tmpl` (always falls through to `else`; call `_defer_shell_integrations` directly)
- [x] **2.5** Remove stale second LM Studio PATH entry from `dot_zshrc.tmpl`

## 3. Low-priority polish

- [x] **3.1** Remove empty/null `taps:` and `brews:` stubs from `personal` and `mobile` categories in `packages.yaml`; remove entirely-commented `ai.cargo` key
- [x] **3.2** Document the `trusted` list sync requirement in CLAUDE.md (or refactor entries inline to eliminate the separate list)
- [x] **3.3** Rename `includeCore` parameter to `coreAlwaysEligible` in `package-layer-items` template and its single caller (script 27)
- [x] **3.4** Replace `eval "skip_${layer}=1"` with a bash associative array in `shared-utils.sh`

## 4. Validation

- [x] **4.1** Run `chezmoi cat` on each affected generated file to verify output is correct: `~/.config/claude-extend/tools.json`, `~/Library/LaunchAgents/io.github.cearley.claude-config-dir.plist`, `~/.zshrc`, `~/.chezmoi.toml`
- [x] **4.2** Run `chezmoi apply --dry-run` and confirm no unexpected changes
- [x] **4.3** Test shell startup: open a new terminal and verify no errors
