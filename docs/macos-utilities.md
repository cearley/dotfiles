# macOS System Utilities and Commands

**Reference guide for macOS (Darwin) system utilities and commands.**

> **For specifications and requirements**, see [`openspec/specs/`](../openspec/specs/) and [`openspec/project.md`](../openspec/project.md).

---

## Core System Commands (Darwin-specific)

### System Information
```bash
# System version and kernel
uname -a

# Machine architecture
arch

# Computer name (used in templates)
scutil --get ComputerName

# Hardware information
system_profiler SPHardwareDataType

# Disk usage
df -h
```

### File Operations
```bash
# List files (with hidden files)
ls -la

# Copy with extended attributes (macOS)
cp -R source destination

# Move files
mv source destination

# Create directories
mkdir -p path/to/directory

# Change permissions
chmod +x filename
```

### Process Management
```bash
# List processes
ps aux

# Find processes
pgrep process_name

# Kill processes
killall process_name

# System activity monitor
top
```

### Network Operations
```bash
# Network configuration
ifconfig

# DNS lookup
nslookup domain.com

# Network connectivity
ping hostname

# Port scanning
nc -zv hostname port
```

### Package Management (Homebrew)
```bash
# Update package lists
brew update

# Upgrade packages
brew upgrade

# Install package
brew install package_name

# Install cask (GUI app)
brew install --cask app_name

# Search packages
brew search term

# Package information
brew info package_name

# List installed packages
brew list

# Bundle from Brewfile
brew bundle --file path/to/Brewfile
```

### Text Processing
```bash
# Search files (prefer rg/ripgrep if available)
grep -r "pattern" directory

# Find files
find . -name "*.ext" -type f

# Text manipulation
sed 's/old/new/g' file

# Sort and unique
sort file | uniq

# Word count
wc -l file
```

### Archive Operations
```bash
# Create tar archive
tar -czf archive.tar.gz directory/

# Extract tar archive
tar -xzf archive.tar.gz

# Create zip
zip -r archive.zip directory/

# Extract zip
unzip archive.zip
```

## macOS-Specific Tools

### System Preferences
```bash
# System defaults (used in chezmoi scripts)
defaults write domain key value
defaults read domain key
```

### App Store
```bash
# Mac App Store CLI (mas)
mas search "app name"
mas install app_id
mas list
```

### Service Management
```bash
# Launch services
launchctl list
launchctl start service_name
launchctl stop service_name
```

### Security
```bash
# Keychain access
security find-generic-password -s service_name
security add-generic-password -s service_name -a account

# Code signing
codesign -v application.app
```

## Directory Navigation
```bash
# Change directory
cd path/to/directory

# Go to home
cd ~

# Go to previous directory
cd -

# Print working directory
pwd

# Directory stack
pushd directory
popd
```

## File Viewing and Editing
```bash
# View file contents
cat filename
less filename
head -n 10 filename
tail -n 10 filename

# Edit files
nano filename    # Simple editor
vim filename     # Vi editor
code filename    # VS Code (if installed)
```

## Important Notes

### Darwin vs Linux Differences
- Some GNU tools behave differently on macOS (BSD variants)
- Use Homebrew to install GNU versions if needed (e.g., `gnu-sed`)
- File paths and permissions may differ
- Extended attributes are macOS-specific

### Recommended Replacements
- Use `bat` instead of `cat` for syntax highlighting
- Use `rg` (ripgrep) instead of `grep` for better performance
- Use `fd` instead of `find` for faster file searching
- Use `zoxide` instead of `cd` for smart directory jumping

### Security Considerations
- macOS Gatekeeper may block unsigned executables
- SIP (System Integrity Protection) prevents modification of system files
- Use `sudo` carefully, prefer user-space solutions when possible
