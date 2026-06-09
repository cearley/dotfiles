## Context

Syncthing is already installed via Homebrew and managed by brew services. A `run_onchange_after_darwin-95` script restarts the service when its configuration changes. However, shared folder configuration — paths, versioning policies, ignore patterns — is done entirely through the Syncthing Web UI and is lost on a fresh machine setup.

The Syncthing daemon ships a first-party `syncthing cli` subcommand that communicates with the running instance over the local REST API, reading the API key automatically from the config file. A separate REST endpoint (`POST /rest/db/ignores`) handles ignore patterns; it requires the API key explicitly.

The script must be idempotent and non-destructive. Critically, device-sharing relationships (which machines share which folders) are set up via the Web UI and stored in the folder's `devices` list — overwriting this list would silently break sync.

## Goals / Non-Goals

**Goals:**
- Add `syncthing_folders` to the per-machine config.yaml schema
- Implement a `run_onchange_after_darwin-94` script that adds missing folders and reconciles versioning + ignore patterns on existing ones
- Preserve device-sharing config set via the Web UI on every re-run
- Keep the API key out of the chezmoi source state

**Non-Goals:**
- Device pairing/sharing — intentionally left to the Web UI
- Folder deletion — too destructive for an automated script
- Linux/Windows support — darwin-only, consistent with existing Syncthing script
- Syncthing daemon-level config (ports, GUI auth, LDAP)

## Decisions

### Decision 1: `add-json` for new folders, individual setters for existing

**Rationale**: `syncthing cli config folders add-json '<json>'` is the cleanest way to create a folder with full config in one call (versioning is embedded in the JSON blob). However, it replaces the entire folder config, which would wipe the `devices` list populated by the Web UI.

**Approach**: Check if the folder ID already exists (`syncthing cli config folders list`). If absent, use `add-json` with the full config. If present, use targeted setters for only the properties this script owns (versioning type, versioning params, ignores) — never touch `devices`.

**Alternative considered**: Always use `add-json` with a merged config (read existing, merge, write back). Rejected: complex, fragile, requires JSON manipulation in bash.

### Decision 2: REST API for ignore patterns

**Rationale**: `syncthing cli` has no subcommand for per-folder ignore patterns. The only options are:
1. Write `.stignore` directly to the folder path — simple, but requires the folder directory to exist and bypasses Syncthing's own file parsing
2. `POST /rest/db/ignores?folder=<id>` — canonical Syncthing approach, writes `.stignore` via the daemon and validates patterns

**Choice**: REST API. It writes the `.stignore` file and validates syntax. The API key is extracted at runtime with `grep`/`sed` from the Syncthing config.xml — one line, no external tools.

**Note**: Syncthing config.xml lives at `~/Library/Application Support/Syncthing/config.xml` on macOS. This path is stable across Homebrew Syncthing versions.

### Decision 3: Per-machine `syncthing_folders` list in config.yaml

**Rationale**: Different machines may have different folder sets or different local paths for the same logical folder. This mirrors the existing pattern for `claude_envs` and `keepassxc_entries`.

**Schema per folder entry**:
```yaml
syncthing_folders:
  - id: emmxp-fxjwr        # must match across machines for the same shared folder
    label: knowledge-personal
    path: ~/basic-memory    # expanded at script time, not in template
    versioning:             # optional; omit to leave existing versioning alone
      type: simple          # simple | trashcan | staggered | external | none
      params:               # Syncthing-native camelCase keys; all values must be strings
        keep: "5"
        cleanoutDays: "0"
    ignores:                # optional; omit to leave existing .stignore alone
      - "(?d).DS_Store"
```

**`type: none` clears versioning** (sets `type: ""`). Omitting the `versioning` key leaves existing versioning untouched.

### Decision 4: Script position 94

The folder setup script runs at position 94 (`run_onchange_after_darwin-94-setup-syncthing-folders.sh.tmpl`), before the existing restart script at 95. Syncthing `cli` changes take effect immediately without a restart, so the ordering is a safety net rather than a hard requirement.

### Decision 5: Require Syncthing to be running

The `syncthing cli` communicates with the live daemon. If Syncthing is not running (e.g., first-time setup before brew services start), the script exits gracefully with a warning rather than failing the `chezmoi apply`.

### Decision 6: `run_onchange_after` trigger

The script uses `run_onchange_after` so chezmoi re-runs it whenever the template content changes — which includes changes to config.yaml that affect the machine's `syncthing_folders` list (since those values are embedded in the script via Go template expansion).

## Risks / Trade-offs

- **[Risk] Script runs while Syncthing is stopped** → Script checks for a running daemon (`syncthing cli show system`) before proceeding; exits with a warning if unavailable so `chezmoi apply` completes cleanly
- **[Risk] Folder path doesn't exist yet** → `mkdir -p` the path before calling `add-json`; Syncthing itself creates `.stfolder` on first use
- **[Risk] Version skew in `syncthing cli` flags** → Script uses only `add-json` (JSON blob) and `versioning type set` / `versioning params set` which are stable; avoids flags that have changed across versions
- **[Risk] API key extracted via grep breaks if config.xml format changes** → The `<apikey>` element has been stable for many years; acceptable risk for a personal dotfiles repo
- **[Trade-off] Per-machine config duplication** → Folders shared across machines must be listed in each machine section. Acceptable given the existing per-machine config pattern; avoids the complexity of a global merge

## Migration Plan

1. Add `syncthing_folders` entries for the Mac Studio's existing folders in `config.yaml`
2. Apply on Mac Studio: `chezmoi apply` — script reconciles config for already-configured folders
3. Add entries for MacBook Pro in `config.yaml`
4. Apply on MacBook Pro: `chezmoi apply` — script adds any missing folders locally (device sharing still via Web UI)
5. No rollback needed: script only adds/updates, never deletes

## Open Questions

None — all design decisions are resolved.
