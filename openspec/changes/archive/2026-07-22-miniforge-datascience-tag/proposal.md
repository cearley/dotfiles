## Why

`miniforge` (and its `conda init` shell block) currently lives under the `dev` tag, so every `dev`-tagged machine gets a full Conda distribution installed and initialized even though Conda is only actually used for data science work. Meanwhile, two `dev`-tag scripts (`run_onchange_after_darwin-35-install-nvm.sh.tmpl` and `run_onchange_after_darwin-46-setup-ssh-github.sh.tmpl`) call `python3` directly with no guaranteed Homebrew-installed `python3` in `core` — they've been relying on an implicit system/Xcode-CLI-tools stub or on `miniforge`'s bundled Python happening to be on `PATH`. Moving `miniforge` to `datascience` (where it belongs) would break that implicit dependency for `dev`-only machines, so `python3` needs to become an explicit `core` package first.

## What Changes

- Move `miniforge` from `packages.darwin.dev.casks` to `packages.darwin.datascience.casks` in `home/.chezmoidata/packages.yaml`.
- Add `python3` to `packages.darwin.core.brews` in `home/.chezmoidata/packages.yaml`, guaranteeing a Homebrew-managed `python3` is installed before any tag-specific scripts run (fixes the implicit dependency in the nvm-version-lookup and SSH-key-parsing scripts).
- In `home/dot_zshrc.tmpl`, extract the `# >>> conda initialize >>>` / `# <<< conda initialize <<<` block (lines 156–169) out of the surrounding `{{ if has "dev" .tags -}}` block and wrap it in its own `{{ if has "datascience" .tags -}}` conditional, so Conda is only initialized on machines with the `datascience` tag. The rest of that `dev`-tag block (awslocal alias, dotnet64 alias, cargo env, frum init, liquibase env) is unaffected and stays under `dev`.

## Capabilities

### New Capabilities
(none)

### Modified Capabilities
- `package-management`: adds a new "Conda Shell Integration" requirement documenting that Conda initialization in shell profiles is gated on the `datascience` tag — the same documented pattern the spec already uses for SDKMAN's tag-conditional shell integration (see "Requirement: SDKMAN Shell Integration"). This closes a gap where Conda's shell init was previously undocumented and incorrectly coupled to the `dev` tag.

## Impact

- **Affected files**: `home/.chezmoidata/packages.yaml`, `home/dot_zshrc.tmpl`
- **Affected tags**: `dev` (loses miniforge + unconditional conda init), `core` (gains python3), `datascience` (gains miniforge + conda init)
- **Affected scripts (indirect)**: `run_onchange_after_darwin-35-install-nvm.sh.tmpl` and `run_onchange_after_darwin-46-setup-ssh-github.sh.tmpl` both invoke `python3` and run after `run_onchange_before_darwin-28-brew-bundle-install.sh.tmpl`, so making `python3` a `core` brew closes the gap left by removing miniforge from `dev`
- **Not affected**: `home/dot_p10k.zsh`'s `anaconda` prompt segment — it only activates when `CONDA_PREFIX` is set at runtime, so it requires no tag-gating and works correctly regardless of which tag installed Conda
- **Machine impact**: any machine currently running with `dev` but without `datascience` will stop getting Conda on next `chezmoi apply` (expected — this is the point of the move); machines with `personal` tag combo (`core,dev,ai,personal,datascience` per existing convention) are unaffected since they already carry `datascience`
- **No breaking changes to package-management requirements**: tag semantics, Brewfile generation, and trust declarations are untouched
