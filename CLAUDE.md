
# Chezmoi Dotfiles

Quick reference guide for AI assistants working with this chezmoi dotfiles repository.

## Quick Navigation

### Essential Files
- **OpenSpec specs**: `openspec/specs/` - Capability specifications and design
- **Code style examples**: "Code Style Quick Reference" note in the `chezmoi` basic-memory project - Extended cookbook

## Common Commands

```bash
audit-packages                 # List packages installed but not declared in packages.yaml (read-only)
audit-packages --strict        # Same, but exit non-zero if any orphans found (CI-friendly)
```

Standard chezmoi commands (`apply`, `diff`, `status`, `add`, `managed`, ...) and file-attribute prefixes (`private_`, `dot_`, `executable_`, `symlink_`, `.tmpl`) are covered by the `chezmoi-expert` skill — invoke it rather than duplicating that reference here.

## Practical Quick Reference

Script naming, shared utilities, template testing, and template-editing gotchas moved to `.claude/rules/home-scripts.md` (loads automatically when working under `home/`).

### Reusable Templates

Catalog and usage examples moved to `home/.chezmoitemplates/CLAUDE.md` (loads automatically when working in that directory).

## Key Principles

1. **No hardcoded secrets** - Two-tier model: KeePassXC for secrets used outside chezmoi-rendered files (default), SOPS+age-encrypted repo files only for secrets that exist solely to render chezmoi-managed files — see `openspec/specs/secret-management/` and `openspec/specs/sops-age-encryption/`
2. **Data files are static** - Files in `.chezmoidata/` cannot be templates
3. **Six-layer package management** (Homebrew, UV, Bun, SDKMAN, Cargo, Claude Skills via npx) - See `openspec/specs/package-management/`
4. **Consistent messaging** - Always use shared utilities for script output
5. **Platform wrapping** - Darwin scripts must use conditional templates
6. **Script ordering** - Machine-specific Brewfile (position 28) must always be last in the package management group (20-29)
7. **`trusted` list invariant** - `packages.yaml` has a `packages.darwin.trusted` list used by script 23 to emit `trusted: true` in the Brewfile for third-party taps and formulae. **Every third-party tap or formula added to any category must also appear in `trusted:`**, or it will install without the trust flag. The lists must be kept in sync manually — there is no automatic check.

### Platform Requirements
- **Target OS**: macOS 11.0+ (Big Sur or later)
- **Architectures**: ARM64 (Apple Silicon) primary, x64 (Intel) secondary
- **Bootstrap dependencies**: Xcode CLI Tools, KeePassXC (secrets), Homebrew (packages)

## Non-Interactive Limitations
- `chezmoi diff` fails without a TTY (KeePassXC requires interactive prompt); use `chezmoi status` or `chezmoi managed` instead
- `chezmoi apply --exclude=templates` also skips `.tmpl` scripts — don't use this flag when scripts need to run
- shellcheck false positives on `.tmpl` files are expected (Go template syntax misread as shell errors; safely ignored)

## Claude Code Automations

### Hooks (`.claude/settings.json`)
- **Template validation** (PostToolUse): Runs `chezmoi execute-template` on `.tmpl` files after edits
- **Data file protection** (PreToolUse): Blocks `{{ }}` expressions in `.chezmoidata/` files

### Skills
- `/new-script` - Generate a chezmoi script with correct naming, boilerplate, and conventions
- `/apply` - Safe diff-then-apply workflow with confirmation

### Agents
- `template-reviewer` - Scans all templates for convention violations (read-only)

### MCP Server Configuration
- **Global MCP servers**: `home/private_dot_config/claude-extend/tools.json.tmpl` (deployed to `~/.config/claude-extend/tools.json`)
- **Project MCP servers**: `.mcp.json` (if needed)
- GitHub MCP uses `gh auth token` for authentication — no PAT management needed

## When to Reference openspec/

- **Package management** → `openspec/specs/package-management/`
- **Machine config** → `openspec/specs/machine-config/`
- **Secret management** → `openspec/specs/secret-management/` (tiering) and `openspec/specs/sops-age-encryption/` (SOPS+age mechanism for repo-scoped secrets)
- **Major changes** → See archived proposals in `openspec/changes/archive/`

> `openspec archive <name> --yes` — note: positional arg, not `--change` (that flag errors)

## Session Completion

End-of-session checklist (quality gates, push, save session notes, handoff) moved to the `session-completion` skill.
