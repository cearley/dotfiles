## 1. Update packages.yaml

- [x] 1.1 Add `cargo` key to the `ai` section in `home/.chezmoidata/packages.yaml` with entry `'--git https://github.com/Dicklesworthstone/beads_rust.git'` for `beads_rust`

## 2. Create Cargo Installation Script

- [x] 2.1 Create `home/.chezmoiscripts/run_onchange_after_darwin-27-install-cargo-packages.sh.tmpl` with darwin platform guard, `dev` tag gate, `source ~/.cargo/env`, `require_tools cargo` check, and tag-iterating `cargo install` loop
- [x] 2.2 Verify the script template expands correctly: `chezmoi execute-template < home/.chezmoiscripts/run_onchange_after_darwin-27-install-cargo-packages.sh.tmpl`

## 3. Update Package Management Spec

- [x] 3.1 Apply the delta from `openspec/changes/add-cargo-packages/specs/package-management/spec.md` into `openspec/specs/package-management/spec.md` — add Cargo requirements sections and update the installation sequence scenario and tag reference table

## 4. Validate and Apply

- [x] 4.1 Run `chezmoi diff` and confirm only expected changes appear (packages.yaml, new script)
- [x] 4.2 Run `chezmoi apply` and verify the cargo installation script runs without errors on a `dev`+`ai` machine
- [x] 4.3 Confirm `beads_rust` binary is available in `~/.cargo/bin/` after apply
