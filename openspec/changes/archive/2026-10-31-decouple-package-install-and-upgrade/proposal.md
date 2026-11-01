# Proposal

## Why

`brew bundle` (the bare subcommand both Homebrew install scripts call, equivalent to `brew bundle install`) installs missing dependencies *and* upgrades outdated ones in a single unconditional call, by design (`brew bundle install --help`: "Install and upgrade (by default) all dependencies from the Brewfile"). `run_onchange_before_darwin-23-install-packages.sh.tmpl`'s cask and mas sections additionally show a confirmation prompt gated only on "does `packages.yaml` declare any items in this category for the active tag set" — not on whether anything is actually missing or outdated. The combination means: adding one new formula or cask to `packages.yaml` and running `chezmoi apply` to get it installed right away silently drags in upgrades of every other already-installed package in that bundle, and the cask/mas prompts fire on every triggering run (including the unrelated 7-day periodic re-run) even when nothing needs to change.

This is a direct evolution of `2026-08-12-simplify-package-update-skip`, which replaced a buggy `$PPID`-keyed upgrade-skip cache with fresh, per-run cask/mas prompts gated on category contents. That fixed the staleness bug but left the gating condition wrong (category non-empty, not work-pending) and left "install" and "upgrade" bundled as one undifferentiated decision. This change keeps that predecessor's "ask fresh every run, no caching" principle but re-grounds the gate in `brew bundle check` and splits the single install+upgrade decision into two: installing anything missing is unconditional and silent in every category (so `chezmoi apply` always delivers a newly-declared package immediately), and upgrading anything already-installed-but-outdated becomes its own single, combined, opt-in prompt.

## What Changes

- **BREAKING**: Remove the cask and mas "any items declared? (y/N)" install prompts from `run_onchange_before_darwin-23-install-packages.sh.tmpl` entirely. Missing casks and mas items now install unconditionally and silently, like taps/formulae already do.
- Change every `brew bundle` install call in `run_onchange_before_darwin-23-install-packages.sh.tmpl` (taps+formulae, casks, mas) to `brew bundle install --no-upgrade`, so these calls only ever install what's missing and never touch already-installed packages.
- Add one combined `brew bundle check --verbose` (default upgrade-checking enabled) across the full declared set (taps+brews+casks+mas) after the missing-item installs complete. A failure here can only mean something is outdated, since missing items were already installed.
- Add one new combined prompt, shown only when that check fails: "N packages have updates available — install them now? (y/N)". On yes, run one `brew bundle install --upgrade` across the full combined set. On no or non-TTY, skip and exit 0.
- Apply the identical split to `run_onchange_before_darwin-28-brew-bundle-install.sh.tmpl` (machine-specific Brewfile): install missing items silently via `--no-upgrade` first, then gate a single upgrade prompt on `brew bundle check`. This script keeps its own separate prompt — it is a structurally separate script and trigger from darwin-23, and this change does not merge the two.
- No changes to: the pre-tap loop (still runs before any bundle invocation in darwin-23), `$icloudSignedIn`/`warn_icloud_not_signed_in` mas gating, per-bundle partial-failure handling (`any_failed`, scoped warnings, non-zero exit propagation), `brew_env` export behavior, `trusted:` annotation rendering, or the `package-layer-items` template partial. These are unchanged inputs to the new bundle invocations.

## Capabilities

### New Capabilities
(none)

### Modified Capabilities
- `package-management`: "User Confirmation for Additional Packages" is rewritten from per-category install gating (cask prompt, independent mas prompt, non-empty-category trigger) to a single combined upgrade-only prompt per script, gated by `brew bundle check` rather than category contents. "Homebrew Core Bundle Split" is rewritten from three independent bundle invocations (one unconditional, two gated-by-install-prompt) to the new five-step sequence (three unconditional no-upgrade installs, one combined check, one conditional combined upgrade). "Idempotent Package Installation"'s "Package updates" scenario is tightened to describe upgrade as an explicit, confirmed, separate step rather than an implicit side effect of installing missing packages.

## Impact

- **Affected scripts**: `run_onchange_before_darwin-23-install-packages.sh.tmpl`, `run_onchange_before_darwin-28-brew-bundle-install.sh.tmpl`. No other script in the 20-29 (package management) range is touched — SDKMAN, uv, tools, Bun, Cargo installers are already unconditional per the 2026-08-12 change and are out of scope here.
- **Modified utility**: none. `home/scripts/shared-utils.sh` gains no new helper — the new upgrade prompt is a plain inline `read -p`, matching the existing style and the 2026-08-12 precedent's deliberate choice not to centralize this in shared-utils.
- **Tags**: not tag-specific. Every tag profile (core, dev, ai, work, personal, datascience, mobile) goes through darwin-23's Homebrew bundle and is affected by the install/upgrade split; machines with a configured machine-specific Brewfile (darwin-28) are additionally affected there.
- **Security implications**: none. No secrets or credentials are involved; this only changes whether/when install vs. upgrade commands run and what triggers the remaining prompt, not what gets installed, how trust annotations are rendered, or how `brew_env` is exported. The existing iCloud/`HOMEBREW_BUNDLE_MAS_SKIP` gating for mas is unaffected.
- **Non-goals**: this does not add per-package install or upgrade control (still per-bundle, not per-item); does not change what `run_onchange` triggers on (content hash / 7-day time-bucket triggers are untouched — only what happens once a script is triggered changes); does not touch tag-selection prompts in `.chezmoi.toml.tmpl`; does not add any caching of upgrade decisions across runs (the "ask fresh every run" principle from the predecessor change is preserved, just re-scoped to upgrades only).
