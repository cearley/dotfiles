# Verification Evidence: harden-chezmoi-operational-resilience

Compiled per task 8.3, so a reviewer can verify all six findings without re-deriving them.

## 1-2. Run_onchange failure propagation + non-destructive MCP replacement

`run_onchange_before_darwin-23-install-packages.sh.tmpl` and `run_onchange_after_darwin-38-install-claude-mcp-servers.sh.tmpl` both gained a script-level `any_failed` accumulator, set on any per-item warning branch, checked once at the end with `exit 1` if set — non-critical per-item failures still continue past each other exactly as before; only the final exit code changed, so chezmoi's own retry-on-failure now actually retries these scripts.

Script 38 additionally captures a server's prior registration (`$name`/`$cmd`/`$_env_flags`/`$scope`, already in scope) before removing it in the `"already exists"` replacement path. If the retry `mcp add` fails, it re-issues `mcp add` with the captured values to restore the prior registration before reporting failure — a failed replacement no longer leaves a server unregistered.

Verified with a synthetic 3-server scratch harness + stateful stub `claude` CLI covering: clean register, hard failure, already-exists-retry-fails-restore-succeeds, and the unchanged all-success path. Exit codes and final registry state confirmed for each case.

## 3. Private package-index dependency-confusion guard

`private_pip.conf.tmpl`'s global `[global]`/`extra-index-url` block (which applied to every `pip install` on the machine) was replaced with a comment-only doc block containing the same `keepassxcAttribute`-sourced URLs plus per-invocation usage instructions (`pip install --index-url <url> <package>` / `PIP_INDEX_URL=<url> pip install <package>`). A plain `pip install <name>` no longer consults the private index at all, closing the confusion vector structurally.

Grep sweep (`grep -rn "extra-index-url\|pip.conf" home/ --include=*.tmpl`) found one dependent site: `run_onchange_after_darwin-45-setup-github-auth.sh.tmpl`'s `setup_pip_github` printed a now-misleading "pip configured for GitHub Packages" message based solely on the file's existence. Updated to state the instructions are available for per-invocation use, not global configuration.

## 4. LaunchAgent teardown on persona removal

`run_onchange_after_darwin-40-load-claude-launchagent.sh.tmpl`'s `$PLIST`/`$LABEL` computation moved before the `if not $claudeDefault` early-exit branch. That branch now checks whether `$PLIST` exists; if so, it runs `launchctl bootout gui/$(id -u)/$LABEL` (tolerating "not loaded") and `rm -f "$PLIST"` before exiting, instead of silently leaving a stale LaunchAgent active.

Verified with a scratch harness (dummy plist + stubbed `launchctl`): teardown path removes the plist and invokes `bootout` with the correct label; no-plist path is unchanged (exit 0, no `launchctl` call). The existing "claude_default IS set" install/idempotent-bootstrap path confirmed byte-for-byte untouched.

## 5. Complete package-audit declaration set

`audit-packages.tmpl`'s Homebrew declared-set computation (`declared_for "brews"` and the cask/tap equivalents) now unions in the machine-specific Brewfile's entries (resolved via the same `machine-settings` partial and path formula script 28 uses), extracted via `grep -oE` rather than a full Brewfile-DSL parser.

Verified with a fixture Brewfile (`tap "homebrew/cask-fonts"`, `brew "wget"`, `brew "htop"`, `cask "font-fira-code"`) plus a fixture `packages.yaml`: Brewfile-only entries no longer appear as orphans, while a package present in neither fixture still correctly flags as an orphan (no over-suppression). The existing tag-based orphan scenarios (no Brewfile case) reproduce byte-identical pre/post-change output.

## 6. Pinned executable externals

All `type = "archive"` entries across both `.chezmoiexternal.toml.tmpl` files, plus the 3 `type = "git-repo"` entries (converted to pinned `archive` entries — chezmoi v2.72.2's `git-repo` external has no ref-pinning field, and even a manual pin would be undone by the next `refreshPeriod`-triggered `git pull`), are now pinned to specific commit SHAs instead of tracking `master`/`main`:

| Repo | Branch | Resolved SHA |
|---|---|---|
| ohmyzsh/ohmyzsh | master | `83a0ec79ee3b1f64c6ae2e80dcb1fb27a55e5952` |
| zdharma-continuum/fast-syntax-highlighting | master | `4672ad5dd9ad68a7effc1476d65afb7c584ce2b3` |
| marlonrichert/zsh-autocomplete | main* | `77706d4cf24866bf62b865d97e9ef7d8bc38bd6e` |
| zsh-users/zsh-autosuggestions | master | `85919cd1ffa7d2d5412f6d3fe437ebdbeeec4fc5` |
| cearley/zsh-claude-env | main | `668833fe076f21534bbf9ceed3e53da11339c590` |
| romkatv/zsh-defer | master | `53a26e287fbbe2dcebb3aa1801546c6de32416fa` |
| romkatv/powerlevel10k | master | `d05a1b00f9a61f9578bf9dc19b8451942dde8734` |
| davila7/claude-code-templates (jev-model-router) | main | `c3a74d3ef9ed8076eeb1e3370cc0fc0cc398bdfa` |
| cearley/zsh-llm-suggestions (git-repo→archive) | master | `73fee019a63843beebad7e31cd3be47148ddece9` |
| bitovi/freshbooks-mcp-server (git-repo→archive) | main | `a111a76fef66b2899f4a051b9f604c6dc7c45a98` |
| cearley/zsh-functions (git-repo→archive) | master | `3fe6281cde63ee899f6dd9d6a3e192ade9678e9e` |

\* `zsh-autocomplete` has no `master` branch — the original template's `archive/master.tar.gz` URL was silently resolving via an undocumented GitHub codeload compatibility fallback, not tracking the branch it claimed to. Now moot since it's SHA-pinned.

All 11 resolved-SHA URLs verified reachable (HTTP HEAD, 200) and both files confirmed to still parse as valid TOML after the edit. `home/.chezmoitemplates/CLAUDE.md` gained an "External Dependencies" section documenting the pinning convention and update procedure.

## 7. CI exercises the checkout under test

`remote_install.sh` now honors the `$REPO` env var `.github/workflows/ci.yml` already sets (`set -- --source "$REPO" "$@"`), pointing chezmoi at the actual checkout instead of a fresh clone — no change needed to how the workflow invokes the script.

This surfaced two pre-existing, independent bugs, both fixed:
- **`home/.chezmoi.toml.tmpl`'s hook path**: `[hooks.read-source-state.pre]`'s `command` was a hardcoded path relative to the *default* source location, breaking under any non-default `--source`. Fixed to derive from `dir .chezmoi.sourceDir` (accounting for `.chezmoiroot: home` shifting `.chezmoi.sourceDir` into the `home/` subtree — the hook script lives at the repo root, a sibling of `home/`).
- **CI's fixture `chezmoi.toml`**: its `[data]` block was stale, missing most of `home/.chezmoi.toml.tmpl`'s `promptStringOnce` keys — today's CI would already hang/fail on a `/dev/tty` prompt attempt, independent of this change. Expanded to cover the full key set.

`ci.yml` now adds `--apply` to the `init` invocation (previously `init`-only, not satisfying `ci-validation`'s "SHALL render and apply") and rewrote the result-verification step to check `chezmoi --source "$REPO" source-path` resolves to `$REPO/home` and that `~/.gitconfig` was actually applied.

Verified end-to-end against a scratch clone + sandboxed `$HOME`: `REPO=<scratch> ./remote_install.sh init --apply` exits 0, resolves to the scratch checkout, and a marker comment added only to the scratch clone's `dot_gitconfig.tmpl` appeared in the actually-applied `$HOME/.gitconfig` — proving the checkout under test is the one being exercised, not a disconnected bootstrap.

**Known follow-up, deliberately not addressed**: the existing 300s CI timeout may be tight now that `--apply` runs a real (non-secret-gated) `brew bundle` on a fresh runner. Left as-is per explicit user decision (watch the next CI run; address separately if it times out).

Also fixed: `tests/run-template`'s `mktemp` suffix collision (BSD `mktemp` doesn't randomize a template with a literal suffix after the `X`s) — verified with 8 concurrent invocations, no collisions.

## 8. Integration verification

- `openspec validate --changes harden-chezmoi-operational-resilience --strict` → 0 errors.
- Drift check: `git status --short` showed exactly 13 modified files, matching the sum across all 5 workers' assigned file lists — no unintended drift.
