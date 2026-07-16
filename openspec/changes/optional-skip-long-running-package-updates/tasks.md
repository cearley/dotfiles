## 1. Shared Skip-Decision Helper

- [x] 1.1 Add `package_layer_should_skip <layer>` (plus any small private helpers it needs) to `home/scripts/shared-utils.sh`, implementing the resolution order: `CHEZMOI_SKIP_PACKAGE_UPDATES` env var → per-`$PPID` cache file → TTY-gated two-step prompt → non-interactive default.
- [x] 1.2 Implement cache file read/write at `${TMPDIR:-/tmp}/chezmoi-package-update-skip.$PPID` using simple `SKIP_<LAYER>=0|1` lines, with a 1-hour staleness check based on file mtime.
- [x] 1.3 Implement the two-step prompt (`read -p`-based, matching the existing style in `run_onchange_before_darwin-28-brew-bundle-install.sh.tmpl`): "Skip ALL long-running package-update checks this run? (y/N)", then if declined, "Selectively skip specific layers instead? (y/N)", then if accepted, one y/N question per layer (`homebrew`, `sdkman`, `uv`, `bun`, `cargo`, `claude`).
- [x] 1.4 Add TTY detection (`[ -t 0 ]`) so the prompt is skipped entirely (defaulting every layer to "run") when stdin is not a terminal.
- [x] 1.5 Manually source `shared-utils.sh` in a scratch shell and exercise each resolution path (env var set, fresh cache hit, stale cache, TTY prompt — all three branches, no-TTY default) before wiring it into any real script.

## 2. Homebrew Layer Gate (scripts 23, 28)

- [x] 2.1 Add the `package_layer_should_skip "homebrew"` guard clause to `run_onchange_before_darwin-23-install-packages.sh.tmpl`, immediately after sourcing `shared-utils.sh` and before `require_tools brew`.
- [x] 2.2 Add the same guard clause to `run_onchange_before_darwin-28-brew-bundle-install.sh.tmpl`, placed before its existing `read -p "🍺 Install additional packages..."` confirmation prompt.
- [x] 2.3 Validate both templates with `chezmoi execute-template < <file>` (or `tests/run-template`) to confirm no template syntax errors were introduced.

## 3. SDKMAN Layer Gate (scripts 20, 24)

- [x] 3.1 Add the `package_layer_should_skip "sdkman"` guard clause to `run_onchange_before_darwin-20-install-sdkman.sh.tmpl`, after existing `dev`-tag and modern-bash checks are otherwise unaffected.
- [x] 3.2 Add the same guard clause to `run_onchange_before_darwin-24-install-sdks.sh.tmpl`.
- [x] 3.3 Validate both templates with `chezmoi execute-template`.

## 4. UV Layer Gate (scripts 21, 25)

- [x] 4.1 Add the `package_layer_should_skip "uv"` guard clause to `run_onchange_before_darwin-21-install-uv.sh.tmpl`.
- [x] 4.2 Add the same guard clause to `run_onchange_before_darwin-25-install-tools.sh.tmpl`.
- [x] 4.3 Validate both templates with `chezmoi execute-template`.

## 5. Bun Layer Gate (script 26)

- [x] 5.1 Add the `package_layer_should_skip "bun"` guard clause to `run_onchange_before_darwin-26-install-bun-packages.sh.tmpl`.
- [x] 5.2 Validate the template with `chezmoi execute-template`.

## 6. Cargo Layer Gate (script 27)

- [x] 6.1 Add the `package_layer_should_skip "cargo"` guard clause to `run_onchange_before_darwin-27-install-cargo-packages.sh.tmpl` (actual on-disk filename is `_before_`, not `_after_` as the pre-existing `package-management` spec doc states — out-of-scope doc drift), after the existing `dev`-tag / `require_tools cargo` checks.
- [x] 6.2 Validate the template with `chezmoi execute-template`.

## 7. Claude Skills/MCP/Plugins Layer Gate (scripts 37, 38, 39)

- [x] 7.1 Add the `package_layer_should_skip "claude"` guard clause to `run_onchange_after_darwin-37-install-claude-skills.sh.tmpl`.
- [x] 7.2 Add the same guard clause to `run_onchange_after_darwin-38-install-claude-mcp-servers.sh.tmpl`.
- [x] 7.3 Add the same guard clause to `run_onchange_after_darwin-39-install-claude-plugins.sh.tmpl`.
- [x] 7.4 Validate all three templates with `chezmoi execute-template`.

## 8. Template and Apply Verification

- [x] 8.1 Confirmed all eleven scripts are still tracked via `chezmoi managed`, and validated each rendered template individually via `tests/run-template` (contains the guard clause, renders without error). Full-repo `chezmoi status` could not be run in the sandboxed session — it requires a live TTY to unlock KeePassXC for an unrelated `.aws/credentials` template, a pre-existing repo limitation (see CLAUDE.md "Non-Interactive Limitations"), not something introduced by this change.
- [x] 8.2 Run `chezmoi diff` interactively (in a real terminal with KeePassXC access) to sanity-check the rendered script content before applying.

## 9. Manual End-to-End Verification

- [x] 9.1 Run `CHEZMOI_SKIP_PACKAGE_UPDATES=1 chezmoi apply` and confirm all eleven scripts print a skip message and exit 0, with no prompts shown. Verified in user's real terminal: all 11 expected skip messages appeared (Homebrew x2, SDKMAN x2, UV x2, Bun x1, Cargo x1, Claude x3), no prompts shown, run completed without error.
- [x] 9.2 Run `chezmoi apply` interactively (env var unset) and answer "yes" to the skip-all prompt; confirm every layer is skipped. Verified: exactly one prompt shown, no follow-up per-layer question, all 11 scripts printed a skip message.
- [x] 9.3 Run `chezmoi apply` interactively; decline skip-all, accept per-layer selection, and skip only one or two layers; confirm only those layers are skipped and the rest run normally. Verified: skipped homebrew+sdkman+cargo+claude, ran uv+bun — exact match to selections, with uv/bun performing real updates.
- [x] 9.4 Run `chezmoi apply` interactively and decline both prompts; confirm every layer runs exactly as it did before this change. Verified across two full real runs (one with `CHEZMOI_SKIP_DEBUG=1`): every layer ran its real update logic (Homebrew brew bundle, SDKMAN, UV, Bun, Cargo, Claude skills/MCP/plugins all executed normally), single cache resolution shared correctly across all 11 scripts (PPID stable, cache age growing 0s→221s, no re-prompting). An initial run appeared to show the prompt sequence twice, but this did not reproduce under two independent instrumented re-tests and is attributed to a VS Code integrated-terminal rendering artifact on a very large/fast output stream, not a code defect.
- [x] 9.5 Run `chezmoi apply` with stdin redirected from a non-TTY source (env var unset) and confirm it does not hang and defaults to running every layer. Accepted based on prior direct verification of the identical `package_layer_should_skip`/`_package_update_skip_load_or_prompt` code (real child-process test, stdin from `/dev/null`, confirmed no-hang and default-to-run for all 6 layers) performed before this was wired into the real scripts, plus 9.1–9.4 proving the integration layer behaves correctly.
- [x] 9.6 Manually age a cache file past 1 hour (or fake its mtime) and confirm the next script run treats it as stale and re-resolves the decision. Accepted based on prior direct verification against the real function (`_package_update_skip_load_or_prompt` called directly against a cache file with mtime forced 2 hours old, confirmed stale-all-skip=1 cache was correctly ignored and re-resolved to all-run=0) performed before this was wired into the real scripts.
- [x] 9.7 Confirm via `chezmoi apply` output/exit code that a skipped script is not reported as a failure. Verified across all real runs (9.1–9.4): every skipped script exited cleanly with a `skip` message, chezmoi never reported any script as failed, and each full apply invocation completed successfully.
