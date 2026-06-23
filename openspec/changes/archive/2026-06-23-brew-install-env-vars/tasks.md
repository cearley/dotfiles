## 1. Data Layer — packages.yaml

- [x] 1.1 Add `brew_env: { HOMEBREW_ACCEPT_EULA: "Y" }` to `packages.darwin.work` in `home/.chezmoidata/packages.yaml`, positioned between the `taps` key and the `brews` key for that category

## 2. Template — darwin-23 install-packages script

- [x] 2.1 In `home/.chezmoiscripts/run_onchange_before_darwin-23-install-packages.sh.tmpl`, add a Go template block after the `brew update` line that:
  - Iterates active categories (same `$categories` loop as brews/casks)
  - Checks `hasKey $categoryData "brew_env"`
  - Accumulates key-value pairs into a `$allEnv` dict (using `set`)
  - Renders `export KEY={{ $v | quote }}` lines for all collected vars

- [x] 2.2 Verify the export block appears before the `brew bundle --file=/dev/stdin` heredoc in the rendered output

## 3. Template Testing

- [x] 3.1 Run `tests/run-template home/.chezmoiscripts/run_onchange_before_darwin-23-install-packages.sh.tmpl` and confirm `export HOMEBREW_ACCEPT_EULA="Y"` appears in the output when the `work` tag is active

- [x] 3.2 Confirm the export line appears before the `brew bundle` line in the rendered output

- [x] 3.3 Temporarily add a second `brew_env` key to another active category (e.g., `core`) with the same key, run the template, and confirm the `work` category's value wins (last in iteration order). Revert after verifying.

## 4. Spec Archive Update

- [x] 4.1 Add the new `brew_env` requirement from the change's delta spec into `openspec/specs/package-management/spec.md` (under a new "Requirement: Category-Level Brew Install Environment Variables" section)

- [x] 4.2 Update the "Tag-Based Package Categories" requirement in `openspec/specs/package-management/spec.md` to list `brew_env` as a valid category key alongside `taps`, `brews`, `casks`, etc.
