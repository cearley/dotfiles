## 1. Config Schema

- [x] 1.1 Add `syncthing_folders` list to the MacBook Pro section of `home/.chezmoidata/config.yaml` with initial folder entries (id, label, path, versioning, ignores)
- [x] 1.2 Add `syncthing_folders` list to the Mac Studio section of `home/.chezmoidata/config.yaml` with the same shared folder entries (same IDs, adjust paths if needed)
- [x] 1.3 Verify config.yaml is valid YAML (`python3 -c "import yaml; yaml.safe_load(open('home/.chezmoidata/config.yaml'))"`)

## 2. Setup Script

- [x] 2.1 Create `home/.chezmoiscripts/run_onchange_after_darwin-94-setup-syncthing-folders.sh.tmpl` with darwin platform guard and boilerplate (shebang, `set -euo pipefail`, `source shared-utils.sh`)
- [x] 2.2 Add `lookPath "syncthing"` guard — exit 0 if syncthing not installed
- [x] 2.3 Add daemon liveness check via `syncthing cli show system` — print warning and exit 0 if not reachable
- [x] 2.4 Add API key extraction: `APIKEY=$(grep -o '<apikey>[^<]*</apikey>' "$HOME/Library/Application Support/Syncthing/config.xml" | sed 's/<[^>]*>//g')`
- [x] 2.5 Add Go template loop over `syncthing_folders` for the current machine (use `machine-settings` template to get the list)
- [x] 2.6 For each folder: emit `mkdir -p <path>` to ensure local directory exists
- [x] 2.7 For each folder: check if folder ID exists (`syncthing cli config folders list | grep -qx "<id>"`); branch into add vs. update paths
- [x] 2.8 Implement **add path**: call `syncthing cli config folders add-json '<json>'` with full folder config (id, label, path, type, versioning embedded in JSON)
- [x] 2.9 Implement **update path**: call `syncthing cli config folders <id> versioning type set <type>` and `syncthing cli config folders <id> versioning params set <key> <val>` for each param; skip versioning block if `versioning` key is absent in config
- [x] 2.10 Handle `versioning.type: none` by setting type to empty string (`""`) to clear versioning
- [x] 2.11 Implement ignore patterns: if `ignores` list is non-empty, POST to REST API; skip if `ignores` key is absent
- [x] 2.12 Print `print_message "success"` per folder after reconciliation

## 3. Template Testing

- [x] 3.1 Run `tests/run-template home/.chezmoiscripts/run_onchange_after_darwin-94-setup-syncthing-folders.sh.tmpl` and verify the rendered script looks correct for the current machine
- [x] 3.2 Run `chezmoi diff` (or `chezmoi status`) to confirm the script is picked up and would be executed
- [x] 3.3 Run `chezmoi apply` on Mac Studio and verify: new folders appear in `syncthing cli config folders list`, versioning and ignores are set as declared

## 4. Documentation

- [x] 4.1 Update CLAUDE.md script-ordering table to add position 94 (setup-syncthing-folders) in the 80-99 System Config group
- [x] 4.2 Add `syncthing_folders` key documentation to the `config.yaml` header comment block (alongside existing `claude_envs`, `claude_default` docs)
