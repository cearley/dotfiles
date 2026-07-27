## Context

`home/.chezmoidata/config.yaml` is a static YAML data file (no chezmoi templating — `.chezmoidata/` files cannot be templates) consumed by `home/.chezmoitemplates/machine-config` and `machine-settings`, which resolve per-machine settings for the currently running host via substring hostname matching against keys under `machines:`.

MacBook Pro and Mac Studio declared byte-identical `syncthing_folders` lists (5 entries: `default`, `knowledge-personal`, `Confidential`, `Business`, `knowledge-work`, each with `id`/`label`/`path`/`versioning`/`ignores`). This was pure copy-paste duplication with no mechanism to keep the two copies in sync.

## Goals / Non-Goals

**Goals:**
- Eliminate the duplicated `syncthing_folders` list between MacBook Pro and Mac Studio.
- Preserve identical resolved data per machine (zero behavior change for the consuming script).
- Keep the change confined to `config.yaml`; no template or script edits.

**Non-Goals:**
- Changing the `syncthing_folders` schema (per-folder shape stays `id`/`label`/`path`/`versioning`/`ignores`).
- Deduplicating other per-machine settings (`claude_envs`, `keepassxc_entries`, etc.).
- Building tooling/validation to prevent future accidental duplication elsewhere in `config.yaml`.

## Decisions

### Decision 1: Use a plain YAML anchor/alias, not a template mechanism

`config.yaml` lives in `.chezmoidata/` and is explicitly static — no `{{ }}` template expressions are allowed there. YAML anchors (`&name`) and aliases (`*name`) are pure YAML syntax, resolved by the YAML parser before chezmoi's template engine ever sees the data, so they don't violate the "data files are static" convention.

Verified empirically: wrote a scratch `.chezmoidata` file with an anchor/alias pair and confirmed via `chezmoi execute-template` that both keys resolved to identical, fully-expanded data.

**Alternatives considered:**
- A chezmoi template partial that builds the list at render time. *Rejected*: `.chezmoidata/` files can't contain template expressions, and moving the list into a `.chezmoitemplates/` partial would mean the setup script's data source is no longer plain declarative YAML, complicating the existing `machine-settings`/`machine-config` lookup path for no benefit.

### Decision 2: Anchor lives in a new top-level key (`syncthing_shared_folders`), not nested inside `machines:`

Two placements were considered for where the anchor's defining node lives:
- **Sibling key directly inside `machines:`** (e.g. `machines: { MacBook Pro: {...}, syncthing_folders: &anchor [...] }`). *Rejected*: `home/.chezmoitemplates/machine-config:37` does `{{- range $pattern, $config := .machines -}}`, treating every key under `machines:` as a hostname-pattern candidate and testing `contains $pattern $computerName`. A non-machine key here is a latent false-match risk, and it contradicts `openspec/specs/machine-config/spec.md`'s Machine Data Storage requirement that all `machines:` entries are machine-name patterns.
- **New top-level key, outside `machines:` entirely.** *Chosen*: confirmed via code reading that neither `machine-config` nor `machine-settings` touch anything outside `.machines`, so this is invisible to hostname matching. It also reads naturally as "shared literal data, not a machine setting."

### Decision 3: Keep the anchor definition lexically before `machines:`

YAML resolves anchors in a single forward pass — an alias can only reference an anchor already seen earlier in the document. Confirmed empirically (a scratch file with the anchor defined *after* its alias use failed with `could not find alias "shared"`). This forces `syncthing_shared_folders` to be positioned above `machines:` in the file, which also reads naturally as "shared data declared before the entries that use it."

## Risks / Trade-offs

- **[Risk]** A future machine name pattern could theoretically contain the substring `syncthing_shared_folders` and get spuriously matched if it were ever nested inside `machines:` — moot under the chosen top-level placement (Decision 2), since `machine-config`'s range never sees this key at all.
- **[Trade-off]** Two per-machine sections aliasing the same list means a machine wanting a *slightly different* folder set (e.g. one machine missing a folder) can no longer alias the whole shared list — it would need to either not use the alias or the shared list would need splitting. Not a concern today since MacBook Pro and Mac Studio genuinely want identical folder sets; deferred until a machine needs to diverge.

## Migration Plan

1. Add `syncthing_shared_folders: &laptop_desktop_syncthing_folders` above `machines:`, holding the 5-folder list.
2. Replace MacBook Pro's inline list with `syncthing_folders: *laptop_desktop_syncthing_folders`.
3. Replace Mac Studio's inline list with `syncthing_folders: *laptop_desktop_syncthing_folders`.
4. Verify via `chezmoi execute-template` that both machines' resolved `syncthing_folders` are unchanged and identical to each other.
5. Verify the consuming script (`run_onchange_after_darwin-94-setup-syncthing-folders.sh.tmpl`) still renders without error.

**Rollback:** revert `config.yaml` to the prior state (re-inline both lists). Single-file change, trivially revertible via git.

## Open Questions

None.
