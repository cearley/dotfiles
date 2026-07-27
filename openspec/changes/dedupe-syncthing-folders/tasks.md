## 1. Restructure config.yaml

- [x] 1.1 Add top-level `syncthing_shared_folders: &laptop_desktop_syncthing_folders` key above `machines:` in `home/.chezmoidata/config.yaml`, holding the 5-folder Syncthing list (`default`, `knowledge-personal`, `Confidential`, `Business`, `knowledge-work`).
- [x] 1.2 Replace `machines."MacBook Pro".syncthing_folders`'s inline list with `syncthing_folders: *laptop_desktop_syncthing_folders`.
- [x] 1.3 Replace `machines."Mac Studio".syncthing_folders`'s inline list with `syncthing_folders: *laptop_desktop_syncthing_folders`.
- [x] 1.4 Update the file's comment-header block to document the new `syncthing_shared_folders` key and why it sits outside `machines:`.

## 2. Verification

- [x] 2.1 Confirm via scratch `.chezmoidata` test file + `chezmoi execute-template` that YAML anchors/aliases in `.chezmoidata` files resolve correctly (they're plain YAML syntax, resolved before chezmoi's template layer runs — no conflict with the "data files are static" rule).
- [x] 2.2 Run `chezmoi execute-template` to dump `(index .machines "MacBook Pro").syncthing_folders` and `(index .machines "Mac Studio").syncthing_folders` as JSON; confirm both are identical to each other and unchanged from the pre-refactor values.
- [x] 2.3 Run `chezmoi execute-template < home/.chezmoiscripts/run_onchange_after_darwin-94-setup-syncthing-folders.sh.tmpl`; confirm it renders with no errors.
- [x] 2.4 Confirm `machine-settings`/`machine-config` still correctly resolve the current machine's settings (e.g. `claude_default`, `brewfile`) after adding the new top-level key, proving it doesn't interfere with hostname-pattern matching in `machine-config`'s `range $pattern, $config := .machines`.
- [x] 2.5 Confirm empirically that a forward-referenced alias (anchor defined after `machines:`) fails to parse, establishing that `syncthing_shared_folders` must stay lexically above `machines:`.

## 3. Documentation

- [x] 3.1 Record the openspec change (this proposal/design/tasks/spec-delta set) documenting the already-applied refactor for future reference.
