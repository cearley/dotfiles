# Implementation Tasks

**Archived**: 2025-12-12

**Status**: Phase 1 (Scenario A) COMPLETED ✅ | Phase 2 (Scenario B) NOT IMPLEMENTED

**What was implemented:**
- Single GitHub account with automated package manager authentication (npm, NuGet, Maven, pip)
- GITHUB_TOKEN environment variable export for CLI tools
- Backward compatible with existing single-account setups
- All package managers are optional and configurable

**What was NOT implemented:**
- Multi-account support (Scenario B - enterprise GitHub authentication)
- Future work if multi-account support is needed

---

## Phase 1: Core Enhancements (Scenario A - Benefits All Users)

### 1. Configuration Updates
- [x] 1.1 Update `home/.chezmoi.toml.tmpl` to add package manager variables
  - [x] Add `gh_packages_owner` variable (default: empty, optional)
  - [x] Add `gh_npm_registry` variable (default: empty, optional)
  - [x] Add `gh_nuget_source` variable (default: empty, optional)
  - [x] Add `gh_maven_repository` variable (default: empty, optional)
  - [x] Add `gh_pip_index` variable (default: empty, optional)
- [x] 1.2 Ensure backward compatibility for existing installations without tags

### 2. Primary Account Enhancement (darwin-45)
- [x] 2.1 Add tag gating to `run_onchange_after_darwin-45-setup-github-auth.sh.tmpl`
  - [x] Check for `dev` tag OR KeePassXC availability (backward compatible)
  - [x] Update script header comments to reflect tag requirement
- [x] 2.2 Add package manager authentication functions
  - [x] Add `setup_npm_github()` function for GitHub Packages (npm)
  - [x] Add `setup_nuget_github()` function for GitHub Packages (NuGet)
  - [x] Add `setup_maven_github()` function for GitHub Packages (Maven)
  - [x] Add `setup_pip_github()` function for GitHub Packages (pip)
  - [x] Each function should check if package owner/repo is configured before proceeding
- [x] 2.3 Update main() function to call package manager setup functions
- [x] 2.4 Add success messages for each configured package manager

### 3. Package Manager Configuration Files (Scenario A)
- [x] 3.1 Create or update `home/private_dot_npmrc.tmpl`
  - [x] Add GitHub Packages registry configuration
  - [x] Use existing GitHub credentials
  - [x] Make registry configuration optional (check for package owner variable)
- [x] 3.2 Create or update `home/dot_nuget/NuGet/private_NuGet.Config.tmpl`
  - [x] Add GitHub Packages source
  - [x] Use existing GitHub credentials
  - [x] Make source configuration optional
- [x] 3.3 Create or update `home/private_dot_m2/private_settings.xml.tmpl`
  - [x] Add GitHub Packages repository
  - [x] Use existing GitHub credentials
  - [x] Make repository configuration optional
- [x] 3.4 Create or update `home/private_dot_config/private_pip/private_pip.conf.tmpl`
  - [x] Add GitHub Packages index
  - [x] Use existing GitHub credentials
  - [x] Make index configuration optional

### 4. Environment Variable Exports (Scenario A)
- [x] 4.1 Update `home/dot_zsh_secrets.tmpl`
  - [x] Add `GITHUB_TOKEN` export (gated by KeePassXC availability)
  - [x] Use existing "GitHub" KeePassXC entry

### 5. Testing Scenario A (Single Account + Packages)
- [x] 5.1 Test existing single-account setup
  - [x] Verify existing git authentication still works
  - [x] Verify existing GHCR authentication still works
  - [x] Verify existing gh CLI authentication still works
  - [x] Verify GITHUB_TOKEN environment variable is set
- [x] 5.2 Test package manager authentication
  - [x] Verify npm GitHub Packages works (if configured)
  - [x] Verify NuGet GitHub Packages works (if configured)
  - [ ] Verify Maven GitHub Packages works (if configured) - Not tested (not configured)
  - [ ] Verify pip GitHub Packages works (if configured) - Not tested (not configured)
- [x] 5.3 Test backward compatibility
  - [x] Verify works without tags (KeePassXC fallback)
  - [x] Verify works with existing configuration
  - [x] Verify skips packages when not configured
- [x] 5.4 Test commit email routing (existing behavior)
  - [x] Verify `~/work/` uses work email (existing includeIf)
  - [x] Verify outside `~/work/` uses personal email
  - [x] Confirm same credentials used everywhere

## Phase 2: Optional Multi-Account Support (Scenario B) - NOT IMPLEMENTED

**Note**: Phase 2 was not implemented. Only Scenario A (single account with package managers) was completed.

### 6. Configuration Updates for Multi-Account
- [ ] 6.1 Update `home/.chezmoi.toml.tmpl` to add enterprise GitHub variables
  - [ ] Add `gh_enterprise_domain` variable (default: empty)
  - [ ] Add `gh_enterprise_username` variable (default: empty)
  - [ ] Add enterprise package configuration variables (optional)

### 7. Enterprise Account Script (darwin-45a)
- [ ] 7.1 Create `run_onchange_after_darwin-45a-setup-github-auth-enterprise.sh.tmpl`
  - [ ] Gate by `work` tag AND enterprise domain configuration
  - [ ] Source shared utilities
  - [ ] Require git, docker, gh CLI tools
- [ ] 7.2 Implement git credential setup for enterprise domain
  - [ ] Configure osxkeychain helper for enterprise domain
  - [ ] Set enterprise GitHub domain credentials
  - [ ] Pre-populate enterprise token in macOS Keychain
- [ ] 7.3 Implement GHCR login for enterprise
  - [ ] Login to enterprise GHCR (ghcr.io or custom domain)
- [ ] 7.4 Implement GitHub CLI authentication for enterprise
  - [ ] Configure gh CLI for enterprise domain
  - [ ] Use `--hostname` flag for enterprise domains
- [ ] 7.5 Implement package manager authentication functions
  - [ ] Add `setup_npm_github_enterprise()` function
  - [ ] Add `setup_nuget_github_enterprise()` function
  - [ ] Add `setup_maven_github_enterprise()` function
  - [ ] Add `setup_pip_github_enterprise()` function
- [ ] 7.6 Add main() function to orchestrate all setup steps
- [ ] 7.7 Add appropriate success and skip messages

### 8. Git Configuration Updates (Scenario B)
- [ ] 8.1 Update `home/dot_gitconfig.tmpl`
  - [ ] Add conditional enterprise credential routing if enterprise configured
  - [ ] Update includeIf pattern for `~/work/` to include credentials
- [ ] 8.2 Create `home/dot_gitconfig-github-enterprise.tmpl`
  - [ ] Set enterprise GitHub username
  - [ ] Set enterprise GitHub credential configuration
  - [ ] Add enterprise domain to credential helper configuration

### 9. Package Manager Multi-Account Support (Scenario B)
- [ ] 9.1 Update package manager configs to support enterprise account
  - [ ] Update `.npmrc` to conditionally add enterprise registry
  - [ ] Update `NuGet.Config` to conditionally add enterprise source
  - [ ] Update `settings.xml` to conditionally add enterprise repository
  - [ ] Update `pip.conf` to conditionally add enterprise index
- [ ] 9.2 Ensure conditional logic based on enterprise configuration

### 10. Environment Variable Multi-Account Support (Scenario B)
- [ ] 10.1 Update `home/private_dot_zsh_secrets.tmpl`
  - [ ] Add `GITHUB_TOKEN_ENTERPRISE` export (gated by work tag + enterprise domain)
  - [ ] Use "GitHub (Enterprise)" KeePassXC entry

### 11. Testing Scenario B (Multi-Account)
- [ ] 11.1 Test enterprise account only configuration
  - [ ] Verify git authentication works for enterprise domain
  - [ ] Verify enterprise GHCR authentication works
  - [ ] Verify gh CLI authentication works for enterprise
  - [ ] Verify package manager authentication (if configured)
  - [ ] Verify GITHUB_TOKEN_ENTERPRISE environment variable is set
- [ ] 11.2 Test multi-account configuration
  - [ ] Verify directory-based credential routing works
  - [ ] Test git operations in `~/work/` use enterprise credentials
  - [ ] Test git operations outside `~/work/` use personal credentials
  - [ ] Verify both environment variables are set correctly
  - [ ] Verify package managers use correct registry per account
- [ ] 11.3 Test conversion from Scenario A to Scenario B
  - [ ] Start with Scenario A configured
  - [ ] Add enterprise account
  - [ ] Verify personal account still works
  - [ ] Verify enterprise account works
  - [ ] Test rollback to Scenario A

## Phase 3: Documentation and Final Validation

### 12. Documentation
- [ ] 12.1 Create `.serena/memories/github-authentication.md`
  - [ ] Document both Scenario A and Scenario B clearly
  - [ ] Explain when to use each scenario
  - [ ] Document Scenario A: Single account + package managers (current setup enhancement)
  - [ ] Document Scenario B: Multi-account credential routing (optional)
  - [ ] Document KeePassXC entry naming convention
  - [ ] Provide PAT rotation instructions for both scenarios
  - [ ] Document package manager configuration
  - [ ] Include troubleshooting section
- [ ] 12.2 Update `.serena/memories/chezmoi-dotfiles-quick-reference.md`
  - [ ] Add GitHub authentication section
  - [ ] Reference authentication scripts
  - [ ] Document optional tag requirements
  - [ ] Clarify both scenarios supported

### 13. PAT Rotation Testing
- [ ] 13.1 Test PAT rotation for Scenario A
  - [ ] Update PAT in "GitHub" KeePassXC entry
  - [ ] Run `chezmoi apply`
  - [ ] Verify credentials updated in keychain
  - [ ] Verify git/GHCR/CLI/packages still work
- [ ] 13.2 Test PAT rotation for Scenario B (if applicable)
  - [ ] Update personal PAT
  - [ ] Verify only personal script re-executes
  - [ ] Update enterprise PAT
  - [ ] Verify only enterprise script re-executes

### 14. Spec Updates
- [x] 14.1 Verify spec delta is correct and comprehensive
- [x] 14.2 Ensure spec covers both scenarios
- [ ] 14.3 Run `openspec validate enhance-github-auth --strict` - Not run (openspec CLI not installed)
- N/A 14.4 Fix any validation issues

### 15. Final Review
- [x] 15.1 Review all changes for clarity on both scenarios
- [x] 15.2 Ensure code style matches existing scripts
- [x] 15.3 Verify all shared utilities are used correctly
- [x] 15.4 Check for any hardcoded values that should be templated
- [x] 15.5 Verify all error messages are clear and helpful
- [x] 15.6 Confirm no secrets are hardcoded or committed
- [x] 15.7 Verify Scenario A implementation works without Scenario B components
- [x] 15.8 Verify backward compatibility maintained