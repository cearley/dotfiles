## 1. Work Account Authentication Script
- [ ] 1.1 Create `run_onchange_after_darwin-46-setup-azure-auth.sh.tmpl`
- [ ] 1.2 Implement `setup_git_credentials()` for dev.azure.com and *.visualstudio.com
- [ ] 1.3 Implement `setup_azure_cli()` for DevOps extension configuration
- [ ] 1.4 Implement `setup_acr_login()` for Container Registry authentication
- [ ] 1.5 Implement `main()` function with sequential setup execution
- [ ] 1.6 Add template conditional wrapper (macOS + KeePassXC + work tag)

## 2. Personal Account Authentication Script
- [ ] 2.1 Create `run_onchange_after_darwin-47-setup-azure-auth-personal.sh.tmpl`
- [ ] 2.2 Implement `setup_git_credentials()` for personal account (dev.azure.com and *.visualstudio.com)
- [ ] 2.3 Implement optional `setup_azure_cli()` for personal DevOps extension
- [ ] 2.4 Add placeholder comments for future ACR and package manager support
- [ ] 2.5 Implement `main()` function with sequential setup execution
- [ ] 2.6 Add template conditional wrapper (macOS + KeePassXC + dev tag)

## 3. Git Configuration
- [ ] 3.1 Update `dot_gitconfig.tmpl` with Azure DevOps credential sections (work account global)
- [ ] 3.2 Add username configuration for dev.azure.com domain (work)
- [ ] 3.3 Add username configuration for visualstudio.com domain (work)
- [ ] 3.4 Add `includeIf` directive for `~/personal/azure/` directory
- [ ] 3.5 Create `dot_gitconfig-azure-personal.tmpl` with personal account credential overrides
- [ ] 3.6 Gate work configuration with work tag and KeePassXC availability
- [ ] 3.7 Gate personal configuration with dev tag and KeePassXC availability

## 4. Template Variables
- [ ] 4.1 Add Azure DevOps work account prompts to `.chezmoi.toml.tmpl` (gated by work tag)
- [ ] 4.2 Add `azure_devops_org` prompt for work
- [ ] 4.3 Add `azure_devops_username` prompt for work
- [ ] 4.4 Add `azure_devops_email` prompt for work
- [ ] 4.5 Add optional feed name prompts for work (npm, NuGet, Python, Maven)
- [ ] 4.6 Add `acr_registries` prompt for work (comma-separated list)
- [ ] 4.7 Add Azure DevOps personal account prompts (gated by dev tag)
- [ ] 4.8 Add `azure_devops_org_personal` prompt
- [ ] 4.9 Add `azure_devops_username_personal` prompt
- [ ] 4.10 Add `azure_devops_email_personal` prompt (for future use)
- [ ] 4.11 Add all variables to [data] section

## 5. Environment Configuration
- [ ] 5.1 Update `private_dot_zsh_secrets.tmpl` with AZURE_DEVOPS_EXT_PAT export (work account)
- [ ] 5.2 Add AZURE_DEVOPS_EXT_PAT_PERSONAL export (personal account, optional)
- [ ] 5.3 Gate work environment variable with work tag and KeePassXC availability
- [ ] 5.4 Gate personal environment variable with dev tag and KeePassXC availability

## 6. Package Manager Configurations (Work Account Only)
- [ ] 6.1 Extend `private_dot_npmrc.tmpl` with Azure Artifacts authentication (work)
- [ ] 6.2 Create `private_dot_nuget/NuGet/private_NuGet.Config.tmpl` with Azure source (work)
- [ ] 6.3 Create `private_dot_m2/private_settings.xml.tmpl` with Azure server credentials (work)
- [ ] 6.4 Create `private_dot_config/private_pip/private_pip.conf.tmpl` with Azure index URL (work)
- [ ] 6.5 Make all package configs conditional on feed names being provided
- [ ] 6.6 Add comments noting personal account support is reserved for future implementation

## 7. KeePassXC Entry Setup
- [ ] 7.1 Document "Azure DevOps (Willdan)" entry structure and required PAT scopes
- [ ] 7.2 Document "Azure DevOps (CES)" entry structure and required PAT scopes
- [ ] 7.3 Document how to create both entries in KeePassXC

## 8. Documentation
- [ ] 8.1 Create `.serena/memories/azure-devops-authentication.md`
- [ ] 8.2 Document multi-account architecture and directory structure
- [ ] 8.3 Document KeePassXC entry structures for both accounts
- [ ] 8.4 Document authentication flow for each service (work and personal)
- [ ] 8.5 Document PAT rotation procedure for both accounts
- [ ] 8.6 Document troubleshooting steps for multi-account scenarios
- [ ] 8.7 Document staged adoption approach (git only → add package managers → add ACR)
- [ ] 8.8 Document future enhancement path for personal account package managers
- [ ] 8.9 Update `.serena/memories/chezmoi-dotfiles-quick-reference.md`

## 9. Testing - Work Account
- [ ] 9.1 Create KeePassXC entry "Azure DevOps (Willdan)" with "Access Token" attribute
- [ ] 9.2 Test git clone from work Azure DevOps repository (from ~/work/)
- [ ] 9.3 Test `az devops` CLI commands with work org
- [ ] 9.4 Test ACR docker pull (after `az login`)
- [ ] 9.5 Test npm install from work Azure Artifacts
- [ ] 9.6 Test NuGet restore from work Azure Artifacts
- [ ] 9.7 Test PAT rotation (update work KeePassXC entry, run `chezmoi apply`)
- [ ] 9.8 Verify script skips when work tag not present

## 10. Testing - Personal Account
- [ ] 10.1 Create KeePassXC entry "Azure DevOps (CES)" with "Access Token" attribute
- [ ] 10.2 Test git clone from personal Azure DevOps repository (from ~/personal/azure/)
- [ ] 10.3 Test `az devops` CLI commands with personal org (if configured)
- [ ] 10.4 Test PAT rotation (update personal KeePassXC entry, run `chezmoi apply`)
- [ ] 10.5 Verify script requires dev tag (skips without dev tag even when KeePassXC available)

## 11. Testing - Multi-Account Scenarios
- [ ] 11.1 Verify git uses work credentials in ~/work/ directory
- [ ] 11.2 Verify git uses personal credentials in ~/personal/azure/ directory
- [ ] 11.3 Verify both scripts can run independently
- [ ] 11.4 Test error handling with missing tools
- [ ] 11.5 Verify script skips when KeePassXC unavailable
