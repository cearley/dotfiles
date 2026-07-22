## Context

`packages.yaml` currently places `miniforge` under `dev.casks`, and `dot_zshrc.tmpl` initializes Conda inside the same `{{ if has "dev" .tags -}}` block that also sets up `awslocal`, `dotnet64`, cargo, and `frum`/`liquibase` env vars (`home/dot_zshrc.tmpl:148-181`). This means every `dev`-tagged machine installs and initializes a full Conda distribution whether or not it does data science work. Two scripts that run after Homebrew install (`run_onchange_after_darwin-35-install-nvm.sh.tmpl`, `run_onchange_after_darwin-46-setup-ssh-github.sh.tmpl`) call `python3` directly with no explicit `core` dependency providing it.

## Goals / Non-Goals

**Goals:**
- Install Conda (`miniforge`) and initialize its shell hook only on machines with the `datascience` tag.
- Guarantee a Homebrew-managed `python3` exists on every machine (`core`) before any tag-specific script runs, independent of whether Conda is installed.
- Preserve every other behavior currently gated by the `dev` tag block in `dot_zshrc.tmpl` (awslocal, dotnet64, cargo, frum, liquibase) unchanged.

**Non-Goals:**
- Not changing the `datascience` tag's existing package list beyond adding `miniforge` (csvkit, pandoc, pdfly, basictex, cursor, r-app, rstudio stay as-is).
- Not adding a new tag or prompt option — `datascience` already exists as a selectable tag in the bootstrap tag combinations.
- Not modifying `dot_p10k.zsh`'s `anaconda` prompt segment — it's runtime-conditional on `CONDA_PREFIX` and needs no tag-gating.
- Not touching `python3` usages inside the `run_onchange_after_darwin-35`/`-46` scripts themselves — only ensuring the binary is guaranteed present via `core`.

## Decisions

**1. Extract the conda-init block into its own `{{ if has "datascience" .tags -}}` conditional, rather than nesting it inside the existing `dev` block or wrapping with a combined `dev` + `datascience` check.**
Rationale: Conda's presence is fully determined by the `datascience` tag once `miniforge` moves there — coupling it to `dev` as well would require both tags selected simultaneously, which doesn't match how `datascience` is used standalone in some machine profiles. A dedicated conditional keeps the mapping 1:1 with the package that installs it (`miniforge` in `datascience.casks`), matching the existing pattern where the `ai` tag block (`dot_zshrc.tmpl:199-219`) and `dev` tag block are each self-contained.
Alternative considered: leave the block inside `dev` and add `(has "dev" .tags) and (has "datascience" .tags)` — rejected because it silently requires two tags for a feature the proposal frames as single-tag-gated, and doesn't fix the core problem (dev-only machines still wouldn't get conda even though they used to).

**2. Add `python3` to `core.brews` rather than to `dev.brews` or `datascience.brews`.**
Rationale: the two scripts that call `python3` directly (`-35-install-nvm`, `-46-setup-ssh-github`) are not gated by `dev` or `datascience` tags themselves — they run unconditionally in the numbered script sequence. `core` is the only tag guaranteed present on every machine, so it's the correct home for a dependency those scripts implicitly need.
Alternative considered: add `require_tools python3` guards to those two scripts instead of adding a `core` package — rejected as a non-fix; it would make the missing dependency loud (script failure) instead of actually resolving it, and doesn't match the proposal's intent of removing the implicit reliance on miniforge's bundled Python.

**3. Order of edits: add `python3` to `core` before removing `miniforge` from `dev`.**
Rationale: prevents a window where a `dev`-only, non-`datascience` machine has neither miniforge's Python nor an explicit `python3`, which would break the two scripts above on the very apply that performs the move. Since both edits land in the same commit/change, this is a logical/documentation ordering for `tasks.md`, not a multi-deploy sequencing concern.

## Risks / Trade-offs

- **[Risk] Existing `dev`-only (non-`datascience`) machines lose Conda on next `chezmoi apply`.** → Mitigation: this is the intended outcome per the proposal; anyone who actually uses Conda on such a machine needs to add the `datascience` tag to their machine's tag selection (existing chezmoi re-init/config mechanism, no new tooling needed).
- **[Risk] A user's shell profile or scripts outside this repo might reference the hardcoded `/opt/homebrew/Caskroom/miniforge/base/...` path directly (e.g., in a personal `.zshrc.local` or an editor's configured Python interpreter) and would break silently if `datascience` isn't selected.** → Mitigation: out of scope to detect from within the repo; call out in the PR description so the user (sole maintainer) can check machines before applying.
- **[Trade-off] Splitting the conda block out of the `dev` conditional adds one more independent `{{ if has ... }}` block to `dot_zshrc.tmpl`, slightly increasing template branching.** → Accepted: matches the existing precedent of the `ai` tag having its own dedicated block, and keeps each tag's shell contributions independently readable/removable.
