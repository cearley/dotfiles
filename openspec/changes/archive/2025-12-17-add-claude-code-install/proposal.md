# Change: Claude Code Native Installation

## Why
Developers using Claude Code (Anthropic's AI coding assistant) need a streamlined, native installation method that provides better performance, automatic updates, and eliminates Node.js dependencies. The native installation is Anthropic's recommended approach and offers significant advantages over alternative methods.

**Current gaps:**
- No automated Claude Code installation in the dotfiles system
- Manual setup required for AI development environments
- Missing integration with the existing tag-based package management system

**Benefits of native installation:**
- One self-contained executable with no external dependencies
- No Node.js runtime requirement
- Improved auto-updater stability
- Faster startup and better performance
- Native binary signed by Anthropic and notarized (macOS)
- Consistent installation experience across macOS, Linux, and WSL

**Target users:**
- Developers using the `ai` tag for AI/ML development tools
- Users who want Claude Code for AI-assisted coding
- Teams standardizing on Claude Code for development workflows

## What Changes

### Core Enhancement
- **Installation script**: `run_once_after_darwin-36-install-claude-code.sh.tmpl`
  - Native install using: `curl -fsSL https://claude.ai/install.sh | bash`
  - Gated by `ai` tag (consistent with other AI tools like Claude Desktop, Ollama)
  - macOS, Linux, and WSL support (platform conditional logic)
  - Script order 36: After nvm (35), before shell plugins/auth (40+)
  - Idempotent: Safe to re-run, skips if already installed
  - Installation verification using `claude --version`
  - Uses shared utilities for consistent messaging

### Installation Details
- **Binary location**: `~/.local/bin/claude` (Unix/Linux/WSL)
- **Installation directory**: `~/.claude-code/` (config and state)
- **Auto-updates**: Enabled by default (can be disabled via `DISABLE_AUTOUPDATER=1`)
- **Authentication**: Handled post-install via `claude` CLI (supports Claude Console, Pro/Max plans, enterprise platforms)

### Platform Support
- **macOS**: Native ARM64 and x64 binaries, signed and notarized by Anthropic
- **Linux**: Ubuntu 20.04+, Debian 10+, and compatible distributions
- **WSL**: Both WSL 1 and WSL 2 supported
- Platform detection using `.chezmoi.os` and `.chezmoi.arch`

### Integration
- Follows existing script patterns from the dotfiles system
- Uses shared utilities (`scripts/shared-utils.sh`)
- Consistent with other development tool installations (nvm, rustup, etc.)
- Tag-based gating aligns with AI package category (`packages.yaml` ai section)

### Documentation
- Installation verification steps
- Quick reference for `claude` CLI commands
- Authentication setup guidance
- Update and maintenance procedures

## Impact
- **Affected specs**: `package-management` (added Claude Code native installation to development toolchain)
- **Affected code**:
  - `home/.chezmoiscripts/run_once_after_darwin-36-install-claude-code.sh.tmpl` (create - native install script)
  - `docs/command-reference.md` (modify - add Claude Code commands and usage)
  - `.serena/memories/chezmoi-dotfiles-quick-reference.md` (modify - add Claude Code reference)
- **Dependencies**: 
  - curl (already available in core packages)
  - bash (system default)
  - No Node.js required (advantage of native install)
  - `ai` tag selection during chezmoi initialization
- **Breaking changes**: None (purely additive, no impact on existing installations)
- **Platform support**: macOS (primary), Linux/WSL (supported via same install script with conditional logic)
