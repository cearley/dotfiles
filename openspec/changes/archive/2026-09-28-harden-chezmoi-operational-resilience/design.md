# Design

## Context

See `proposal.md` - Why for the six findings this addresses (a seventh, SDKMAN/uv ordering, needs no design work — it's covered by an existing requirement, see proposal's Non-goals). Six independent fixes to already-shipped mechanisms, grouped into one change because they share an origin (the same Codex review pass) and none compete for the same files. `chezmoi v2.72.2` is the version installed on this machine; syntax below is checked against it.

**Finding groundwork — run_onchange retry semantics**: chezmoi tracks, per `run_onchange_` script, whether the last invocation (keyed by the script's rendered-content hash) completed successfully. A script that exits non-zero is NOT recorded as successfully applied, so the next `chezmoi apply` re-attempts it even though its rendered content is unchanged. A script that exits `0` — even after printing a warning about an internal partial failure — IS recorded as successful, and will not be re-attempted until its content changes. Scripts 23 (`brew bundle`) and 38 (MCP registration) currently only ever print warnings and always exit `0` on partial failure, which is what breaks their own "run `chezmoi apply` again" advice.

**Finding groundwork — MCP replacement ordering**: script 38's per-server loop, on detecting `"already exists"` from `mcp add`, runs `mcp remove` unconditionally before retrying `mcp add`. If the retry's `mcp add` fails, the server is left unregistered — worse than its prior state.

**Finding groundwork — pip dependency confusion**: `pip.conf.tmpl`'s `[global] extra-index-url` block applies to every `pip install` invocation on the machine (not just ones the user intends to hit the private index), and pip's index resolution for `extra-index-url` does not itself scope by package-name prefix — any `pip install <name>` on the machine now consults both indexes, and a same-named public package can be selected depending on version/timing, independent of user intent.

**Finding groundwork — LaunchAgent teardown**: script 40's existing early-exit (`if not $claudeDefault { exit 0 }`) has no corresponding teardown path — it was written for the "never had a LaunchAgent" case, not the "had one, now don't" case, and both currently look identical to the script (early exit either way).

**Finding groundwork — package-audit Brewfile gap**: `audit-packages`'s `declared_for "brews"` (called from `_audit_homebrew_formulae`) reads only `packages.yaml` via `yq`. Script 28 additionally installs `{{ .chezmoi.sourceDir }}/brewfiles/<machine-brewfile>` when the active machine's settings declare one (`$settings.brewfile`) — this Brewfile path is resolvable the same way script 28 resolves it, from the same `machine-settings` partial the audit script could call.

**Finding groundwork — unpinned externals**: `.chezmoiexternal.toml.tmpl`'s `type = "archive"` entries fetch GitHub tarballs at `.../archive/<ref>.tar.gz` — GitHub accepts any ref (branch name, tag, or full commit SHA) in that URL path, so pinning is a matter of replacing `master`/`main` with a specific commit SHA, no schema change needed. The `type = "git-repo"` entries (`zsh-llm-suggestions`, `freshbooks-mcp-server`, `zsh-functions`) clone/mirror the repository directly; chezmoi's git-repo external type does not have a documented per-entry ref-pinning field as of v2.72.2 (flagged as an Open Question below).

**Finding groundwork — CI**: `.github/workflows/ci.yml` sets `REPO: ${{ github.workspace }}` as an env var on the `remote_install.sh init` step, but `remote_install.sh` never references `$REPO` (confirmed via `grep -n REPO remote_install.sh` — zero matches). The script has no flag or env var to point it at an existing local checkout instead of doing its own clone/bootstrap from scratch.

## Goals / Non-Goals

**Goals:**
- Fix all six findings with the smallest change that closes the actual gap, matching this repo's established idioms (`print_message`, `shared-utils.sh`, `machine-settings` partial) rather than introducing new patterns.
- Leave every other behavior of the six touched capabilities unchanged.

**Non-Goals:**
- Auditing every `run_onchange_` script for the retry-semantics gap — only scripts 23 and 38, the ones the review identified, are in scope for `tasks.md`. The new `script-execution` requirement applies repo-wide going forward, but retrofitting every other script is a separate follow-up if pursued.
- Redesigning `pip.conf`'s credential model — the fix scopes how the private index is applied, not how its credentials are sourced (still KeePassXC, still `keepassxcAttribute`, unchanged).
- Rewriting `remote_install.sh`'s bootstrap flow — the CI fix adds a minimal "use this checkout" path, not a general refactor of the installer.
- A general externals-update-cadence tool or Renovate-style automation for pinned refs — bumping a pin remains a manual, deliberate edit (see proposal's Non-goals).

## Decisions

### Decision 1: Failure propagation via a shared exit-code accumulator pattern, not per-script rewrites
Each affected script (23, 38) already tracks per-item success/failure locally (`brew_exit`, `_mcp_exit` per server). The fix is to accumulate a script-level failure flag across all items and `exit 1` at the very end if any item failed — after all items have been attempted, preserving the existing "continue past non-critical failures" behavior. No new shared-utils function is needed: `local any_failed=0` set on each per-item failure path, checked once before the script's final exit, is sufficient and matches the existing style (script 23 already has a `brew_exit`/`mas_exit` local pattern to extend).

**Alternative considered**: add a `require_all_succeeded` helper to `shared-utils.sh`. Rejected: only two call sites exist today; a shared helper for two call sites with slightly different item-tracking shapes (brew bundle's own exit code vs. a per-server loop) adds indirection without removing duplication.

### Decision 2: MCP replacement — attempt the new registration before removing the old one, where the CLI allows it; otherwise capture-and-restore
`claude mcp add` for a name that `"already exists"` currently requires `remove` first (the CLI itself refuses to overwrite in place, per the existing script's own comment path). The fix: before removing, capture the existing server's registration details (already available in `_mcp_output`/the loop's own `$cmd`/`$env_flags`/`$scope` variables — no new lookup needed) so that if the retry's `mcp add` fails after removal, the script re-issues the original `mcp add` with the captured prior values to restore it, then reports failure and exits non-zero (Decision 1).

**Alternative considered**: check server reachability before removing (e.g. dry-run the new command). Rejected: `claude mcp add` has no dry-run mode; capture-and-restore is the only mechanism that doesn't require one.

### Decision 3: pip dependency-confusion fix — drop the global `extra-index-url`, scope private-index use to explicit invocation
Remove `pip.conf.tmpl`'s machine-wide `[global] extra-index-url` block entirely. In its place, `private_pip.conf.tmpl` still renders the same private-index URL(s), but under a **named, non-global** pip config section the user opts into per-invocation (`pip install --index-url <url> <package>`, or `PIP_INDEX_URL=<url> pip install <package>` for a single call) rather than a config file pip consults for every install on the machine. This closes the confusion vector structurally — a plain `pip install <anything>` no longer ever consults the private index at all, so there is nothing for a public package to be confused with — rather than trying to make the global config "smarter" about scoping, which plain `pip.conf` has no mechanism for.

**Alternative considered**: keep `extra-index-url` global but add `--index-url` (not `--extra-index-url`) semantics, which is "first-index-wins" rather than "any-index-may-match." Rejected: even first-index-wins doesn't prevent a public package colliding with a private name if the public index happens to be checked first for an unrelated install, and pip's precedence behavior for `extra-index-url` has historically been inconsistent across versions — not a guarantee worth relying on for a security property.
**Alternative considered**: switch to a private PyPI proxy (Artifactory/Nexus-style) that fronts public PyPI. Rejected as out of scope: introduces new infrastructure to run and maintain, disproportionate to a personal dotfiles repo's two private-index use cases (GitHub Packages, Azure Artifacts).

### Decision 4: LaunchAgent teardown — always check for the plist's existence, independent of the early-exit branch
Restructure script 40 so the "no `claude_default`" branch, instead of `exit 0` immediately, first checks whether `$PLIST` exists on disk. If it does, tear it down (`launchctl bootout gui/$(id -u)/$LABEL` tolerating "not loaded", then `rm -f $PLIST`) and log via `print_message`, then exit 0. If it doesn't exist, behavior is unchanged (exit 0, nothing to do). This reuses the script's own existing `$PLIST`/`$LABEL` variable derivation (already computed from `{{ .reverse_dns }}` before the early-exit branch would need to move below that computation).

**Alternative considered**: a separate teardown script/hook triggered on `config.yaml` changes. Rejected: script 40 already `run_onchange_`s on `claude_default` changes (per its own header comment), so it already re-executes at exactly the right time — no new trigger mechanism needed, just handling both directions of the same transition it already observes.

### Decision 5: package-audit Brewfile union — resolve the same way script 28 does, reusing `machine-settings`
`_audit_homebrew_formulae`'s `declared_for "brews"` call gets a second source unioned in: read `$settings.brewfile` via the same `machine-settings` partial script 28 already uses, resolve `{{ .chezmoi.sourceDir }}/brewfiles/<name>`, and if that file exists, parse its `brew "..."` / `cask "..."` / `tap "..."` lines (a `grep -oE` pass is sufficient — the Brewfile format is a constrained Ruby DSL, not general Ruby) into the same declared-set stream `declared_for` already produces, before the existing `sort`/`comm -23` comparison.

**Alternative considered**: invoke `brew bundle list --file=<brewfile>` instead of grep-parsing. Rejected: `brew bundle list` requires Homebrew to actually evaluate the Brewfile (slower, and fails if any listed tap/cask is unavailable), where the audit only needs the declared *names*, which a grep pass gets cheaply and matches how `report_orphans`'s existing comparison already works (plain sorted name lists).

### Decision 6: externals pinning — pin `type = "archive"` entries via tarball URL ref; `type = "git-repo"` entries need an implementation-time check
For every `type = "archive"` entry (`.oh-my-zsh` and its five plugin/theme sub-entries, the `jev-model-router` mod files), replace `master`/`main` in the tarball URL with the specific commit SHA currently at the head of that branch, resolved once at implementation time (`git ls-remote <repo> <branch>`). For the three `type = "git-repo"` entries, `tasks.md` includes a step to check current chezmoi documentation/`chezmoi.toml` schema for a ref-pinning field (e.g. some chezmoi versions support a `type = "archive"` fallback using a GitHub tarball URL instead of `git-repo`, which would let these three follow Decision 6's archive approach uniformly) — if no pinning field exists, convert them to `type = "archive"` tarball entries at a pinned SHA instead, since GitHub serves a tarball for any repo at any ref.

**Alternative considered**: leave `git-repo` entries unpinned since they're a minority. Rejected: `freshbooks-mcp-server` and the zsh function/suggestion repos are still executable content (an MCP server build, sourced zsh functions) — the same threat model as the archive entries applies.

## Risks / Trade-offs

- **[Risk] Pinned refs go stale and this repo won't notice a legitimate upstream security fix landing on the tracked branch** → Mitigation: accepted trade-off, matching the proposal's explicit non-goal (deliberate, manual pin updates over automatic tracking) — the alternative (auto-tracking) is the vulnerability this change closes.
- **[Risk] The pip fix changes the ergonomics of installing from the private index (no longer "just works" via global config)** → Mitigation: this is the fix's entire point — friction here is the security property. `tasks.md` includes documenting the new per-invocation usage so it isn't a silent surprise.
- **[Risk] Script 38's capture-and-restore (Decision 2) could itself fail if the restore `mcp add` also fails** → Mitigation: in that case the script still reports the failure and exits non-zero (Decision 1), so the user is not misled into thinking the server is registered — the improvement over today is "never worse than before," not "guaranteed success."
- **[Risk] Grep-parsing the Brewfile (Decision 5) could miss an edge-case Brewfile syntax (e.g. a formula name split across lines)** → Mitigation: this repo's existing machine Brewfiles are simple, single-line `brew "name"` entries (consistent with `brew bundle dump`'s own output format per script 28's maintenance comment); a mismatch here produces an over-cautious orphan report, not a destructive action, since `audit-packages` is read-only.

## Migration Plan

Purely corrective — no new files beyond the pinned-ref edits and script logic changes, no schema changes, no data migration. Deploys on the next `chezmoi apply` for every machine that already renders the touched scripts/templates. The pip fix changes behavior for anyone currently relying on the global `extra-index-url` working implicitly — `tasks.md` documents the new invocation pattern for the two known consumers (work Azure Artifacts, personal GitHub Packages) so nothing breaks silently. No rollback beyond reverting the commit and re-applying.

## Open Questions

- Does chezmoi v2.72.2's `type = "git-repo"` external support a per-entry ref-pinning field? Resolve during implementation of Decision 6's `git-repo` entries (`chezmoi --help` / current docs check) — if yes, use it directly; if no, convert those three entries to pinned `type = "archive"` tarball URLs. Either answer keeps the same requirement, approach, and task shape (pin executable externals to a ref), so it doesn't block writing `tasks.md` now.
