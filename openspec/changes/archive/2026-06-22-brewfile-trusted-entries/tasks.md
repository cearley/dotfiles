## 1. Update packages.yaml Schema

- [x] 1.1 Add `packages.darwin.trusted` list with all 11 entries from the design (after the top-level `taps:` block)
- [x] 1.2 Convert top-level `taps` entries from dict format back to plain strings (`isen-ng/dotnet-sdk-versions`, `buo/cask-upgrade`)
- [x] 1.3 Convert `dev.taps` entry `localstack/tap` from dict format back to plain string
- [x] 1.4 Convert `ai.brews` entry `itspriddle/brews/ical-guy` from dict format back to plain string
- [x] 1.5 Rename `ai.casks` entry `cmux` to `manaflow-ai/cmux/cmux`

## 2. Add New Packages to packages.yaml

- [x] 2.1 Add `microsoft/mssql-release` to `work.taps`; add `microsoft/mssql-release/msodbcsql18` and `microsoft/mssql-release/mssql-tools18` to `work.brews`
- [x] 2.2 Add `supabase/tap` to `ai.taps`; add `supabase/tap/supabase` to `ai.brews`
- [x] 2.3 Add `postrv/narsil` to `ai.taps`; add `postrv/narsil/narsil-mcp` to `ai.brews`
- [x] 2.4 Add `qltysh-archive/formulae` to `dev.taps`; add `qltysh-archive/formulae/codeclimate` to `dev.brews`

## 3. Update Brewfile Template

- [x] 3.1 In the top-level taps loop (Brewfile heredoc), append `{{ if has . $.packages.darwin.trusted }}, trusted: true{{ end }}` to the `tap` line
- [x] 3.2 In the category taps loop (Brewfile heredoc), append the same conditional to the `tap` line
- [x] 3.3 In the category brews loop (Brewfile heredoc), append the same conditional to the `brew` line
- [x] 3.4 In the category casks loop (Brewfile heredoc), append the same conditional to the `cask` line

## 4. Verify Template Output

- [x] 4.1 Run `chezmoi cat ~/.local/share/chezmoi/home/.chezmoiscripts/run_onchange_before_darwin-23-install-packages.sh.tmpl` (or `chezmoi execute-template`) and confirm `tap "isen-ng/dotnet-sdk-versions", trusted: true` appears in the heredoc
- [x] 4.2 Confirm `brew "itspriddle/brews/ical-guy", trusted: true` appears
- [x] 4.3 Confirm `cask "manaflow-ai/cmux/cmux", trusted: true` appears
- [x] 4.4 Confirm an untrusted entry (e.g. `brew "aria2"`) has no `, trusted: true` annotation
- [x] 4.5 Confirm pre-tap `brew tap` lines have no trust annotation

## 5. Apply and Validate

- [x] 5.1 Run `chezmoi apply` and confirm `brew bundle` runs without trust-related errors
- [x] 5.2 Run `brew doctor` and confirm no managed taps appear in the untrusted taps warning
