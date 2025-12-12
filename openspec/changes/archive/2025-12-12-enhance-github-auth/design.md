## Context
GitHub provides git hosting, package registries (GitHub Packages), and container registries (GHCR). Authentication requires Personal Access Tokens (PATs) with specific scopes. This enhancement extends the existing GitHub authentication pattern to match Azure DevOps capabilities, maintaining architectural consistency across all authentication systems.

**Constraints:**
- Must maintain backward compatibility with existing single-account setup
- Must use KeePassXC for secret storage (no hardcoded credentials)
- Must support token rotation without manual intervention
- Must work with multiple GitHub services (git, CLI, GHCR, Packages)
- Must support both github.com and GitHub Enterprise domains
- Must be optional via tag-based gating

**Stakeholders:**
- Developers using GitHub for both personal and work projects
- Teams using GitHub Packages for dependency management
- Organizations using GitHub Enterprise
- Open source contributors needing separate work/personal identities

## Goals / Non-Goals

**Goals:**
- Multi-account support (personal + enterprise GitHub)
- Automated GitHub Packages authentication across all package managers
- Environment variable exports for CLI tools
- Directory-based credential routing
- Tag-based gating for selective deployment
- Persistent credential storage (no password prompts)
- Automatic re-execution on PAT rotation
- Clear error messages and troubleshooting guidance

**Non-Goals:**
- GitHub Apps authentication (OAuth apps, not individual PATs)
- GitHub Actions runner configuration (CI/CD, not dotfiles concern)
- Multi-organization support beyond personal + work (single org per context is sufficient)
- Windows or Linux implementations (macOS only for now)

## Decisions

### Decision 1: Support Both Single-Account and Multi-Account Scenarios
**Choice:** Design implementation to support two distinct usage patterns

**Scenario A: Single Account, Multiple Commit Identities**
- One GitHub account, one set of credentials
- Same PAT used for git, packages, CLI everywhere
- Directory-based email changes only (existing `includeIf` behavior)
- Minimal configuration changes required
- **This is the current/common pattern** - just enhance it with package managers

**Scenario B: Multiple Accounts**
- Separate GitHub accounts with separate credentials
- Directory-based credential routing (different PATs per directory)
- Optional/advanced feature requiring explicit configuration
- Enterprise script only runs if enterprise domain is configured

**Rationale:**
- Preserves existing user workflows (Scenario A users get packages without disruption)
- Provides flexibility for users who need true multi-account (Scenario B)
- Avoids forcing complexity on users who don't need it
- Common pattern: many developers use one GitHub account with different commit emails for work vs personal
- Less common pattern: separate enterprise GitHub instance requiring different credentials
- Implementation cost is low: same code supports both scenarios with conditional logic

**Alternatives considered:**
- **Multi-account only**: Would force users to configure two accounts even if they only have one (increased complexity)
- **Single-account only**: Wouldn't support users with GitHub Enterprise (missing important use case)
- **Two separate proposals**: Would duplicate package manager implementation across both

### Decision 2: Separate Script for Enterprise GitHub (Scenario B Only)
**Choice:** Create `darwin-45a-setup-github-auth-enterprise.sh.tmpl` as an optional separate script

**Rationale:**
- Only runs if enterprise GitHub is explicitly configured (Scenario B users only)
- Independent triggering when enterprise PAT changes (personal PAT changes won't trigger enterprise script)
- Clear separation of concerns (single responsibility principle)
- Easier to disable for developers without enterprise GitHub access
- Maintains backward compatibility (existing script continues to work for Scenario A)
- Follows Azure DevOps pattern of separate scripts per account

**Alternatives considered:**
- **Single script with conditionals**: Would tightly couple personal and enterprise auth, making both re-execute when either token changes
- **Modify existing script only**: Wouldn't provide multi-account support (Scenario B)
- **Three+ scripts (personal, enterprise, shared)**: Over-engineered for two accounts

### Decision 3: osxkeychain Credential Helper (Existing Pattern)
**Choice:** Continue using macOS Keychain (`osxkeychain` helper) with pre-populated credentials

**Rationale:**
- Already implemented and working in current setup
- Persistent storage survives reboots
- Encrypted by macOS
- No password prompts after initial setup
- Standard git credential helper protocol
- Consistent with Azure DevOps pattern

**Alternatives considered:**
- **cache helper**: Temporary (lost after timeout or reboot)
- **store helper**: Plaintext on disk (security risk)

### Decision 4: GitHub CLI Authentication Method
**Choice:** Use `gh auth login --with-token` for GitHub CLI

**Rationale:**
- Already implemented in existing script
- Standard authentication method
- Works with both github.com and GitHub Enterprise
- Supports all gh CLI commands
- Token stored securely in system keychain

**Alternatives considered:**
- **Browser-based auth**: Interactive, doesn't support automation
- **SSH keys only**: Doesn't support GitHub API operations

### Decision 5: Environment Variable Exports
**Choice:** Export `GITHUB_TOKEN` for personal account and optionally `GITHUB_TOKEN_ENTERPRISE` for work account

**Rationale:**
- Many CLI tools expect `GITHUB_TOKEN` environment variable
- Enables GitHub API scripting without additional configuration
- Required by tools like `act` (GitHub Actions local runner)
- Common pattern in GitHub documentation
- Separate variable names prevent credential conflicts

**Alternatives considered:**
- **No environment variables**: Would require manual configuration for each tool
- **Single GITHUB_TOKEN variable**: Would conflict between accounts
- **GH_TOKEN alias**: Less standard than GITHUB_TOKEN

### Decision 6: Package Manager Support
**Choice:** Provide configuration for npm, NuGet, Maven, and Python pip

**Rationale:**
- GitHub Packages supports all four package types
- Enterprise environments are often polyglot
- Each configuration is optional (only activates if package owner/repo provided)
- Brings GitHub to parity with Azure DevOps implementation
- Small implementation cost for high value

**Alternatives considered:**
- **npm-only**: Insufficient for .NET/Java organizations
- **All package managers**: GitHub Packages doesn't support as many types as Azure Artifacts

### Decision 7: Tag-Based Gating
**Choice:** Require `dev` tag for personal account and `work` tag for enterprise account

**Rationale:**
- Personal account gated by `dev` tag (development/personal projects)
- Enterprise account gated by `work` tag (enterprise/work context)
- Prevents unnecessary configuration on machines where accounts aren't needed
- Users explicitly opt-in by selecting appropriate tags during `chezmoi init`
- Matches Azure DevOps pattern
- **Breaking change mitigation**: Existing users may not have tags, so scripts should check for both tag presence AND KeePassXC

**Alternatives considered:**
- **No gating**: Would configure on all machines with KeePassXC (current behavior, wasteful)
- **Both require work tag**: Would prevent personal account on personal-only machines
- **Separate github_enterprise tag**: Too granular, work tag already exists
- **Always install both**: Wastes configuration time on machines that don't need both accounts

### Decision 8: Multi-Account Support Architecture (Scenario B)
**Choice:** Two separate authentication scripts with directory-based git credential routing

**Rationale:**
- Developers commonly maintain personal GitHub + enterprise GitHub accounts
- Directory-based routing (`~/work/` vs `~/personal/github/`) provides automatic context switching
- Follows existing work directory pattern (`includeIf "gitdir:~/work/"`)
- Two scripts allow independent execution and PAT rotation per account
- Personal account gated by dev tag, enterprise account gated by work tag
- Physical directory separation prevents accidental credential misuse
- Common workflow: personal projects in ~/personal/, work projects in ~/work/

**Alternatives considered:**
- **Single script, multiple accounts**: More complex logic, harder to maintain, both accounts re-execute on any PAT change
- **Manual git config switching**: Error-prone, defeats automation goal
- **Environment variables for account selection**: Requires remembering to set before operations
- **Host-based routing** (github.com vs github.enterprise.com): Not all enterprises use custom domains

**Implementation details:**
- Personal script (darwin-45): Full features (git, CLI, GHCR, all package managers), requires dev tag
- Enterprise script (darwin-45a): Full features (git, CLI, GHCR, all package managers), requires work tag
- Git configuration: Personal as global default, enterprise overrides via `includeIf` for `~/work/`
- KeePassXC entries: "GitHub" or "GitHub (Personal)" and "GitHub (Enterprise)" or "GitHub (Work)"
- Package managers: Both accounts support all package managers

**Directory structure:**
```
~/personal/github/         # Personal projects (uses personal GitHub)
  ├── learning/            # Learning projects
  └── oss/                 # Open source contributions
~/work/                    # Work projects (uses enterprise GitHub)
  └── github/              # Work GitHub repos
```

### Decision 9: GitHub Enterprise Domain Support (Scenario B)
**Choice:** Support both github.com (personal) and custom GitHub Enterprise domains (work)

**Rationale:**
- Many organizations use GitHub Enterprise with custom domains
- Personal projects typically use github.com
- Low implementation cost (credential configuration per domain)
- Better user experience (works with enterprise setups)
- Enterprise domain can be configured via `.chezmoi.toml.tmpl`

**Alternatives considered:**
- **github.com only**: Would break for users with GitHub Enterprise
- **Auto-discovery**: Too complex, enterprises use varied domain patterns
- **Multiple domain support per account**: Over-engineered

### Decision 10: Backward Compatibility Strategy
**Choice:** Make tag-based gating check for tags OR KeePassXC availability

**Rationale:**
- Existing users may not have `dev` or `work` tags configured
- Don't want to break existing setups
- If tags are present, use them for gating
- If tags are absent, fall back to KeePassXC availability check (current behavior)
- Clear migration path: users can add tags when ready

**Alternatives considered:**
- **Strict tag requirement**: Would break existing setups (BREAKING CHANGE)
- **No tag gating**: Would miss opportunity to improve configuration
- **Migration script**: Too complex for simple configuration change

## Risks / Trade-offs

### Risk: PAT Expiration
**Impact:** Authentication breaks when PAT expires
**Likelihood:** High (PATs typically expire after 1 year or less)
**Mitigation:**
- Clear error messages when PAT validation fails
- Documentation includes rotation procedure
- Hash-based re-execution makes rotation simple (update KeePassXC, run `chezmoi apply`)
- Consider adding calendar reminder in documentation

### Risk: GitHub Packages Not Widely Used
**Impact:** Package manager configuration may be unnecessary for many users
**Likelihood:** Medium (Docker is common, but language packages less so)
**Mitigation:**
- All package manager feeds are optional (empty string = skip)
- Users only configure what they need
- Zero overhead if not used

### Risk: Directory Discipline Required
**Impact:** Git uses wrong credentials if repos cloned in incorrect directories
**Likelihood:** Medium (users must remember ~/work/ vs ~/personal/github/ convention)
**Mitigation:**
- Clear documentation of directory structure
- Git credential errors will be obvious (authentication failures)
- Can manually specify credentials during clone if needed
- Enterprise account only affects ~/work/, rest of system uses personal account

### Trade-off: Two Environment Variables
**Choice:** Use `GITHUB_TOKEN` and `GITHUB_TOKEN_ENTERPRISE` separately
**Rationale:**
- Prevents credential conflicts
- Tools can use appropriate token for context
- Clear which token is which
**Downside:** Some tools only recognize `GITHUB_TOKEN`, requiring manual configuration for enterprise context

### Trade-off: Tag Gating vs. Backward Compatibility
**Choice:** Optional tag gating (fall back to KeePassXC check if tags absent)
**Rationale:**
- Preserves existing behavior
- Provides upgrade path
- No breaking changes
**Downside:** Less strict control over where scripts run

### Risk: Two PATs to Manage
**Impact:** More credentials to track and rotate
**Likelihood:** High (both PATs will expire)
**Mitigation:**
- Independent rotation per account reduces blast radius
- Both use same KeePassXC-based rotation workflow
- Can choose to only configure accounts you actually use (staged adoption)

### Risk: GitHub Enterprise Domain Variation
**Impact:** Enterprise domain configuration may be complex
**Likelihood:** Low (most enterprises use consistent domain pattern)
**Mitigation:**
- Document common enterprise domain patterns
- Support single enterprise domain per machine
- Users with multiple enterprises can manually configure additional domains

## Migration Plan

### Scenario A: Single Account + Package Managers (Current Setup Enhancement)

**For existing machines (most common - your use case):**
1. **No tags required** (existing KeePassXC check continues to work)
2. Optionally add `dev` tag to `.chezmoi.toml.tmpl` for explicit gating
3. Optionally add GitHub Packages configuration variables:
   - `gh_packages_owner` (e.g., your GitHub username or organization)
   - Package feed names for npm, NuGet, Maven, pip (all optional)
4. Run `chezmoi apply`
5. **Result**: Package managers configured, existing git/GHCR/CLI authentication unchanged
6. **No credential changes**: Same "GitHub" KeePassXC entry, same PAT everywhere

**For new machines (Scenario A):**
1. During `chezmoi init`, provide:
   - GitHub username (existing)
   - Optional: GitHub Packages owner/configuration
2. Create KeePassXC entry "GitHub" with PAT
3. Run `chezmoi apply`
4. **Result**: Full authentication including packages using single account

**Staged adoption (git only, add packages later):**
1. Initial setup with no package configuration
2. Later: Edit `.chezmoi.toml.tmpl` to add package variables
3. Run `chezmoi apply` - packages configured without disrupting git/GHCR/CLI

### Scenario B: Multiple Accounts (Optional/Advanced)

**For new machines (personal + enterprise):**
1. Select `dev` and `work` tags during `chezmoi init`
2. Provide personal GitHub username and optional package configuration
3. Provide enterprise GitHub domain, username, and optional package configuration
4. Create KeePassXC entries:
   - "GitHub" or "GitHub (Personal)" with personal PAT
   - "GitHub (Enterprise)" with enterprise PAT
5. Run `chezmoi apply`
6. Create directory structure:
   - `mkdir -p ~/personal/github` for personal projects
   - `mkdir -p ~/work` for work projects (enterprise credentials)

**For existing machines (adding enterprise account):**
1. Add `work` tag to `.chezmoi.toml.tmpl`
2. Add enterprise GitHub variables:
   - `gh_enterprise_domain`
   - `gh_enterprise_username`
   - Optional package configuration
3. Create KeePassXC entry "GitHub (Enterprise)" with enterprise PAT
4. Run `chezmoi apply`
5. Enterprise script executes, personal account unchanged
6. Move work repositories to `~/work/` to use enterprise credentials

**For existing machines (converting Scenario A → Scenario B):**
1. Already have personal account configured
2. Follow "adding enterprise account" steps above
3. Choose directory organization:
   - Personal projects stay in current location or move to `~/personal/github/`
   - Work projects move to `~/work/`
4. Git will automatically use correct credentials based on directory

**Rollback:**
- **Scenario B → Scenario A**: Remove `work` tag and enterprise variables, run `chezmoi apply`
- **Disable packages**: Remove package variables, run `chezmoi apply`
- **Complete rollback**: Remove all new variables, system reverts to original state

**No data loss:** All configurations are additive. Scenario A users never need Scenario B features.

## Open Questions
None - all design decisions finalized based on gap analysis and Azure DevOps pattern.