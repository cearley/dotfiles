## 1. Script Reordering
- [x] 1.1 Rename `run_onchange_before_darwin-26-brew-bundle-install.sh.tmpl` to `run_onchange_before_darwin-28-brew-bundle-install.sh.tmpl`

## 2. Implementation
- [x] 2.1 Create `run_onchange_before_darwin-26-install-bun-packages.sh.tmpl` following the UV tools script pattern (position 25)
- [x] 2.2 Verify template renders correctly with `chezmoi execute-template`
- [x] 2.3 Test idempotent behavior: run `chezmoi apply` twice and confirm no errors on second run

## 3. Validation
- [x] 3.1 Run `chezmoi diff` to confirm the new script appears in the target state
- [x] 3.2 Verify `ralph-tui` is installed globally after `chezmoi apply`
- [x] 3.3 Confirm bun packages from unselected tags are skipped
- [x] 3.4 Confirm brew-bundle script still executes last in the package management group

## 4. Spec Updates
- [x] 4.1 Archive this change and apply spec deltas to `openspec/specs/package-management/spec.md`
