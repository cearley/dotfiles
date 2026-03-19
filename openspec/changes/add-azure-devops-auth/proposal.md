# Change: Azure DevOps Multi-Account Authentication Management

## Why
Development teams using Azure DevOps Repos, Azure Artifacts, and Azure Container Registry need automated credential management similar to the existing GitHub authentication system. Additionally, developers often maintain multiple Azure DevOps accounts (work + personal/learning), requiring context-aware authentication.

Currently, Azure DevOps credentials must be configured manually on each machine, leading to:
- Inconsistent setup across development environments
- Password prompts interrupting git workflows
- Manual token rotation when credentials expire
- No unified authentication for Azure Artifacts package feeds
- Difficulty maintaining Docker credentials for Azure Container Registry
- No support for multiple Azure DevOps accounts with automatic context switching

This change brings Azure DevOps authentication to parity with GitHub authentication, following the established KeePassXC-based pattern, while adding multi-account support via directory-based configuration.

## What Changes

### Multi-Account Support
- **Work account (Willdan)** authentication script: `run_onchange_after_darwin-46-setup-azure-auth.sh.tmpl`
  - Gated by `work` tag (enterprise context)
  - Full feature support: git, Azure CLI, ACR, all package managers
  - KeePassXC entry: "Azure DevOps (Willdan)"
  - Default authentication for `~/work/` directory

- **Personal account (CES)** authentication script: `run_onchange_after_darwin-47-setup-azure-auth-personal.sh.tmpl`
  - Gated by `dev` tag (development/personal projects)
  - Git authentication for `~/personal/azure/` directory
  - Optional Azure CLI support
  - Package managers and ACR support reserved for future implementation
  - KeePassXC entry: "Azure DevOps (CES)"

### Git Configuration
- Directory-based credential configuration using `includeIf`
- Work account as global default
- Personal account overrides for `~/personal/azure/` directory
- Support for both dev.azure.com and *.visualstudio.com domains

### Package Manager Authentication (Work Account)
- npm (.npmrc) for Azure Artifacts
- NuGet (NuGet.Config) for Azure Artifacts
- Maven (settings.xml) for Azure Artifacts
- Python pip (pip.conf) for Azure Artifacts
- All optional (staged adoption supported)

### Azure Services
- Azure CLI DevOps extension with PAT-based authentication
- Azure Container Registry authentication via `az acr login`
- Separate environment variables per account

### Configuration
- Template variables for both work and personal accounts in `.chezmoi.toml.tmpl`
- Separate KeePassXC entries for account isolation
- Independent PAT rotation per account
- Documentation in Serena memory system

### Gating
- **Work account (Willdan)**: Requires `work` tag + KeePassXC
- **Personal account (CES)**: Requires `dev` tag + KeePassXC
- macOS only (following existing pattern)

## Impact
- **Affected specs**: `secret-management` (added Azure DevOps multi-account authentication requirements)
- **Affected code**:
  - **Work account**:
    - `home/.chezmoiscripts/run_onchange_after_darwin-46-setup-azure-auth.sh.tmpl` (create)
    - `home/private_dot_npmrc.tmpl` (modify - add Azure Artifacts)
    - `home/private_dot_nuget/NuGet/private_NuGet.Config.tmpl` (create)
    - `home/private_dot_m2/private_settings.xml.tmpl` (create)
    - `home/private_dot_config/private_pip/private_pip.conf.tmpl` (create)
  - **Personal account**:
    - `home/.chezmoiscripts/run_onchange_after_darwin-47-setup-azure-auth-personal.sh.tmpl` (create)
  - **Shared configuration**:
    - `home/.chezmoi.toml.tmpl` (modify - add Azure prompts for both accounts)
    - `home/dot_gitconfig.tmpl` (modify - add Azure credential config with includeIf)
    - `home/dot_gitconfig-azure-personal.tmpl` (create - personal account overrides)
    - `home/private_dot_zsh_secrets.tmpl` (modify - add AZURE_DEVOPS_EXT_PAT for both accounts)
  - **Documentation**:
    - `.serena/memories/azure-devops-authentication.md` (create)
    - `.serena/memories/chezmoi-dotfiles-quick-reference.md` (modify)
- **Dependencies**: Azure CLI (already in packages.yaml), docker, git
- **Breaking changes**: None (purely additive)
