## Context
Azure DevOps provides enterprise git hosting, artifact management, and container registries. Authentication requires Personal Access Tokens (PATs) with specific scopes. This implementation mirrors the existing GitHub authentication pattern established in `run_onchange_after_darwin-45-setup-github-auth.sh.tmpl`, maintaining architectural consistency.

**Constraints:**
- Must follow existing GitHub authentication pattern
- Must use KeePassXC for secret storage (no hardcoded credentials)
- Must support token rotation without manual intervention
- Must work with multiple Azure services (git, CLI, ACR, Artifacts)
- Must be optional (gated by work tag for enterprise context)

**Stakeholders:**
- Developers using Azure DevOps for work projects
- Teams using Azure Artifacts for package management
- Organizations using Azure Container Registry

## Goals / Non-Goals

**Goals:**
- Automated Azure DevOps authentication across all services
- Persistent credential storage (no password prompts)
- Automatic re-execution on PAT rotation
- Support for polyglot development (npm, NuGet, Maven, Python)
- Clear error messages and troubleshooting guidance

**Non-Goals:**
- Service Principal authentication (enterprise CI/CD, not dotfiles concern)
- Multi-organization support (single org per machine is sufficient)
- Azure resource management authentication (requires interactive `az login`)
- Windows or Linux implementations (macOS only for now)

## Decisions

### Decision 1: Separate Script from GitHub Authentication
**Choice:** Create `darwin-46-setup-azure-auth.sh.tmpl` as a separate script

**Rationale:**
- Independent triggering when Azure PAT changes (GitHub PAT changes won't trigger Azure script)
- Clear separation of concerns (single responsibility principle)
- Easier to disable for organizations not using Azure
- Mirrors the pattern of separate, focused scripts for specific services

**Alternatives considered:**
- **Combined authentication script**: Would tightly couple GitHub and Azure, making both re-execute when either token changes. Harder to maintain and debug.
- **Plugin system**: Over-engineered for two authentication providers.

### Decision 2: osxkeychain Credential Helper
**Choice:** Use macOS Keychain (`osxkeychain` helper) with pre-populated credentials

**Rationale:**
- Consistent with GitHub authentication pattern
- Persistent storage survives reboots
- Encrypted by macOS
- No password prompts after initial setup
- Standard git credential helper protocol

**Alternatives considered:**
- **cache helper**: Temporary (lost after timeout or reboot)
- **store helper**: Plaintext on disk (security risk)

### Decision 3: Azure CLI Authentication Method
**Choice:** Use `AZURE_DEVOPS_EXT_PAT` environment variable for Azure DevOps extension

**Rationale:**
- PATs work for Azure DevOps Services (repos, pipelines, artifacts)
- Environment variable is the standard authentication method for `az devops` commands
- General Azure resource management requires `az login` (interactive), which is acceptable as a one-time operation
- Simple and well-documented

**Alternatives considered:**
- **Service Principal**: More complex, requires Azure AD management, overkill for individual developers
- **PAT-only for all az commands**: Not supported by Azure CLI for resource management

### Decision 4: ACR Authentication via `az acr login`
**Choice:** Primary method is `az acr login`, with note that `az login` is required first

**Rationale:**
- Microsoft's recommended approach
- Uses Azure AD authentication with automatic token refresh
- More secure than storing PAT in Docker config
- One-time `az login` is acceptable trade-off for better security

**Alternatives considered:**
- **PAT-based docker login**: Less secure, manual token rotation required, deprecated by Microsoft
- **Docker credential helper**: Still requires `az login` under the hood

### Decision 5: Support Multiple Package Managers
**Choice:** Provide configuration for npm, NuGet, Maven, and Python pip

**Rationale:**
- Enterprise environments are often polyglot (.NET + Java + Node.js + Python)
- Each configuration is optional (only activates if feed name provided)
- Covers most common enterprise package managers
- Small implementation cost for high value

**Alternatives considered:**
- **npm-only**: Insufficient for .NET/Java organizations
- **All package managers**: Too comprehensive (skip less common ones like Gradle, SBT, Gem)

### Decision 6: Tag-Based Gating
**Choice:** Require `work` tag for work account (Willdan) and `dev` tag for personal account (CES)

**Rationale:**
- Work account (Willdan) gated by `work` tag (enterprise/work context)
- Personal account (CES) gated by `dev` tag (development/personal projects)
- Both tags provide clear organizational separation
- Prevents accidental configuration on machines where accounts aren't needed
- Users explicitly opt-in by selecting appropriate tags during `chezmoi init`
- dev tag already indicates development activities, appropriate for personal Azure DevOps projects

**Alternatives considered:**
- **No gating for personal**: Would configure personal account on all machines with KeePassXC (wasteful)
- **Both require work tag**: Would prevent personal account on personal-only machines
- **Separate azure_personal tag**: Too granular, dev tag already exists and is semantically appropriate
- **Always install both**: Wastes configuration time on machines that don't need either account

### Decision 7: Legacy Domain Support
**Choice:** Support both dev.azure.com (modern) and *.visualstudio.com (legacy)

**Rationale:**
- Many organizations still have repositories on visualstudio.com
- Migration to dev.azure.com is ongoing but not universal
- Low implementation cost (just duplicate credential config)
- Better user experience (works regardless of domain)

**Alternatives considered:**
- **Modern domain only**: Would break for users with legacy repositories
- **User-specified domains**: Too complex for minimal benefit

### Decision 8: Multi-Account Support Architecture
**Choice:** Two separate authentication scripts with directory-based git credential routing

**Rationale:**
- Developers commonly maintain work + personal/learning Azure DevOps accounts
- Directory-based routing (`~/work/` vs `~/personal/azure/`) provides automatic context switching
- Follows existing GitHub work config pattern (`includeIf "gitdir:~/work/"`)
- Two scripts allow independent execution and PAT rotation per account
- Work account gated by work tag, personal account always available (when KeePassXC configured)
- Physical directory separation prevents accidental credential misuse

**Alternatives considered:**
- **Single script, multiple accounts**: More complex logic, harder to maintain, both accounts re-execute on any PAT change
- **Manual git config switching**: Error-prone, defeats automation goal
- **Environment variables for account selection**: Requires remembering to set before operations
- **Host-based routing** (work.visualstudio.com vs personal.visualstudio.com): Not all orgs use custom domains

**Implementation details:**
- Work script (darwin-46): Full features (git, CLI, ACR, all package managers), requires work tag
- Personal script (darwin-47): Git + optional CLI only, requires dev tag
- Git configuration: Work as global default, personal overrides via `includeIf` for `~/personal/azure/`
- KeePassXC entries: "Azure DevOps (Willdan)" and "Azure DevOps (CES)"
- Package managers: Work account only initially, personal account reserved for future

**Directory structure:**
```
~/work/                    # Work projects (uses work Azure DevOps)
  └── azure/              # Work Azure repos
~/personal/azure/          # Personal projects (uses personal Azure DevOps)
  ├── learning/           # Learning projects
  └── business/           # Personal business projects
```

## Risks / Trade-offs

### Risk: PAT Expiration
**Impact:** Authentication breaks when PAT expires
**Likelihood:** High (PATs typically expire after 1 year or less)
**Mitigation:**
- Clear error messages when PAT validation fails
- Documentation includes rotation procedure
- Hash-based re-execution makes rotation simple (update KeePassXC, run `chezmoi apply`)
- Consider adding calendar reminder in documentation

### Risk: `az login` Required for ACR
**Impact:** Users must remember to run `az login` before ACR access works
**Likelihood:** Medium (one-time operation, but easy to forget)
**Mitigation:**
- Script displays tip message explaining `az login` requirement
- Documentation clearly states this requirement
- Fallback to PAT-based docker login available if needed

### Risk: Multiple Azure Artifacts Feeds
**Impact:** Organizations may have multiple feeds per package manager
**Likelihood:** Medium (larger orgs often separate feeds by team/project)
**Mitigation:**
- Current implementation supports one feed per package manager
- Users can manually edit config files for multiple feeds
- Future enhancement if needed (low priority)

### Trade-off: Simplicity vs. Validation
**Choice:** Minimal validation (just tool checks), following GitHub pattern
**Rationale:**
- Consistent with existing patterns
- Failures are caught by actual usage (git operations, npm install, etc.)
- Over-validation adds complexity and maintenance burden
**Downside:** Less helpful error messages before actual usage

### Trade-off: Azure Artifacts Optional Feeds
**Choice:** All package manager feeds are optional (empty string = skip)
**Rationale:**
- Not all organizations use all package managers
- Allows incremental adoption
- Reduces prompting overhead
**Downside:** Users must know to provide feed names for their package managers

### Risk: Directory Discipline Required
**Impact:** Git uses wrong credentials if repos cloned in incorrect directories
**Likelihood:** Medium (users must remember ~/work/ vs ~/personal/azure/ convention)
**Mitigation:**
- Clear documentation of directory structure
- Git credential errors will be obvious (authentication failures)
- Can manually specify credentials during clone if needed
- Personal account only affects ~/personal/azure/, rest of system uses work account

### Trade-off: Personal Account Limited Features Initially
**Choice:** Personal account supports git + optional CLI only (no package managers or ACR initially)
**Rationale:**
- Most personal projects only need git access
- Reduces initial complexity
- Package managers and ACR can be added later if needed
- Most personal Azure DevOps usage is for learning/hobby projects
**Downside:** Users with advanced personal projects must manually configure package managers

### Risk: Two PATs to Manage
**Impact:** More credentials to track and rotate
**Likelihood:** High (both PATs will expire)
**Mitigation:**
- Independent rotation per account reduces blast radius
- Both use same KeePassXC-based rotation workflow
- Can choose to only configure accounts you actually use (staged adoption)

## Migration Plan

**For new machines (work + personal):**
1. Select `work` and `dev` tags during `chezmoi init`
2. Provide work Azure DevOps organization (Willdan) and optional feed names
3. Provide personal Azure DevOps organization (CES) (username will be prompted)
4. Create KeePassXC entries:
   - "Azure DevOps (Willdan)" with work PAT
   - "Azure DevOps (CES)" with personal PAT
5. Run `chezmoi apply`
6. Run `az login` once for ACR access (work account)
7. Create directory structure:
   - `mkdir -p ~/work/azure` for work projects
   - `mkdir -p ~/personal/azure` for personal projects

**For new machines (work only):**
1. Select `work` tag during `chezmoi init` (no dev tag)
2. Provide work Azure DevOps configuration (Willdan)
3. Skip/leave empty personal Azure DevOps prompts (or they won't appear without dev tag)
4. Create KeePassXC entry "Azure DevOps (Willdan)" with PAT
5. Run `chezmoi apply`
6. Run `az login` once for ACR access

**For new machines (personal only):**
1. Select `dev` tag during `chezmoi init` (no work tag)
2. Skip/leave empty work Azure DevOps prompts (or they won't appear without work tag)
3. Provide personal Azure DevOps configuration (CES)
4. Create KeePassXC entry "Azure DevOps (CES)" with PAT
5. Run `chezmoi apply`
6. Personal git authentication will be configured

**For existing machines:**
1. Update `.chezmoi.toml.tmpl` with Azure variables (or re-run `chezmoi init`)
2. Ensure appropriate tags are set (work for Willdan, dev for CES)
3. Create KeePassXC entries:
   - "Azure DevOps (Willdan)" for work account
   - "Azure DevOps (CES)" for personal account
4. Run `chezmoi apply`
5. Run `az login` once for ACR access (if using work account)
6. Organize existing Azure repos into appropriate directories

**Staged adoption (git only first):**
1. Provide organization and username during init
2. Leave all feed names and ACR registries empty
3. Only git authentication will be configured
4. Later: Edit `.chezmoi.toml.tmpl` to add feed names, run `chezmoi apply`

**Adding personal account later:**
1. Add `dev` tag to `.chezmoi.toml.tmpl` tags list
2. Edit `.chezmoi.toml.tmpl` to add personal account variables (or re-run `chezmoi init`)
3. Create KeePassXC entry "Azure DevOps (CES)"
4. Run `chezmoi apply`
5. Personal script will execute, work account unaffected

**Rollback:**
- **Disable work account**: Remove `work` tag from `.chezmoi.toml.tmpl`, run `chezmoi apply`
- **Disable personal account**: Remove `dev` tag from `.chezmoi.toml.tmpl`, run `chezmoi apply`
- **Both accounts**: Remove both `work` and `dev` tags, or remove all Azure variables, run `chezmoi apply`

**No data loss:** All configurations are additive, no existing functionality affected. Both scripts can be disabled independently.

## Open Questions
None - all design decisions finalized based on user requirements.
