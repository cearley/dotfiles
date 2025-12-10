# Command Reference

**Quick reference for daily development commands.**

> **For specifications and requirements**, see [`openspec/specs/`](../openspec/specs/) and [`openspec/project.md`](../openspec/project.md).

---

## Daily Development Commands

### Essential chezmoi Commands
```bash
# Edit a dotfile
chezmoi edit $FILENAME

# Edit and automatically apply changes on save
chezmoi edit --apply $FILENAME

# Edit with live reload (auto-apply on save)
chezmoi edit --watch $FILENAME

# Apply all changes
chezmoi apply

# See what would change without applying
chezmoi diff

# Pull latest changes and apply
chezmoi update

# Pull changes without applying
chezmoi git pull -- --autostash --rebase && chezmoi diff
```

### Template Development & Testing
```bash
# Test template execution
chezmoi execute-template < filename.tmpl

# Debug template scripts
cat {name-of-template-script}.tmpl | chezmoi execute-template
```

### Git Workflow
```bash
# Check status
git status

# View recent commits
git log --oneline -5

# Current branch
git branch --show-current
```

### System Utilities (macOS Darwin)
```bash
# List files
ls -la

# Find files (prefer glob patterns in code)
find . -name "*.tmpl"

# Search content (prefer ripgrep/rg if available)
grep -r "pattern" .

# System information
uname -a

# Machine name (used in templates)
scutil --get ComputerName

# Architecture detection
arch
```

### Package Management
```bash
# Update Homebrew
brew update && brew upgrade

# Install from Brewfile
brew bundle --file ~/.brewfiles/current

# Search packages
brew search <package>

# Show package info
brew info <package>
```

### Development Environment
```bash
# Python environment (uv)
uv --version
uv tool list

# Node environment (nvm)
nvm list
nvm use <version>

# Rust environment
rustup --version
cargo --version

# Java environment (SDKMAN)
sdk list java
sdk current
sdk use java <version>
sdk install java <version>
```
