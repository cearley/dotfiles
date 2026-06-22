## Why

Homebrew now requires explicit trust declarations for third-party taps and their formulae/casks in Brewfiles. Without this, `brew bundle` silently skips packages from untrusted taps, and `brew doctor` reports trust warnings. The current `packages.yaml` partially addressed this with ad-hoc dict-format entries (`{name: ..., trusted: true}`) for individual taps and brews, but the approach is inconsistent, doesn't cover casks, and makes the YAML harder to read.

## What Changes

- Add a `packages.darwin.trusted` list — a global set of tap/formula/cask names that receive `, trusted: true` in the generated Brewfile
- Remove all existing dict-format entries from `taps`, `brews`, and `casks` lists; convert back to plain strings
- Update the Brewfile heredoc template to append `, trusted: true` when an entry's name appears in the trusted set
- Add 4 previously-unmanaged taps and their formulae to the appropriate tag categories:
  - `microsoft/mssql-release` → `work` (formulae: `msodbcsql18`, `mssql-tools18`)
  - `supabase/tap` → `ai` (formula: `supabase/tap/supabase`)
  - `postrv/narsil` → `ai` (formula: `postrv/narsil/narsil-mcp`)
  - `qltysh-archive/formulae` → `dev` (formula: `qltysh-archive/formulae/codeclimate`)
- Update `cmux` cask entry from short name to fully-qualified `manaflow-ai/cmux/cmux`

## Capabilities

### New Capabilities

_(none — this is a behaviour change within the existing Homebrew package management capability)_

### Modified Capabilities

- `package-management`: New requirement for Homebrew tap trust declarations. The `packages.yaml` schema gains a `darwin.trusted` key. The Brewfile template gains conditional trust annotation. Entries requiring formula-level trust must use fully-qualified names in their respective lists.

## Impact

- **`home/.chezmoidata/packages.yaml`**: Schema change (new `darwin.trusted` key); entry format simplification (remove dicts, restore plain strings; fully-qualify selected formula names)
- **`home/.chezmoiscripts/run_onchange_before_darwin-23-install-packages.sh.tmpl`**: Four lines in the Brewfile heredoc gain an inline `{{ if has . $.packages.darwin.trusted }}, trusted: true{{ end }}` conditional
- **Tags affected**: `core` (oven-sh/bun), `dev` (localstack, codeclimate), `ai` (itspriddle, manaflow-ai, postrv/narsil, supabase), `work` (microsoft/mssql-release)
- **Pre-tap bash section**: No changes needed — `brew tap` CLI has no trust flag; trust is Brewfile-only
- **No secrets, no permissions, no SIP implications**

## Non-Goals

- Trusting taps installed outside chezmoi (`postrv/narsil`, `qltysh-archive/formulae`, `supabase/tap`, `microsoft/mssql-release` are being brought under management as part of this change, but any other orphan taps are out of scope)
- Automating `brew trust` CLI commands — the Brewfile approach is sufficient
- Per-category trusted lists or per-entry inline trust flags — the global set with plain-string entries is the chosen design
