# Glossary

Terms that get reused across this repo's specs, scripts, and config in ways that
aren't obvious from the name alone. This file disambiguates; it doesn't replace
the canonical spec — follow the link for the full rules.

## persona
A named Claude Code profile: `~/.claude`, `~/.claude-personal`, `~/.claude-work`,
`~/.claude-bedrock`. Each has its own `CLAUDE_CONFIG_DIR`, `settings.json`, and
`.claude-settings.json` override. **Not** a macOS user account, and not a chezmoi
machine profile. Hooks and permission postures are allowed to diverge per persona
by design — that's not a bug to fix.
Canonical: `home/dot_claude/rules/claude-tooling.md.tmpl`

## trusted (packages.yaml)
The flat list at `packages.darwin.trusted` in `home/.chezmoidata/packages.yaml`.
Any tap, formula, or cask name in this list gets `, trusted: true` emitted in the
generated Brewfile. Membership is manual — adding a third-party tap/formula
elsewhere in `packages.yaml` does **not** automatically add it here.
Canonical: `openspec/specs/package-management/spec.md`

## script naming convention / execution order
Scripts in `home/.chezmoiscripts/` follow
`{frequency}_{timing}_{os}-{order}-{description}.sh.tmpl`:
- `frequency`: `run_once_` (runs once ever) or `run_onchange_` (reruns when the script's content hash changes)
- `timing`: `before` or `after` dotfile application
- `order`: a two-digit number, grouped in 10-point ranges (00-09 system foundation, 10-19 dev toolchains, 20-29 package management, 30-39 environment managers, 40-49 environment setup, 80-99 system configuration)
Canonical: `openspec/specs/script-execution/spec.md`

## two-tier secret model
"Tier" here means *which mechanism holds the secret*, not a priority or quality
ranking. KeePassXC is the default tier, for secrets used outside chezmoi-rendered
files. SOPS+age-encrypted repo files are the second tier, reserved for secrets
that exist solely to render chezmoi-managed files.
Canonical: `openspec/specs/secret-management/spec.md`, `openspec/specs/sops-age-encryption/spec.md`
