## Context

See proposal.md - Why. The current `package_layer_should_skip()` mechanism (`home/scripts/shared-utils.sh`) and its `$PPID`-keyed cache file are consulted by 12 scripts across six layers. `run_onchange_before_darwin-23-install-packages.sh.tmpl` currently generates one `brew bundle` heredoc containing taps, brews, casks, and mas together, gated by that shared decision for the `homebrew` layer. `run_onchange_before_darwin-28-brew-bundle-install.sh.tmpl` (machine-specific Brewfile) already has its own separate, uncached `read -p "Install additional packages from your brewfile? (y/N)"` prompt further down the script — confirmed via `git show 61139b3` to predate the layered mechanism and to have been left untouched when that mechanism was added on top of it.

## Goals / Non-Goals

**Goals:**
- Only Homebrew casks and `mas` installs are ever gated by a prompt; every other package layer (SDKMAN, uv, Bun, Cargo, Claude skills/MCP/plugins) always runs.
- The cask/mas prompt has no memory between runs — no cache file, no env var, asked fresh every `chezmoi apply`.
- Homebrew taps and formulae install unconditionally, never blocked on a cask or mas answer.
- Every confirmation prompt across both Homebrew scripts (script 23's independent cask and mas prompts, plus script 28's single combined Brewfile prompt) uses the same mechanics: plain `read -p`, no TTY guard.

**Non-Goals:**
- No per-package skip granularity (still per-bundle: "all pending casks/mas" as one yes/no, not one question per app).
- No change to what `run_onchange` triggers on (content hash / 7-day bucket).
- No change to tag-selection behavior or `.chezmoi.toml.tmpl` prompts.
- No change to the `warn_icloud_not_signed_in` / `HOMEBREW_BUNDLE_MAS_SKIP` iCloud gating for `mas` entries.

## Decisions

### Bundle split in script 23, not a per-item skip
Script 23's single `brew bundle` heredoc becomes three: an unconditional one for taps+brews, and two independently-confirmed ones — one for casks, one for mas (see "Casks and mas get independent confirmation prompts" below for why those two are split from each other, not just from taps+brews). Alternative considered: keep one bundle call and just gate the whole thing on "does this bundle contain any cask/mas entries" — rejected because it would re-run/re-check every formula on every "yes" answer and couldn't let formulae install for free when the user declines casks/mas, which defeats the goal of never blocking fast installs on a slow-install answer.

### Cask and mas bundles omit tap declarations
Neither the cask (`CASK_EOF`) nor the mas (`MAS_EOF`) heredoc re-declares `tap` lines, unlike the taps+brews bundle. This is safe because the script's existing imperative pre-tap loop (`brew tap` via the CLI, not through a Brewfile) already registers every tap — global and per-category — before any of the three bundles run; by the time either the cask or mas bundle executes, all taps it could reference are already present on the system. Homebrew's `tap` directive is idempotent, so duplicating tap lines into every bundle would have been harmless but unnecessary; omitting them keeps each bundle scoped to exactly the package type it's named for.

### No TTY guard on the cask/mas prompt — mirror script 28 exactly
Considered adding a `[ -t 0 ]` guard so unattended/CI applies would default to installing (matching the old layered mechanism's non-interactive-safe default). Rejected per explicit user direction: consistency with script 28's existing, already-shipped behavior (no TTY → `read` returns empty → treated as decline → skip) matters more here than preserving the old safety net. This is a deliberate, accepted behavior change: unattended/non-interactive applies (CI bootstrap tests, cron, `remote_install.sh` if piped instead of run via command substitution) will no longer install casks/mas without a human answering the prompt.

### Drop `CHEZMOI_SKIP_PACKAGE_UPDATES` entirely, no replacement
With only one prompt left, an env-var bypass duplicates what answering "n" already does. Considered keeping it for fully unattended contexts that want to explicitly force-skip — rejected because the no-TTY default already skips in exactly those contexts; the only scenario an env var would add is "interactively skip without being asked," which isn't a stated need.

### Casks and mas get independent confirmation prompts in script 23, not one combined prompt
After initial implementation, real-world testing showed a single "install cask and Mac App Store packages?" prompt forces an all-or-nothing choice, but casks and `mas` are different enough in practice (GUI apps vs. App Store, and `mas` also depends on iCloud sign-in) that a user may want one without the other. Changed script 23 to run three independent `brew bundle` invocations — taps+brews (unconditional), casks (own prompt), mas (own prompt) — instead of two. Script 28 (machine-specific Brewfile) is intentionally left with its single combined prompt: its Brewfile is an opaque file, not structured per-category data from `packages.yaml`, so splitting it would require parsing raw Brewfile syntax to separate cask/mas lines — a materially different and higher-risk change than script 23's, which already had casks/mas as distinct, independently-resolved template values. Not undertaken here; revisit only if the same complaint arises for script 28 specifically.

### `package-update-skip` capability retired to empty, not deleted outright
All five of its requirements are marked REMOVED via delta rather than deleting the capability directory outright. This keeps the removal auditable through the normal spec-delta/archive flow rather than silently dropping a spec file. Whether the resulting empty capability directory is deleted or left as a placeholder is an archive-time housekeeping decision, not a spec-behavior one.

## Risks / Trade-offs

- **[Risk] Unattended applies silently stop installing casks/mas** → Accepted trade-off per explicit user decision; mitigated by the fact that this matches script 28's pre-existing behavior, so it's a consistency fix rather than a wholly new failure mode. Anyone relying on non-interactive cask/mas installs (e.g. a CI bootstrap test asserting a cask got installed) needs to switch to asserting on formulae only, or feed a `y` to stdin.
- **[Risk] Three `brew bundle` invocations in script 23 (vs. the original single call) means three chances for partial failure** → `brew update` still runs only once, before all three bundles — it's not repeated per-bundle, so there's no added network/update cost from the split itself. The existing partial-failure handling (`Homebrew Bundle Partial Failure Resilience` requirement) applies independently to each of the three bundles' exit codes, so one bundle failing doesn't affect the others' warnings or outcomes.
- **[Risk] Removing five layers' skip guards means those scripts always re-run their full install/upgrade logic on every triggering apply** → This is the explicit goal (they were never expensive enough to justify gating), not a regression.

## Migration Plan

1. Remove `package_layer_should_skip()`, `_package_update_skip_load_or_prompt()`, `_package_update_skip_resolve_and_cache()` from `home/scripts/shared-utils.sh`.
2. Remove the `package_layer_should_skip` guard block from the 10 non-Homebrew scripts (20, 21, 24, 25, 26, 27, 37, 38, 39, 44) — no replacement logic needed, they just lose the early-exit check.
3. Remove the `package_layer_should_skip "homebrew"` guard block from script 28 — its existing `read -p` prompt is untouched and needs no changes.
4. Split script 23's `brew bundle` heredoc into three: taps+brews (unconditional), casks (gated by its own `read -p` confirmation), and mas (gated by an independent `read -p` confirmation) — each of the latter two skipped entirely when that bundle would be empty.
5. Update `openspec/specs/package-update-skip/spec.md` and `openspec/specs/package-management/spec.md` via `openspec sync` (or manual archive) once implementation lands.
6. No data migration, no user-facing config change beyond behavior — nothing to backfill or rollback beyond reverting the commit.

Rollback: revert the implementing commit(s); the removed cache file path and env var were never load-bearing for anything outside this mechanism, so no cleanup is required on rollback.
