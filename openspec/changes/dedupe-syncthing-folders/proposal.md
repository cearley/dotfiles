## Why

`home/.chezmoidata/config.yaml` declared the identical 5-entry `syncthing_folders` list separately under both "MacBook Pro" and "Mac Studio" (~50 duplicated lines). Any future edit to a shared folder's `versioning`/`ignores`/`path` required updating both machine sections in lockstep, with no mechanism to catch a missed one — pure copy-paste drift risk in a file that's otherwise the single source of truth for machine settings.

## What Changes

- Extracted the shared 5-folder Syncthing list into a new top-level `syncthing_shared_folders` key (YAML anchor `&laptop_desktop_syncthing_folders`) in `home/.chezmoidata/config.yaml`, defined above `machines:`.
- Both `machines."MacBook Pro".syncthing_folders` and `machines."Mac Studio".syncthing_folders` now alias that anchor (`*laptop_desktop_syncthing_folders`) instead of repeating the list.
- Documented the new key in the file's existing comment-header block, including why it lives outside `machines:` rather than as a sibling key inside it.
- No schema, behavior, or resolved-data change: both machines' `syncthing_folders` still resolve to byte-identical lists, verified via `chezmoi execute-template`.

## Capabilities

### New Capabilities
<!-- None -->

### Modified Capabilities
- `machine-config`: additive only — documents that `config.yaml` MAY contain top-level keys other than `machines:` for shared literal data referenced via YAML anchor/alias, and that such keys MUST NOT be treated as machine-name patterns. No existing requirement's behavior changes; every machine-name-pattern entry remains nested under `machines:` per the existing Machine Data Storage requirement, and every resolved `syncthing_folders` scenario (openspec/specs/machine-config/spec.md:224-247) still holds unchanged.

## Impact

- **Affected files**: `home/.chezmoidata/config.yaml` only.
- **Affected machines**: MacBook Pro, Mac Studio (both consume the alias; Mac mini is unaffected — it has no `syncthing_folders` entry).
- **Consuming script**: `home/.chezmoiscripts/run_onchange_after_darwin-94-setup-syncthing-folders.sh.tmpl` reads `syncthing_folders` from the resolved per-machine settings dict via `machine-settings`/`machine-config`; unaffected since YAML alias resolution happens before chezmoi's template layer sees the data. Re-rendered and confirmed no errors.
- **Placement constraint discovered during implementation**: the anchor definition must precede its first alias use lexically (confirmed empirically — YAML resolves anchors in a single forward pass; a trailing-position `syncthing_shared_folders` after `machines:` fails with `could not find alias`), and it must live as a top-level key rather than a sibling key inside `machines:`, because `home/.chezmoitemplates/machine-config:37` ranges over every key under `machines:` and tests each as a hostname substring pattern — a non-machine key there is a latent false-match risk and would also contradict the `machine-config` spec's Machine Data Storage requirement.
- **Security implications**: none. No secret handling, no permission changes.

## Non-goals

- Changing the `syncthing_folders` schema itself (per-folder `id`/`label`/`path`/`versioning`/`ignores` shape is unchanged).
- Deduplicating any other machine settings in `config.yaml` (e.g. `claude_envs`, `keepassxc_entries`) — out of scope for this change.
- Adding validation that `syncthing_shared_folders` (or any future shared-data top-level key) isn't accidentally shadowed by a real machine name pattern — deferred; today's machine names ("MacBook Pro", "Mac Studio", "Mac mini") don't collide.
