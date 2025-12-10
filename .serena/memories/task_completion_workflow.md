# Task Completion Workflow

## Post-Development Actions

When completing any development task in this repository, follow these steps:

### 1. Template Testing (if applicable)
```bash
# Test template execution for modified templates
chezmoi execute-template < filename.tmpl

# Test template scripts
cat {script-name}.tmpl | chezmoi execute-template
```

### 2. Apply Changes
```bash
# Apply specific changes
chezmoi apply [specific-file]

# Or apply all changes
chezmoi apply
```

### 3. Validation
```bash
# Check what would change (dry run)
chezmoi diff

# Verify no syntax errors in shell scripts
bash -n ~/path/to/script.sh
```

### 4. Testing Specific Components

#### Shell Scripts (if modified)
```bash
# Source and test shared utilities
source "$(chezmoi source-path)/scripts/shared-utils.sh"

# Test specific functions
print_message "info" "Test message"
command_exists "chezmoi"
```

### 5. System Integration Testing

#### Package Management
```bash
# Verify Homebrew packages
brew bundle check --file ~/.brewfiles/current

# Update if needed
brew bundle --file ~/.brewfiles/current
```

#### Environment Validation
```bash
# Check development environments
rustup --version      # Rust
nvm list             # Node.js
sdk list java        # Java (SDKMAN)
sdk current          # Current SDK versions
uv --version         # Python
```

### 6. Git Workflow
```bash
# Stage changes
git add .

# Commit with descriptive message
git commit -m "descriptive message

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>"

# Push changes (if ready)
git push
```

## Important Notes

### No Linting/Formatting Commands
This repository does not have traditional linting or formatting commands since it's primarily configuration files and shell scripts managed by chezmoi templates.

### Validation Methods
- **Templates**: Use `chezmoi execute-template`
- **Shell Scripts**: Use `bash -n` for syntax checking
- **Configuration**: Use `chezmoi diff` to preview changes

### Prerequisites for Success
- KeePassXC database must be accessible for credential-dependent templates
- Required tools must be installed for script execution (checked via shared utilities)
- Machine tags must be properly configured for tag-dependent installations

### Recovery Actions
If something goes wrong:
```bash
# Revert to last known good state
chezmoi git reset --hard HEAD~1

# Or pull from remote
chezmoi update

# Check system state
chezmoi doctor
```