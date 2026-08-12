## Why

`syncthing_shared_folders` — the literal list of Syncthing folders shared by MacBook Pro and Mac Studio — currently lives inline in `home/.chezmoidata/config.yaml`, referenced by each machine's `syncthing_folders` key via a YAML anchor/alias (`&laptop_desktop_syncthing_folders` / `*laptop_desktop_syncthing_folders`). This couples an unrelated block of literal data to the machine-pattern file and only works because anchors and aliases must share one YAML document. Moving the shared data into its own `.chezmoidata/` file gives it a top-level home matching its own concern and makes it directly accessible to any template as `.syncthing_shared_folders` — but YAML anchors are file-scoped, so the alias mechanism breaks the moment the data moves. This change replaces the anchor/alias with a name-based reference that keeps working across separate data files.

## What Changes

- Add `home/.chezmoidata/syncthing.yaml`, containing the `syncthing_shared_folders` list moved verbatim (with its documentation comment) out of `config.yaml`.
- Remove the `syncthing_shared_folders` block and its YAML anchor from `home/.chezmoidata/config.yaml`.
- **BREAKING** (internal data format only, no user-facing effect): change the per-machine `syncthing_folders` value from a YAML alias (`*laptop_desktop_syncthing_folders`) to a bare string naming the shared top-level data key (`syncthing_folders: syncthing_shared_folders`) for MacBook Pro and Mac Studio. A machine MAY still declare its own inline list instead of a reference — that form is unchanged.
- Update `home/.chezmoiscripts/run_onchange_after_darwin-94-setup-syncthing-folders.sh.tmpl` to resolve `syncthing_folders` after reading it from `machine-settings`: if the value is a string, treat it as the name of a top-level chezmoi data key and look it up dynamically (`kindIs "string"` vs `kindIs "slice"` dispatch); if the referenced key doesn't resolve to a list, fail the template render with a clear error instead of silently skipping folder setup.
- Keep the resolution logic local to the consuming script, not inside the generic `machine-settings`/`machine-config` templates, which are documented as property-agnostic.

## Capabilities

### New Capabilities
(none)

### Modified Capabilities
- `machine-config`: The "Shared Data Top-Level Keys" requirement currently describes a same-file YAML anchor/alias mechanism for sharing literal data across machines. This changes to a name-based string reference that a consuming script resolves against top-level chezmoi template data, which may live in any `.chezmoidata/` file.

## Impact

- `home/.chezmoidata/config.yaml` — remove shared-folder literal block and anchor; update `syncthing_folders` values for MacBook Pro and Mac Studio to string references.
- `home/.chezmoidata/syncthing.yaml` — new file, sole source of the shared folder list.
- `home/.chezmoiscripts/run_onchange_after_darwin-94-setup-syncthing-folders.sh.tmpl` — add reference-resolution and fail-loud validation logic.
- `openspec/specs/machine-config/spec.md` — requirement delta for the new sharing mechanism.
- Machines affected: MacBook Pro, Mac Studio (both currently alias the shared list). Mac mini has no `syncthing_folders` key and is unaffected.
- Tags affected: none (machine-config and syncthing-folder-setup are not tag-gated capabilities).
- Security: none — no secrets or permissions involved; `syncthing.yaml` contains the same non-sensitive folder metadata (paths, versioning, ignore patterns) already committed today.

## Non-goals

- Not changing the behavior or requirements of `syncthing-folder-setup` (folder creation, versioning, ignore-pattern reconciliation) — this is purely a data-location and machine-config-reference change.
- Not adding new machines, folders, or Syncthing devices.
- Not generalizing the name-based reference mechanism to other machine properties beyond `syncthing_folders` in this change; the resolution logic stays local to the one consuming script.
- Not migrating other shared/anchored data (if any exists elsewhere in `config.yaml`) — scope is limited to `syncthing_shared_folders`.
