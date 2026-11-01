# Tasks

## 1. `run_onchange_before_darwin-23-install-packages.sh.tmpl` (package position 23)

- [x] 1.1 Change the taps+formulae bundle invocation from bare `brew bundle` to `brew bundle install --no-upgrade --file=/dev/stdin <<'...'`. Verify by rendering the template with `tests/run-template home/.chezmoiscripts/run_onchange_before_darwin-23-install-packages.sh.tmpl` and confirming the heredoc content is unchanged and only the invoking command differs from today's output.
- [x] 1.2 Remove the `read -p "🍺 Install cask packages? (y/N): "` prompt block and its `$REPLY`/non-TTY branch entirely; change the cask bundle invocation to run unconditionally (still skipped render-time when `$hasCasks` is false) as `brew bundle install --no-upgrade --file=/dev/stdin <<'CASK_EOF'`. Verify by rendering the template and confirming the cask section contains no `read -p` and installs whenever `$hasCasks` is true, with no prompt.
- [x] 1.3 Apply the same change to the `mas` section: remove its `read -p` prompt and non-TTY branch, change its invocation to `brew bundle install --no-upgrade --file=/dev/stdin <<'MAS_EOF'`, still skipped render-time when `$hasMas` (which already factors in `$icloudSignedIn`) is false. Verify the same way as 1.2.
- [x] 1.4 After the three missing-item install invocations, add one combined `brew bundle check --verbose --file=/dev/stdin <<'CHECK_EOF'` containing the full declared set for the active tag set (taps + brews + casks + mas, same content as the three install heredocs combined), capturing its exit status in a variable (e.g. `check_exit`). Verify by tracing the rendered script: the check heredoc's content must match the union of what the three install heredocs just installed.
- [x] 1.5 Add one combined upgrade prompt, shown only when `check_exit` is non-zero: print the captured `--verbose` output, then `read -p "🍺 N packages have updates available — install them now? (y/N): "` (with the existing `[ -t 0 ]` non-TTY guard defaulting `REPLY=N`), and on `y` run `brew bundle install --upgrade --file=/dev/stdin <<'UPGRADE_EOF'` against the same combined set from 1.4. Verify by tracing all four branches: check passes (no prompt, no upgrade), check fails + TTY + accept (upgrade runs), check fails + TTY + decline (skip, exit 0), check fails + non-TTY (skip, exit 0, no hang).
- [x] 1.6 Preserve `any_failed`-style partial-failure tracking across all invocations now present (up to five: taps+brews install, cask install, mas install, combined check, conditional combined upgrade) — a non-zero exit from any install or upgrade invocation sets the failure flag and emits a scoped `print_message "warning"`, matching the existing pattern; the combined `check` invocation's non-zero exit is expected/normal (it's the upgrade-prompt trigger) and must NOT set the failure flag. Verify by tracing the script's final `if [ "$any_failed" -eq 1 ]; then exit 1; fi` against each invocation's possible exit codes.

## 2. `run_onchange_before_darwin-28-brew-bundle-install.sh.tmpl` (package position 28)

- [x] 2.1 Replace the single `brew bundle check` → prompt → bare `brew bundle` sequence with: `brew bundle install --no-upgrade --file=$brewfile` unconditionally (once the existing "brewfile not found" early-exit has passed), then `brew bundle check --verbose --file=$brewfile` to detect staleness, then — only if that check fails — the existing `read -p "🍺 Install additional packages from your brewfile? (y/N): "` prompt (reworded to reference updates, e.g. "...have updates available — install them now?"), gating a final `brew bundle install --upgrade --file=$brewfile`. Verify by rendering the template with `tests/run-template home/.chezmoiscripts/run_onchange_before_darwin-28-brew-bundle-install.sh.tmpl` and tracing all branches (brewfile missing, brewfile present and fully current, brewfile present with something missing, brewfile present with something outdated only).
- [x] 2.2 Confirm the existing iCloud/`HOMEBREW_BUNDLE_MAS_SKIP` gating (`warn_icloud_not_signed_in` / `_icloud_available`) still applies to both the no-upgrade install and the conditional upgrade bundle, not just one of them. Verify by tracing the rendered script with iCloud both signed-in and signed-out.

## 3. Template and syntax validation

- [x] 3.1 Render both templates via `tests/run-template` for at least two representative tag combinations (e.g. `core` only, and `core+dev+ai`) and confirm no Go-template rendering errors in either.
- [x] 3.2 Run `bash -n` against each rendered script output to confirm valid shell syntax after the restructuring.
- [x] 3.3 By hand, trace each rendered script against every scenario in `specs/package-management/spec.md`'s "User Confirmation for Additional Packages" and "Homebrew Core Bundle Split" requirements (no items declared, items declared and all current, items declared and something outdated, non-TTY session) and confirm the rendered logic satisfies each. Do not execute either rendered script for real against this machine's live Homebrew state as part of this task — that risks real installs/upgrades outside a controlled test; live validation is deferred to the workflow follow-up below.

## 4. Spec validation

- [x] 4.1 Run `openspec validate decouple-package-install-and-upgrade --strict` (or the project's equivalent validate command) and confirm it passes — no scenario-formatting or requirement-length warnings in the new spec delta.

## Workflow follow-up

- Run `/opsx:apply` to implement these tasks.
- After implementation, manually run `chezmoi apply` on a real machine to exercise the actual scripts end-to-end (confirm a newly-added package installs with no prompt, and that an outdated package triggers exactly one combined upgrade prompt) before considering this change verified.
- Run `/opsx:verify` once live behavior is confirmed.
- Archive the change (`openspec archive decouple-package-install-and-upgrade --yes`) after verification.
