## Why

The template-reviewer agent identified four critical bugs in the chezmoi templates: a runtime-crashing typo (`ech0`), a double-slash in PATH construction, hardcoded absolute user paths in two files, and a fragile `output` call in a `run_onchange` trigger comment that will fail if syncthing exits non-zero. These bugs cause silent failures or broken configurations on any machine that isn't the original author's.

## What Changes

- Fix `ech0 ""` typo → `echo ""` in `run_once_after_darwin-80-setup-microsoft-defender.sh.tmpl:35` (runtime `command not found` in cancel path)
- Fix double-slash `//bin` → `/bin` in `dot_zshrc.tmpl:102` (malformed PATH entry from incorrect whitespace trim)
- Replace hardcoded `/Users/craig/` path with `{{ .chezmoi.homeDir }}/` in `dot_zshrc.tmpl:202` (broken fpath on non-craig machines)
- Replace hardcoded `/Users/craig/.nvm/...` and `/Users/craig/work/...` paths with `{{ .chezmoi.homeDir }}/...` in `tools.json.tmpl:51,53` (broken MCP server config after node upgrade or on any other machine)

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `shared-utilities`: No requirement change — implementation fix only (typo in a script sourcing shared-utils)
- `script-execution`: No requirement change — these are bug fixes within existing scripts

## Impact

- **Affected files**: 3 source files (`dot_zshrc.tmpl`, `run_once_after_darwin-80-setup-microsoft-defender.sh.tmpl`, `home/private_dot_config/claude-extend/tools.json.tmpl`)
- **Tags affected**: `core` (zshrc, Defender script), `ai` (tools.json.tmpl)
- **Security**: No secrets involved; all changes are path/typo corrections
- **Non-goals**: This change does not address the philosophy-of-software-design issues (Claude env loop duplication, iCloud leakage, color mapping), the `set -e` gaps, or the syncthing `output` fragility beyond the scope of these four critical bugs
- **Breaking changes**: None — all fixes produce the same intended behavior on the author's machine and correct behavior on others
