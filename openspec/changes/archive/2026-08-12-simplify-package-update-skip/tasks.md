## 1. Shared utility cleanup

- [x] 1.1 Remove `package_layer_should_skip()`, `_package_update_skip_load_or_prompt()`, and `_package_update_skip_resolve_and_cache()` from `home/scripts/shared-utils.sh`
- [x] 1.2 Grep the repo for any remaining reference to `package_layer_should_skip`, `CHEZMOI_SKIP_PACKAGE_UPDATES`, or `chezmoi-package-update-skip` to confirm nothing else depends on the removed mechanism

## 2. Remove skip guards from non-Homebrew layers (always-run scripts)

- [x] 2.1 `home/.chezmoiscripts/run_onchange_before_darwin-20-install-sdkman.sh.tmpl` — remove the `package_layer_should_skip "sdkman"` guard block
- [x] 2.2 `home/.chezmoiscripts/run_onchange_before_darwin-21-install-uv.sh.tmpl` — remove the `package_layer_should_skip "uv"` guard block
- [x] 2.3 `home/.chezmoiscripts/run_onchange_before_darwin-24-install-sdks.sh.tmpl` — remove the `package_layer_should_skip "sdkman"` guard block
- [x] 2.4 `home/.chezmoiscripts/run_onchange_before_darwin-25-install-tools.sh.tmpl` — remove the `package_layer_should_skip "uv"` guard block
- [x] 2.5 `home/.chezmoiscripts/run_onchange_before_darwin-26-install-bun-packages.sh.tmpl` — remove the `package_layer_should_skip "bun"` guard block
- [x] 2.6 `home/.chezmoiscripts/run_onchange_before_darwin-27-install-cargo-packages.sh.tmpl` — remove the `package_layer_should_skip "cargo"` guard block
- [x] 2.7 `home/.chezmoiscripts/run_onchange_after_darwin-37-install-claude-skills.sh.tmpl` — remove the `package_layer_should_skip "claude"` guard block
- [x] 2.8 `home/.chezmoiscripts/run_onchange_after_darwin-38-install-claude-mcp-servers.sh.tmpl` — remove the `package_layer_should_skip "claude"` guard block
- [x] 2.9 `home/.chezmoiscripts/run_onchange_after_darwin-39-install-claude-plugins.sh.tmpl` — remove the `package_layer_should_skip "claude"` guard block
- [x] 2.10 `home/.chezmoiscripts/run_onchange_after_darwin-44-register-claude-plugin-marketplace.sh.tmpl` — remove the `package_layer_should_skip "claude"` guard block
- [x] 2.11 Confirm each edited script still passes `set -euo pipefail` cleanly with no dangling reference to the removed guard (e.g. no orphaned `fi` or unused `source` lines)

## 3. Split the core Homebrew installer (script 23)

- [x] 3.1 `home/.chezmoiscripts/run_onchange_before_darwin-23-install-packages.sh.tmpl` — remove the `package_layer_should_skip "homebrew"` guard block
- [x] 3.2 Split the single `brew bundle --file=/dev/stdin <<'BUNDLE_EOF' ... BUNDLE_EOF` heredoc into two: one containing only `tap` and `brew` lines (run unconditionally, right after `brew update`), one containing only `cask` and `mas` lines
- [x] 3.3 Before running the cask/mas bundle, check whether it has any content; if empty, skip the bundle step entirely with no prompt
- [x] 3.4 If the cask/mas bundle is non-empty, add a `read -p "Install casks/mas packages? (y/N): "` confirmation (wording consistent with script 28's existing prompt) with no TTY guard — matching the "User Confirmation for Additional Packages" and "Homebrew Core Bundle Split" requirements in `openspec/specs/package-management/spec.md`
- [x] 3.5 On decline (or no TTY), skip the cask/mas bundle and exit 0 via the existing partial-failure/print_message conventions; do not affect the exit status contributed by the taps/brews bundle
- [x] 3.6 Verify the existing pre-tap loop (which registers taps before either bundle runs) and the `$icloudSignedIn` / `HOMEBREW_BUNDLE_MAS_SKIP` mas-gating logic still apply correctly to the split cask/mas bundle
- [x] 3.7 Verify the existing "Homebrew Bundle Partial Failure Resilience" and "Brew Bundle Failure Propagation" behavior (warn-and-continue vs. exit non-zero) is preserved independently for each of the two bundle invocations

## 4. Simplify the machine-specific Brewfile installer (script 28)

- [x] 4.1 `home/.chezmoiscripts/run_onchange_before_darwin-28-brew-bundle-install.sh.tmpl` — remove the `package_layer_should_skip "homebrew"` guard block (lines 8–11 in the current file); leave its existing `read -p "🍺 Install additional packages from your brewfile? (y/N): "` prompt and everything below it untouched

## 5. Template rendering verification

- [x] 5.1 Run `tests/run-template` against each of the 12 scripts touched in sections 2–4 to confirm they still render valid, syntactically correct bash for at least one representative tag set (e.g. `core,dev,ai`) — all 12 rendered and passed `bash -n`
- [x] 5.2 Specifically render script 23 for a tag set with a non-empty cask/mas list and confirm the output contains two distinct `brew bundle` invocations with the correct entries in each — confirmed against this machine's real (all-tags) config: taps+brews bundle and a separate cask/mas bundle behind the confirmation prompt, both correctly populated
- [x] 5.3 Specifically render script 23 for a tag set with an empty cask/mas list (if one exists, e.g. `core` only on a machine with no casks/mas in that category) and confirm no prompt is emitted in the generated script — no tag on this machine has zero casks/mas, so verified the underlying `$hasCaskOrMas` boolean logic in isolation via `tests/run-template --inline` instead: empty cask/mas dicts correctly resolve to `false` (prompt suppressed), non-empty correctly resolve to `true`
- [x] 5.4 Run `chezmoi status` (not `chezmoi diff`, which needs a TTY) against the rendered changes to confirm only the 12 target scripts changed — could not run: `chezmoi status` fails in this sandbox on an unrelated `modify_private_credentials.tmpl` KeePassXC/TTY dependency before it reaches script evaluation (pre-existing environment limitation, not caused by this change). Additionally, `.chezmoiscripts/*` entries are a distinct managed-entry category that `chezmoi status` doesn't content-diff the way regular target files are — substituted with the per-script `tests/run-template` + `bash -n` checks in 5.1, which are the meaningful correctness signal here. Recommend a manual `chezmoi status` from an interactive terminal as a final sanity check before archiving.

## 6. OpenSpec validation

- [x] 6.1 Run `openspec validate simplify-package-update-skip --strict` and resolve any reported issues before implementation is considered complete — passes

## 7. Split cask/mas into independent prompts (post-implementation feedback)

- [x] 7.1 `home/.chezmoiscripts/run_onchange_before_darwin-23-install-packages.sh.tmpl` — replace the single `$hasCaskOrMas` boolean with independent `$hasCasks`/`$hasMas` booleans, each computed per-category as before (mas still respecting `$icloudSignedIn`)
- [x] 7.2 Replace the single combined cask/mas prompt and `CASK_MAS_EOF` bundle with two independent prompts and bundles: `CASK_EOF` (casks only, gated by its own `read -p`) and `MAS_EOF` (mas only, gated by its own `read -p`), each with its own exit-code variable and warning message
- [x] 7.3 Verify both empty-case suppressions independently (no casks → no cask prompt; no mas or not signed into iCloud → no mas prompt) via `tests/run-template --inline` boolean checks
- [x] 7.4 Render the full script via `tests/run-template` against this machine's real config and confirm both prompts appear with correctly-scoped entries, and `bash -n` passes
- [x] 7.5 Update `specs/package-management/spec.md` delta ("User Confirmation for Additional Packages", "Homebrew Core Bundle Split") and `design.md` to describe two independent prompts for script 23; leave script 28's single combined prompt as documented, unchanged
- [x] 7.6 Re-run `openspec validate simplify-package-update-skip --strict`
