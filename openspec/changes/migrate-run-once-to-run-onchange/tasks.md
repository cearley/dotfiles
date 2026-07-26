## 1. Verify already-converted scripts (no changes expected)

- [ ] 1.1 Confirm `run_onchange_after_darwin-35-install-nvm.sh.tmpl` carries a `time-bucket` trigger comment (already present: 30 days)
- [ ] 1.2 Confirm `run_onchange_before_darwin-10-install-rust.sh.tmpl` carries a `time-bucket` trigger comment (already present: 30 days)
- [ ] 1.3 Confirm `run_onchange_before_darwin-20-install-sdkman.sh.tmpl` carries a `time-bucket` trigger comment (already present: 30 days)
- [ ] 1.4 Confirm `run_onchange_before_darwin-21-install-uv.sh.tmpl` carries a `time-bucket` trigger comment (already present: 30 days)

## 2. Convert `83-login-atuin` to run_onchange_ (7-day cadence)

- [ ] 2.1 `git mv home/.chezmoiscripts/run_once_after_darwin-83-login-atuin.sh.tmpl home/.chezmoiscripts/run_onchange_after_darwin-83-login-atuin.sh.tmpl`
- [ ] 2.2 Add trigger comment near the top: `# rerun trigger (7d): {{ includeTemplate "time-bucket" (dict "days" 7) }}`
- [ ] 2.3 Verify with `tests/run-template home/.chezmoiscripts/run_onchange_after_darwin-83-login-atuin.sh.tmpl` and `bash -n` on the rendered output

## 3. Convert `85-configure-system-defaults` to run_onchange_ (90-day cadence)

- [ ] 3.1 `git mv home/.chezmoiscripts/run_once_after_darwin-85-configure-system-defaults.sh.tmpl home/.chezmoiscripts/run_onchange_after_darwin-85-configure-system-defaults.sh.tmpl`
- [ ] 3.2 Add trigger comment near the top: `# rerun trigger (90d): {{ includeTemplate "time-bucket" (dict "days" 90) }}`
- [ ] 3.3 Verify with `tests/run-template home/.chezmoiscripts/run_onchange_after_darwin-85-configure-system-defaults.sh.tmpl` and `bash -n` on the rendered output

## 4. Document rationale on scripts staying run_once_

- [ ] 4.1 Add a one-line rationale comment to `run_once_after_darwin-36-install-claude-code.sh.tmpl` (skip-only logic never upgrades on re-run)
- [ ] 4.2 Add a one-line rationale comment to `run_once_after_darwin-80-setup-microsoft-defender.sh.tmpl` (interactive one-shot installer, presence doesn't spontaneously drift)
- [ ] 4.3 Add a one-line rationale comment to `run_once_after_darwin-82-setup-global-protect.sh.tmpl` (interactive one-shot installer, presence doesn't spontaneously drift)
- [ ] 4.4 Add a one-line rationale comment to `run_once_before_darwin-05-install-rosetta.sh.tmpl` (OS-level one-shot install, does not go stale)

## 5. Spec sync and validation

- [ ] 5.1 Run `openspec validate migrate-run-once-to-run-onchange --strict` and fix any issues
- [ ] 5.2 After apply, sync the `script-execution` delta spec into `openspec/specs/script-execution/spec.md` (`openspec archive migrate-run-once-to-run-onchange --yes` or `/opsx:sync` + `/opsx:archive`)
- [ ] 5.3 Confirm `chezmoi apply --dry-run` succeeds (or `chezmoi diff` for the 2 renamed scripts if a full dry-run isn't available non-interactively)
