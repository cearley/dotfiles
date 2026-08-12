## 1. Extract shared data into its own file

- [x] 1.1 Create `home/.chezmoidata/syncthing.yaml` containing the `syncthing_shared_folders` list (all 5 entries) moved verbatim from `home/.chezmoidata/config.yaml`, including its schema-documentation comment
- [x] 1.2 Remove the `syncthing_shared_folders` block and its `&laptop_desktop_syncthing_folders` anchor from `home/.chezmoidata/config.yaml`
- [x] 1.3 Update the top-of-file section comment in `config.yaml` (lines 1-5) to drop the reference to `syncthing_shared_folders` as a section of that file

## 2. Switch machine entries to name-based references

- [x] 2.1 Change `MacBook Pro.syncthing_folders` in `config.yaml` from `*laptop_desktop_syncthing_folders` to the bare string `syncthing_shared_folders`
- [x] 2.2 Change `Mac Studio.syncthing_folders` in `config.yaml` from `*laptop_desktop_syncthing_folders` to the bare string `syncthing_shared_folders` (keep the existing `# Same 5 folders as MacBook Pro` comment, updated to point at the new file)
- [x] 2.3 Update the `syncthing_folders` property doc comment in the `machines:` section (around line 113-118) to describe both accepted forms: an inline list, or a bare string naming a top-level `.chezmoidata/` key
- [x] 2.4 Confirm `Mac mini` is untouched (no `syncthing_folders` key)

## 3. Resolve the reference in the consuming script

- [x] 3.1 In `home/.chezmoiscripts/run_onchange_after_darwin-94-setup-syncthing-folders.sh.tmpl`, after `$stFolders := index $settings "syncthing_folders"`, add a `kindIs "string" $stFolders` check
- [x] 3.2 When `$stFolders` is a string, resolve it via `index . $stFolders` against the root template data and reassign `$stFolders` to the result
- [x] 3.3 If the resolved value is empty/nil (reference didn't match any top-level data key), call `fail` with a message naming the missing key, before the existing "no folders configured" skip check
- [x] 3.4 Confirm the existing "no `syncthing_folders` key at all → skip gracefully" behavior (Mac mini's case) is unaffected — that path never reaches the string/list dispatch since `$stFolders` is already empty from `machine-settings`

## 4. Update the machine-config spec

- [x] 4.1 Verify `openspec/changes/extract-syncthing-shared-folders/specs/machine-config/spec.md` (already drafted) matches the final implementation once code changes land

## 5. Verify

- [x] 5.1 Run `tests/run-template home/.chezmoiscripts/run_onchange_after_darwin-94-setup-syncthing-folders.sh.tmpl` (or `chezmoi execute-template <`) and confirm the rendered script is unchanged for a machine matching "MacBook Pro" or "Mac Studio" (folder list, IDs, versioning, ignores all identical to before)
- [x] 5.2 Render the same template for a hypothetical unmatched/Mac-mini-like machine and confirm it still prints "No syncthing_folders configured for this machine" and exits 0
- [x] 5.3 Temporarily typo the string reference (e.g. `syncthing_folers`) in a scratch copy and confirm template rendering fails loudly with a clear error, then revert the typo
- [x] 5.4 Run `chezmoi diff` (interactive TTY) or `chezmoi status` on a real MacBook Pro/Mac Studio machine to confirm no unexpected changes are proposed
- [x] 5.5 Run `openspec validate --change extract-syncthing-shared-folders --strict` before archiving
