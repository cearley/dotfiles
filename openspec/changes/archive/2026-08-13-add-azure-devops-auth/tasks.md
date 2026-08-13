## 1. Work Account Authentication Script
- [x] 1.1 Create `run_onchange_after_darwin-47-setup-azure-auth.sh.tmpl` (order 47, not 46 — see note in azure-devops-authentication Basic Memory note)
- [x] 1.2 Implement `setup_git_credentials()` for dev.azure.com and *.visualstudio.com
- [x] 1.3 Implement `setup_azure_cli()` for DevOps extension configuration
- [x] 1.4 Implement `setup_acr_login()` for Container Registry authentication
- [x] 1.5 Implement `main()` function with sequential setup execution
- [x] 1.6 Add template conditional wrapper (macOS + KeePassXC + work tag)

## 2. Personal Account Authentication Script
- [x] 2.1 Create `run_onchange_after_darwin-48-setup-azure-auth-personal.sh.tmpl` (order 48, not 47 — see note in azure-devops-authentication Basic Memory note)
- [x] 2.2 Implement `setup_git_credentials()` for personal account (dev.azure.com and *.visualstudio.com)
- [x] 2.3 Implement optional `setup_azure_cli()` for personal DevOps extension
- [x] 2.4 Add placeholder comments for future ACR and package manager support
- [x] 2.5 Implement `main()` function with sequential setup execution
- [x] 2.6 Add template conditional wrapper (macOS + KeePassXC + dev tag)

## 3. Git Configuration
- [x] 3.1 Update `dot_gitconfig.tmpl` with Azure DevOps credential sections (work account global)
- [x] 3.2 Add username configuration for dev.azure.com domain (work)
- [x] 3.3 Add username configuration for visualstudio.com domain (work)
- [x] 3.4 Add `includeIf` directive for `~/personal/azure/` directory
- [x] 3.5 Create `dot_gitconfig-azure-personal.tmpl` with personal account credential overrides
- [x] 3.6 Gate work configuration with work tag and KeePassXC availability
- [x] 3.7 Gate personal configuration with dev tag and KeePassXC availability

## 4. Template Variables
- [x] 4.1 Add Azure DevOps work account prompts to `.chezmoi.toml.tmpl` (gated by work tag)
- [x] 4.2 Add `azure_devops_org` prompt for work
- [x] 4.3 Add `azure_devops_username` prompt for work
- [x] 4.4 Add `azure_devops_email` prompt for work
- [x] 4.5 Add optional feed name prompts for work (npm, NuGet, Python, Maven)
- [x] 4.6 Add `acr_registries` prompt for work (comma-separated list)
- [x] 4.7 Add Azure DevOps personal account prompts (gated by dev tag)
- [x] 4.8 Add `azure_devops_org_personal` prompt
- [x] 4.9 Add `azure_devops_username_personal` prompt
- [x] 4.10 Add `azure_devops_email_personal` prompt (for future use)
- [x] 4.11 Add all variables to [data] section

## 5. Environment Configuration
- [x] 5.1 Update `private_dot_zsh_secrets.tmpl` with AZURE_DEVOPS_EXT_PAT export (work account)
- [x] 5.2 Add AZURE_DEVOPS_EXT_PAT_PERSONAL export (personal account, optional)
- [x] 5.3 Gate work environment variable with work tag and KeePassXC availability
- [x] 5.4 Gate personal environment variable with dev tag and KeePassXC availability

## 6. Package Manager Configurations (Work Account Only)
- [x] 6.1 Extend `private_dot_npmrc.tmpl` with Azure Artifacts authentication (work)
- [x] 6.2 Create `private_dot_nuget/NuGet/private_NuGet.Config.tmpl` with Azure source (work)
- [x] 6.3 Create `private_dot_m2/private_settings.xml.tmpl` with Azure server credentials (work)
- [x] 6.4 Create `private_dot_config/private_pip/private_pip.conf.tmpl` with Azure index URL (work)
- [x] 6.5 Make all package configs conditional on feed names being provided
- [x] 6.6 Add comments noting personal account support is reserved for future implementation

## 7. KeePassXC Entry Setup
- [x] 7.1 Document "Azure DevOps (Willdan)" entry structure and required PAT scopes
- [x] 7.2 Document "Azure DevOps (CES)" entry structure and required PAT scopes
- [x] 7.3 Document how to create both entries in KeePassXC

## 8. Documentation
(Redirected 2026-08-13: `.serena/memories/` no longer exists — Serena is now an opt-in plugin. Docs written to the `chezmoi` Basic Memory project instead; see proposal.md Impact section.)
- [x] 8.1 Create Basic Memory note "Azure DevOps Authentication" in the `chezmoi` project
- [x] 8.2 Document multi-account architecture and directory structure
- [x] 8.3 Document KeePassXC entry structures for both accounts
- [x] 8.4 Document authentication flow for each service (work and personal)
- [x] 8.5 Document PAT rotation procedure for both accounts
- [x] 8.6 Document troubleshooting steps for multi-account scenarios
- [x] 8.7 Document staged adoption approach (git only → add package managers → add ACR)
- [x] 8.8 Document future enhancement path for personal account package managers
- [x] 8.9 Update "Chezmoi Dotfiles Project Architecture" note in the `chezmoi` Basic Memory project

## 9. Testing - Work Account
- [x] 9.1 Create KeePassXC entry "Azure DevOps (Willdan)" with "Access Token" attribute
- [x] 9.2 Test git clone from work Azure DevOps repository (from ~/work/)
- [x] 9.3 Test `az devops` CLI commands with work org
- [ ] 9.4 Test ACR docker pull (after `az login`) — deferred 2026-08-13: no ACR registry configured/available to test against
- [ ] 9.5 Test npm install from work Azure Artifacts — deferred 2026-08-13: no npm feed URL configured/available to test against
- [ ] 9.6 Test NuGet restore from work Azure Artifacts — deferred 2026-08-13: no NuGet feed URL configured/available to test against
- [x] 9.7 Test PAT rotation (update work KeePassXC entry, run `chezmoi apply`)
- [x] 9.8 Verify script skips when work tag not present (verified via sandboxed template render — empty output with work tag absent)

## 10. Testing - Personal Account
(Deferred 2026-08-13: user has not set up a personal Azure DevOps account on this machine yet. Work-only testing proceeding in section 9; revisit this section if/when a personal account is configured.)
- [ ] 10.1 Create KeePassXC entry "Azure DevOps (CES)" with "Access Token" attribute
- [ ] 10.2 Test git clone from personal Azure DevOps repository (from ~/personal/azure/)
- [ ] 10.3 Test `az devops` CLI commands with personal org (if configured)
- [ ] 10.4 Test PAT rotation (update personal KeePassXC entry, run `chezmoi apply`)
- [ ] 10.5 Verify script requires dev tag (skips without dev tag even when KeePassXC available)

## 11. Testing - Multi-Account Scenarios
- [x] 11.1 Verify git uses work credentials in ~/work/ directory
- [ ] 11.2 Verify git uses personal credentials in ~/personal/azure/ directory — deferred 2026-08-13: no personal account configured (see section 10)
- [ ] 11.3 Verify both scripts can run independently — deferred 2026-08-13: no personal account configured (see section 10)
- [x] 11.4 Test error handling with missing tools (verified in isolated sandbox: fake GIT_CONFIG_GLOBAL + cache credential helper, PATH without az — script skipped az devops config gracefully, exit 0)
- [x] 11.5 Verify script skips when KeePassXC unavailable
