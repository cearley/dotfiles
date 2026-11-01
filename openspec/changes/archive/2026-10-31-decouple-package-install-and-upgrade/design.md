# Design

## Context

See `proposal.md` - Why. Two scripts are in scope: `run_onchange_before_darwin-23-install-packages.sh.tmpl` (taps, formulae, casks, mas from `packages.yaml`, via the `package-layer-items` template partial) and `run_onchange_before_darwin-28-brew-bundle-install.sh.tmpl` (a single machine-specific Brewfile). Both currently call bare `brew bundle` (= `brew bundle install`, which installs missing dependencies and upgrades outdated ones together by default). darwin-23's cask and mas sections currently gate installation on a `read -p` prompt shown whenever the category has any declared items; darwin-28 already does a `brew bundle check` → prompt → `brew bundle` sequence, but that single check/prompt still covers install+upgrade as one undifferentiated decision.

`brew bundle install --help` and `brew bundle check --help` confirm the flags this design relies on:
- `brew bundle install --no-upgrade` installs missing dependencies only; never upgrades an already-installed one. (`--no-upgrade`: "Do not run brew upgrade on outdated dependencies.")
- `brew bundle install --upgrade` installs missing *and* upgrades outdated, unconditionally.
- `brew bundle check` (default) exits 0 only if everything declared is both installed and current; exits non-zero if anything is missing or outdated. `--verbose` lists what's unmet.
- `brew bundle check --no-upgrade` would check installed-only (ignoring staleness) — not used here, since after step 1 (no-upgrade install) nothing is missing, so a subsequent default `check` failing can only mean staleness.

## Goals / Non-Goals

**Goals:**
- Installing a package newly added to `packages.yaml` (or a machine Brewfile) happens immediately and silently on the next `chezmoi apply`, for every package type, with no prompt.
- Upgrading an already-installed-but-outdated package is a separate, explicit, opt-in decision, asked once per script per run, only when there's actually something outdated.
- No new caching, state files, or shared-utils helpers — matches the "ask fresh every run" principle already established by the 2026-08-12 predecessor change.

**Non-Goals:**
- Per-package (as opposed to per-script) install/upgrade control.
- Changing what triggers `run_onchange` (content hash / 7-day time-bucket) — only what the script does once triggered.
- Merging darwin-23's and darwin-28's prompts into one — they stay structurally separate scripts with separate prompts.

## Decisions

**Split every `brew bundle` call into an unconditional `--no-upgrade` install followed by a conditional `check`-gated `--upgrade` call, rather than keeping one call and trying to detect "is this upgrade-only" some other way.** This is the only approach that uses `brew bundle`'s own documented flags instead of re-implementing dependency-state diffing. Alternative considered: keep a single `brew bundle` call and precede it with a `brew bundle check --no-upgrade` (missing-only) probe just to decide the *prompt text* while still letting the single call upgrade silently — rejected, because it would still silently upgrade everything whenever a prompt wasn't needed for installing, which is exactly the surprise behavior this change removes.

**Use `brew bundle check` (default flags) as the sole gate for the upgrade prompt, in both scripts.** It directly answers "is there anything outdated" after the no-upgrade install has already resolved "is there anything missing" — no separate missing/outdated bookkeeping needed. Alternative considered: reintroduce a cache of the last-seen outdated set — rejected per the 2026-08-12 precedent's explicit rationale (the old `$PPID`-keyed cache was the bug being fixed; `brew bundle check` is cheap enough to just re-run every time).

**darwin-23 keeps three separate missing-item install invocations (taps+brews, casks, mas) but combines the post-install check and upgrade into one call each.** The three-way split exists today because each category has different render-time skip conditions (casks: non-empty for tag set; mas: non-empty and iCloud signed in) and different Brewfile content; collapsing them into one install call would require always rendering all three types together even when one is empty, complicating the skip-silently behavior. The check/upgrade step, by contrast, naturally wants to see the full declared set at once (that's what "do I need to bug the user with an upgrade prompt" should be evaluated against), so one combined invocation there is simpler than three separate checks that would need their own combined prompt logic anyway.

**darwin-28 gets the identical two-step split (no-upgrade install, then check-gated upgrade) but keeps it as a single invocation pair, matching its existing single-Brewfile structure.** No category split needed there since the machine Brewfile isn't parsed by package type.

**No `--verbose` capture/reuse between the check and the prompt text beyond printing it directly.** `brew bundle check --verbose` output is already human-readable; piping it straight to the terminal before the `read -p` is simpler than parsing it to build a custom message, and matches the existing style (scripts already lean on Homebrew's own output rather than building their own summaries).

## Risks / Trade-offs

- **[Risk] `brew bundle check` re-walks the entire declared set (including `mas` entries, which shell out per-app) on every triggering run, even when nothing changed.** → Mitigation: this is strictly cheaper than what happens today (today's cask/mas prompts already fire unconditionally when the category is non-empty, and accepting either prompt runs a full `brew bundle` that does its own equivalent check internally before deciding what to install/upgrade). Net check cost is unchanged or lower; only the prompt *frequency* changes, and only to remove unnecessary prompts.
- **[Risk] A declared package that's missing AND whose presence would itself make another check pass differently (unlikely with Homebrew, but theoretically a tap needed only for a cask version bump) could in principle need two passes.** → Mitigation: not a regression — today's single `brew bundle` call has the same transitive-dependency assumption; Homebrew's own dependency resolution already handles taps-before-casks via the existing pre-tap loop, which this change does not touch.
- **[Trade-off] Splitting one `brew bundle` call into two (no-upgrade install, then conditional upgrade) roughly doubles the number of Homebrew bundle invocations per script when something is actually outdated.** → Accepted: the cost is one extra `brew bundle check` (cheap, no installs) in the common case (nothing outdated), and one extra full bundle pass only in the case where the user explicitly opts into upgrading — which is exactly the behavior being asked for.

## Migration Plan

No data migration. This only changes script logic in two `.tmpl` files; no state file, cache, or `packages.yaml` schema change. Rollout is simply: merge the change, and the new logic takes effect the next time either script's `run_onchange` trigger fires (next `packages.yaml` edit or the next 7-day time-bucket rollover) on each machine that applies this dotfiles repo. Rollback is a plain revert of the two script files — there is no persisted state to clean up, since the old cache mechanism was already removed by the 2026-08-12 predecessor change and this change does not reintroduce one.
