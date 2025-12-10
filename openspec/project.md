# Project Context

## Purpose
This is a personal dotfiles repository managed by chezmoi, designed to bootstrap and maintain macOS development environments. The repository enables:

- **Complete environment automation**: One-command setup of a fully configured development machine
- **Multi-machine support**: Conditional configurations for different Mac models (MacBook Pro, Mac Studio, Mac mini)
- **Secure secret management**: KeePassXC integration eliminates hardcoded credentials
- **Tag-based customization**: Flexible installation profiles (core, dev, ai, work, personal, datascience, mobile)
- **Cross-machine consistency**: Synchronized configurations across multiple machines
- **System-level management**: Manages both user dotfiles and system configurations (/etc/hosts, etc.)

## Tech Stack

### Core Technologies
- **Configuration Management**: chezmoi (dotfiles management and templating)
- **Package Management**: Homebrew (primary), SDKMAN (Java/JVM), uv (Python), nvm (Node.js)
- **Shell Environment**: zsh with Powerlevel10k theme
- **Template Engine**: Go templates (chezmoi's built-in templating system)
- **Secret Management**: KeePassXC integration via chezmoi functions
- **Version Control**: Git with GitHub integration

### Development Languages & Runtimes
- **Shell Scripting**: Bash (with shared utility functions in `scripts/shared-utils.sh`)
- **Python**: uv package manager, conda/Miniforge environment manager
- **Node.js**: nvm (Node Version Manager)
- **Rust**: rustup toolchain with cargo
- **Java/JVM**: SDKMAN for JDK, Gradle, Maven, and other JVM tools
- **Go**: Standard Go toolchain
- **Ruby**: frum version manager
- **.NET**: Multiple SDK versions (3.1, 6.0, 8.0) via Homebrew casks

### Key Dependencies & Tools
- **CLI Essentials**: bat, gh, jq, mas, rclone, speedtest-cli, tree, fzf, zoxide, atuin, lsd, neovim
- **Development Tools**: git-delta, direnv, act, docker-desktop, localstack, dagger
- **Cloud SDKs**: AWS CLI, AWS SAM CLI, Azure CLI
- **Security**: Microsoft Defender, Lulu, KeePassXC, Syncthing
- **macOS Apps**: iTerm2, Visual Studio Code, Claude Desktop, Jetbrains Toolbox
- **AI/ML Tools**: Ollama, LM Studio, Continue IDE extension

### Architecture Support
- **Primary**: ARM64 (Apple Silicon M1/M2/M3/M4)
- **Secondary**: x64 (Intel Macs)
- Uses `.chezmoi.arch` for consistent cross-platform architecture detection

## Project Conventions

### Code Style

#### File Naming (chezmoi-specific)
- **`private_` prefix**: Sensitive or machine-specific files (not shared publicly)
- **`.tmpl` suffix**: Template files processed by chezmoi's Go template engine
- **`dot_` prefix**: Creates dotfiles (hidden files starting with `.`)
- **`executable_` prefix**: Creates executable files (chmod +x)
- **`symlink_` prefix**: Creates symbolic links

#### Script Naming Pattern
Scripts in `home/.chezmoiscripts/` use structured naming:
```
{frequency}_{timing}_{os}-{order}-{description}.sh.tmpl
```

**Components:**
- **Frequency**: `run_once_` (init tasks) or `run_onchange_` (maintenance tasks)
- **Timing**: `before` or `after` (relative to dotfile application)
- **OS**: `darwin` (macOS-specific)
- **Order**: 5-point spacing for logical grouping (05, 10, 15, 20, etc.)
- **Description**: Kebab-case description of task

**Execution Order Categories:**
- **00-09**: System Foundation (Rosetta 2)
- **10-19**: Development Toolchains (Rust, Java/JVM)
- **20-29**: Package Management (SDKMAN, Homebrew bundles, SDKs, UV tools)
- **30-39**: Environment Managers (uv, nvm)
- **40-49**: Environment Setup (GitHub auth, shell plugins)
- **80-99**: System Configuration (security, VPN, authentication services, defaults, validation)

#### Shell Script Conventions
- **Shared utilities**: All scripts source `scripts/shared-utils.sh` for common functions
- **Consistent messaging**: Use `print_message()` with intuitive emoji icons:
  - `🔵 info` - Helpful information
  - `✅ success` - Completed actions
  - `⚠️ warning` - Caution messages
  - `❌ error` - Failures
  - `⏭️ skip` - Skipped operations
  - `💡 tip` - Tips and suggestions
- **Platform wrapping**: All darwin scripts wrapped in `{{- if eq .chezmoi.os "darwin" -}}` conditionals
- **Error handling**: Proper exit codes, cleanup functions, meaningful error messages
- **Stderr output**: Utility functions output to stderr to avoid interfering with return values

#### Template Conventions
- **Architecture detection**: Use `.chezmoi.arch` instead of custom shell commands
- **Command validation**: Use `lookPath "commandname"` (NOT `output "command" "-v"`)
- **Variable expansion**: Single quotes in arrays to prevent premature expansion
- **Dot-notation**: Support for nested YAML properties (e.g., `keepassxc_entries.ssh`)

### Architecture Patterns

#### Custom Source Directory Structure
Uses non-standard chezmoi layout with `home/` as root (defined in `.chezmoiroot`):
```
.local/share/chezmoi/
├── home/                           # Root for all managed files
│   ├── .chezmoidata/              # Static data files (YAML/JSON/TOML)
│   ├── .chezmoitemplates/         # Reusable template snippets
│   ├── .chezmoiscripts/           # Automated setup scripts
│   ├── .chezmoiexternal.toml.tmpl # External dependency definitions
│   ├── .chezmoi.toml.tmpl         # User configuration prompts
│   └── [dotfiles with chezmoi prefixes]
├── scripts/                        # Shared utility scripts
│   └── shared-utils.sh            # Common functions for all scripts
├── hooks/                          # Pre/post operation hooks
├── brewfiles/                      # Machine-specific Homebrew bundles
└── remote_install.sh              # One-command bootstrap script
```

**Important**: Files in `.chezmoidata/` cannot be templates - they must be static files that exist before the template engine runs.

#### Machine Configuration System
Centralized, extensible machine-specific settings:

**Components:**
1. **`machines.yaml`**: Machine-specific settings with pattern-based substring matching
2. **`computer-name` template**: Cross-platform machine name detection (macOS/Linux/Windows)
3. **`machine-config` template**: Generic lookup supporting any setting or returning matched key
4. **Convenience wrappers**: `machine-brewfile-path`, `machine-key-name`, `machine-keepassxc-entry`

**Template Composition:**
- Templates can include other templates via `includeTemplate`
- DRY principle: shared logic in reusable components
- Clean separation: detection → lookup → path construction

**Adding New Properties:**
Simply add to `machines.yaml` - no template changes needed:
```yaml
MacBook Pro:
  brewfile: mbp-brewfile
  keepassxc_entries:
    ssh: SSH (MacBook Pro)
  # New properties work automatically:
  # ssh_key_id: macbook_ed25519
  # hostname_prefix: mbp
```

#### Package Management Strategy
Three-layer approach:
1. **Homebrew packages** (`packages.yaml`): Tag-based categories for system packages, apps, and CLI tools
2. **UV tools** (`tools.yaml`): Tag-based Python CLI tools and utilities
3. **SDKMAN SDKs** (`sdks.yaml`): JVM ecosystem SDKs and build tools (requires `dev` tag)
4. **Machine-specific Brewfiles**: Additional Homebrew packages requiring user confirmation

Tags control installation scope:
- `core`: Always installed
- `dev`: Development tools
- `ai`: AI/ML tools
- `work`: Enterprise tools
- `personal`: Personal productivity
- `datascience`: R, RStudio, data tools
- `mobile`: VPN, network analysis

#### Secret Management Architecture
- **No hardcoded secrets**: All credentials via KeePassXC integration
- **Template-time injection**: `keepassxcAttribute` function retrieves secrets during apply
- **Machine-specific entries**: `machine-keepassxc-entry` template maps logical names to actual entries
- **Graceful degradation**: Scripts skip if KeePassXC unavailable

#### External Dependencies
Managed via `.chezmoiexternal.toml.tmpl`:
- Oh My Zsh and plugins (zsh-autosuggestions, zsh-syntax-highlighting)
- Archive downloads with checksum verification
- Git repository clones
- Automatic updates on hash/version changes

### Testing Strategy

#### Template Testing
```bash
# Test template execution
chezmoi execute-template < filename.tmpl

# Debug template scripts
cat script-name.tmpl | chezmoi execute-template
```

#### Script Validation
- **Pre-flight checks**: `require_tools()` validates dependencies before execution
- **Dry-run support**: Many scripts support testing without applying changes
- **Idempotency**: All scripts are safe to re-run (check before installing)
- **Graceful failures**: Scripts continue on non-critical errors, skip completed tasks

#### System Validation Scripts
- **SSH connectivity**: `run_onchange_after_darwin-97-test-ssh-github.sh.tmpl` validates GitHub access
- **Re-run triggers**: Hash-based change detection (`run_onchange_*`) re-validates on key changes

### Git Workflow

#### Branching Strategy
- **Main branch**: `main` (primary development and deployment)
- **Feature branches**: Short-lived for specific changes
- **No protection**: Personal repository with single maintainer

#### Commit Conventions
- **Two-gate approval**: Separate explicit consent required for commit and push
- **Descriptive messages**: Focus on "why" rather than "what"
- **Emoji suffix**: All commits include collaboration marker:
  ```
  🤖 Generated with Claude Code

  Co-Authored-By: Claude <noreply@anthropic.com>
  ```

#### Workflow Example
1. Make code changes locally
2. Request commit permission from user
3. Wait for explicit "yes" confirmation
4. Execute `git commit`
5. Request push permission from user
6. Wait for explicit "yes, push it" confirmation
7. Execute `git push`

## Domain Context

### chezmoi Concepts
- **Source directory**: Where templates and scripts live (`~/.local/share/chezmoi`)
- **Target directory**: Where files are applied (usually `~`)
- **State**: chezmoi tracks applied state in `~/.local/share/chezmoi/.chezmoistate.boltdb`
- **Templates**: Go template syntax with chezmoi-specific functions
- **Attributes**: File prefixes control how chezmoi processes files

### Platform-Specific Knowledge
- **macOS architecture**: Distinction between Intel (x64) and Apple Silicon (arm64)
- **Rosetta 2**: Required for x86_64 compatibility on Apple Silicon
- **System Integrity Protection (SIP)**: Restricts system-level modifications
- **macOS defaults**: `defaults` command for application preferences
- **Homebrew architecture**: Universal binaries, arch-specific builds, cask vs formula

### Tag-Based Execution
User selects tags during initial setup via `chezmoi init`. Tags control:
- Which packages are installed
- Which scripts execute
- Which configuration snippets are included
- Which external dependencies are fetched

Common tag combinations:
- Minimal: `core`
- Developer: `core,dev,ai`
- Work machine: `core,dev,work`
- Personal machine: `core,dev,ai,personal,datascience`

## Important Constraints

### Platform Requirements
- **Target OS**: macOS 11.0+ (Big Sur or later)
- **Architecture**: ARM64 (Apple Silicon) or x64 (Intel)
- **Required pre-installed**: Xcode Command Line Tools
- **Bootstrap dependencies**: KeePassXC (for secrets), Homebrew (for packages)

### Security Constraints
- **No secrets in repository**: All credentials via KeePassXC or environment variables
- **Private files**: Sensitive files prefixed with `private_` and excluded from sharing
- **Local-only state**: Machine-specific state not tracked in git
- **Secure by default**: Lulu firewall, Microsoft Defender configured during setup

### Performance Constraints
- **Template efficiency**: Avoid reading entire files unnecessarily
- **Script execution time**: Long-running scripts show progress indicators
- **Parallel execution**: Independent operations can run concurrently
- **Network dependencies**: Scripts validate connectivity before downloads

### Maintenance Constraints
- **Single maintainer**: Personal project without external contributors
- **Self-documenting**: Code includes inline documentation and help text
- **Backward compatibility**: Existing machines should apply updates safely
- **Idempotency**: All operations safe to re-run without side effects

## External Dependencies

### Essential Services
- **GitHub**: Repository hosting, authentication, SSH key management
- **KeePassXC**: Secret storage and retrieval (required for bootstrap)
- **Homebrew**: Primary package manager (installed via hook if missing)

### Optional Services
- **Syncthing**: File synchronization across machines
- **ChronoSync**: Backup and file management
- **Dropbox**: Cloud storage integration
- **Google Drive**: Cloud storage integration
- **Box Drive**: Enterprise cloud storage (work tag)
- **OneDrive**: Microsoft cloud storage (work tag)
- **Global Protect VPN**: Palo Alto Networks VPN client (work tag)

### Cloud Providers
- **AWS**: CLI tools, SAM CLI, credential management
- **Azure**: CLI tools, SDK integration (dev/work tags)
- **Docker Hub**: Container registry access
- **GitHub Container Registry (GHCR)**: Package hosting

### AI/ML Services
- **Claude Desktop**: Anthropic's AI assistant application
- **Ollama**: Local LLM hosting and inference
- **LM Studio**: Local LLM management and experimentation
- **Continue**: AI coding assistant IDE extension with multi-provider support
- **Atuin**: Encrypted shell history synchronization service

### Package Repositories
- **Homebrew formulae**: Core package definitions
- **Homebrew casks**: macOS application installations
- **Mac App Store**: App installations via `mas` CLI
- **SDKMAN**: JVM ecosystem (Java, Gradle, Maven, Kotlin, Scala)
- **Rust crates.io**: Rust package ecosystem
- **npm registry**: Node.js packages (via nvm)
- **PyPI**: Python packages (via uv)
