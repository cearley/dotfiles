## Why

Some Homebrew packages require environment variables to be set at install time — for example, Microsoft's `msodbcsql18` and `mssql-tools18` require `HOMEBREW_ACCEPT_EULA=Y`. The Brewfile format has no per-package env var syntax, so there's currently no way to declare these requirements in `packages.yaml`; they must be set manually before running `chezmoi apply`, which breaks the goal of fully automated, reproducible setup.

## What Changes

- **New optional `brew_env` key** at the category level in `packages.yaml` (alongside `brews`, `casks`, `taps`, etc.) — a string-to-string map of environment variable names to values.
- **Script update** to `run_onchange_before_darwin-23-install-packages.sh.tmpl`: before the `brew bundle` heredoc, collect `brew_env` maps from all active categories, merge them (last active category wins on key collision), and export the resulting vars into the script's environment.
- **Scope**: env vars apply to the entire `brew bundle` run (brews and casks alike), which is acceptable because install-time vars like `HOMEBREW_ACCEPT_EULA` are namespace-specific and ignored by packages that don't check for them.
- **No changes** to the `brews`, `casks`, or `taps` list formats — all entries remain plain strings per the existing spec requirement.
- **Initial use case**: declare `HOMEBREW_ACCEPT_EULA: "Y"` under `packages.darwin.work.brew_env` to automate Microsoft SQL tooling installation.

## Capabilities

### New Capabilities

- `brew-install-env-vars`: Category-level declaration of environment variables required for Homebrew package installation, with collection and export before `brew bundle` runs.

### Modified Capabilities

- `package-management`: New optional `brew_env` key added to the category-level schema. Existing string-only list requirements for `brews`, `casks`, and `taps` are unchanged.

## Impact

- **`home/.chezmoidata/packages.yaml`**: Add `brew_env` under `work` category (and any future categories that need it).
- **`home/.chezmoiscripts/run_onchange_before_darwin-23-install-packages.sh.tmpl`**: Add env var collection and export block before the `brew bundle` heredoc.
- **`openspec/specs/package-management/spec.md`**: Add new requirement section for `brew_env`.
- No impact on other scripts, machine configs, or secrets management.
- No breaking changes — `brew_env` is optional; categories without it behave identically to today.

## Non-goals

- Per-package env var scoping (env vars apply to the entire bundle run, not individual packages).
- Persisting env vars beyond the script's execution.
- Supporting env vars for non-Homebrew package managers (UV, Bun, SDKMAN, Cargo).
- Conflict detection when two active categories define the same env var key with different values.
