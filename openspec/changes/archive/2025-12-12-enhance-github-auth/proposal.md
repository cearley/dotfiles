# Change: GitHub Authentication Enhancement

## Why
Developers using GitHub need enhanced authentication capabilities to support package managers and, optionally, multiple GitHub accounts. The current implementation provides basic git, GHCR, and GitHub CLI authentication but lacks package manager support and flexible multi-account options.

**Current gaps:**
- No package manager authentication (GitHub Packages for npm, NuGet, Maven, pip)
- No environment variable exports for CLI tools requiring `GITHUB_TOKEN`
- No optional multi-account support for users with separate work/personal GitHub accounts
- No tag-based gating (runs on all machines with KeePassXC)

**This change supports two usage scenarios:**

**Scenario A: Single Account, Multiple Commit Identities (Current/Common)**
- One GitHub account with one set of credentials
- Same credentials used everywhere (git, packages, CLI)
- Different commit email addresses based on directory (personal vs. work email)
- **Current behavior preserved** - only adds package manager support

**Scenario B: Multiple Accounts (Optional/Advanced)**
- Separate GitHub accounts (e.g., personal github.com + enterprise GitHub)
- Different credentials per account
- Directory-based credential routing (different PATs for ~/work/ vs ~/personal/github/)
- Requires explicit opt-in via enterprise configuration

This change enhances the existing authentication system to support package managers (benefits Scenario A users immediately) while enabling true multi-account support for users who need it (Scenario B).

## What Changes

### Core Enhancement (Benefits Both Scenarios)
- **Primary authentication script**: `run_onchange_after_darwin-45-setup-github-auth.sh.tmpl`
  - Enhanced from existing script (maintains backward compatibility)
  - Optional `dev` tag gating (falls back to KeePassXC check if no tags)
  - **NEW**: Package manager authentication (npm, NuGet, Maven, pip)
  - **NEW**: `GITHUB_TOKEN` environment variable export
  - Existing features preserved: git, GHCR, GitHub CLI
  - KeePassXC entry: "GitHub" (existing)
  - **Works for Scenario A**: Single account + packages

### Optional Multi-Account Support (Scenario B Only)
- **Enterprise account script** (NEW): `run_onchange_after_darwin-45a-setup-github-auth-enterprise.sh.tmpl`
  - Only created/runs if enterprise GitHub is configured
  - Gated by `work` tag + enterprise domain configuration
  - Full feature support: git, GHCR, GitHub CLI, all package managers
  - KeePassXC entry: "GitHub (Enterprise)" or "GitHub (Work)"
  - **Only needed for Scenario B**: Separate enterprise GitHub account

### Git Configuration
- **Scenario A**: Current behavior preserved
  - Same credentials globally
  - `includeIf "gitdir:~/work/"` changes commit email only (existing)
  - Single KeePassXC entry

- **Scenario B**: Multi-account credential routing (optional)
  - Directory-based credential configuration using `includeIf`
  - Primary account as global default
  - Enterprise account overrides for `~/work/` directory
  - Support for github.com and GitHub Enterprise custom domains

### Package Manager Authentication
- npm (.npmrc) for GitHub Packages
- NuGet (NuGet.Config) for GitHub Packages
- Maven (settings.xml) for GitHub Packages
- Python pip (pip.conf) for GitHub Packages
- All optional (staged adoption supported)

### Environment Variable Exports
- **Scenario A**: `GITHUB_TOKEN` exported from single account
- **Scenario B**:
  - `GITHUB_TOKEN` exported for primary account
  - `GITHUB_TOKEN_ENTERPRISE` exported for enterprise account (if configured)
- Available to CLI tools, scripts, and automation

### Configuration
- **Scenario A**: Minimal configuration changes
  - Optional package manager variables in `.chezmoi.toml.tmpl`
  - Existing "GitHub" KeePassXC entry reused
  - No directory-based credential routing needed

- **Scenario B**: Additional multi-account configuration
  - Enterprise GitHub domain and username in `.chezmoi.toml.tmpl`
  - Separate KeePassXC entry for enterprise account
  - Directory-based git credential routing
  - Independent PAT rotation per account

- Documentation in Serena memory system covers both scenarios

### Gating
- **Primary account (darwin-45)**: Optional `dev` tag (falls back to KeePassXC check for backward compatibility)
- **Enterprise account (darwin-45a)**: Requires `work` tag + enterprise domain configuration
- macOS only (following existing pattern)

## Impact
- **Affected specs**: `secret-management` (added GitHub authentication enhancements for both single and multi-account scenarios)
- **Affected code**:
  - **Core enhancements (both scenarios)**:
    - `home/.chezmoiscripts/run_onchange_after_darwin-45-setup-github-auth.sh.tmpl` (modify - add package managers, optional tag gating)
    - `home/private_dot_npmrc.tmpl` (create - add GitHub Packages)
    - `home/private_dot_nuget/NuGet/private_NuGet.Config.tmpl` (modify or create - add GitHub Packages)
    - `home/private_dot_m2/private_settings.xml.tmpl` (modify or create - add GitHub Packages)
    - `home/private_dot_config/private_pip/private_pip.conf.tmpl` (modify or create - add GitHub Packages)
    - `home/private_dot_zsh_secrets.tmpl` (modify - add GITHUB_TOKEN)
  - **Multi-account only (Scenario B)**:
    - `home/.chezmoiscripts/run_onchange_after_darwin-45a-setup-github-auth-enterprise.sh.tmpl` (create - optional)
    - `home/dot_gitconfig.tmpl` (modify - add enterprise credential routing if configured)
    - `home/dot_gitconfig-github-enterprise.tmpl` (create - enterprise account overrides, optional)
    - `home/private_dot_zsh_secrets.tmpl` (modify - add GITHUB_TOKEN_ENTERPRISE if enterprise configured)
  - **Configuration**:
    - `home/.chezmoi.toml.tmpl` (modify - add optional package manager and enterprise GitHub variables)
  - **Documentation**:
    - `.serena/memories/github-authentication.md` (create - cover both scenarios)
    - `.serena/memories/chezmoi-dotfiles-quick-reference.md` (modify)
- **Dependencies**: GitHub CLI (already in packages.yaml), docker, git, package managers (optional)
- **Breaking changes**: None (purely additive, existing setup continues to work as Scenario A with new package manager support)