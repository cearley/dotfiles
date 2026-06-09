## Why

Syncthing is already managed by this dotfiles repo (installed via Homebrew, restarted via a chezmoi script), but shared folder configuration is entirely manual — requiring repetitive Web UI clicks on every new machine or reinstall. Automating folder setup (path, versioning policy, ignore patterns) via a `run_onchange_after` script brings Syncthing's folder config under the same declarative, idempotent model used for everything else in the repo.

## What Changes

- Add `syncthing_folders` key to each machine section in `home/.chezmoidata/config.yaml`, declaring folders with their ID, path, versioning, and ignore patterns
- Add new `run_onchange_after_darwin-94-setup-syncthing-folders.sh.tmpl` script that applies folder config to a running Syncthing instance using `syncthing cli` and the REST API
- Script is idempotent: safe to re-run; adds missing folders, updates versioning and ignores on existing folders without touching device-sharing config set via the Web UI

## Capabilities

### New Capabilities

- `syncthing-folder-setup`: Declarative Syncthing folder configuration via chezmoi — defines folders, versioning policies, and ignore patterns in `config.yaml` and applies them on `chezmoi apply`

### Modified Capabilities

- `machine-config`: Add `syncthing_folders` to the per-machine configuration schema (new optional key)

## Impact

- **Files modified**: `home/.chezmoidata/config.yaml` (new key per machine), CLAUDE.md script-ordering table (add position 94)
- **Files added**: `home/.chezmoiscripts/run_onchange_after_darwin-94-setup-syncthing-folders.sh.tmpl`
- **Dependencies**: Syncthing must be installed (Homebrew) and running (brew services) — no new dependencies
- **Tags affected**: Machines with Syncthing in their Brewfile (MacBook Pro, Mac Studio); Mac mini is unaffected
- **Non-goals**:
  - Device pairing / sharing setup — intentionally left to the Web UI (device IDs are not declared in config)
  - Linux/Windows support — darwin-only script, consistent with other Syncthing scripts
  - Managing Syncthing daemon config (GUI address, port, LDAP) — out of scope
  - Removing folders declared in Syncthing but absent from config — deletion is destructive; script only adds/updates
- **Security**: API key extracted at runtime from `~/Library/Application Support/Syncthing/config.xml` using grep/sed — never stored in chezmoi source; no secrets in config.yaml
