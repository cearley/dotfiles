# Code Style Quick Reference

> **For complete coding standards and conventions**, see:
> - [`openspec/project.md`](../../openspec/project.md) - Section "Project Conventions"
> - Subsections: Code Style, Architecture Patterns, Testing Strategy

---

## Practical Examples

### Sourcing Shared Utilities

All scripts should source shared utilities for consistent messaging:
```bash
source "{{ .chezmoi.sourceDir -}}/scripts/shared-utils.sh"
```

### Using Message Functions

```bash
# Informational message
print_message "info" "Installing package..."

# Success message
print_message "success" "Installation complete"

# Warning message
print_message "warning" "Package already installed"

# Error message
print_message "error" "Installation failed"

# Skip message
print_message "skip" "Skipping optional feature"

# Tip message
print_message "tip" "Use --verbose for more details"
```

### Platform-Specific Scripts

Darwin (macOS) scripts must use conditional templates:
```go-template
{{- if eq .chezmoi.os "darwin" -}}
#!/bin/bash

source "{{ .chezmoi.sourceDir -}}/scripts/shared-utils.sh"

# Your script logic here
print_message "info" "Running on macOS"

{{ end -}}
```

### Architecture Detection

Always use `.chezmoi.arch` for consistent detection:
```go-template
{{- if and (eq .chezmoi.os "darwin") (eq .chezmoi.arch "arm64") -}}
# Apple Silicon specific logic
{{- else if and (eq .chezmoi.os "darwin") (eq .chezmoi.arch "amd64") -}}
# Intel Mac specific logic
{{- end }}
```

### Command Validation in Templates

**Correct approach** - Use `lookPath`:
```go-template
{{- if and (has "dev" .tags) (lookPath "rustup") }}
source "$HOME/.cargo/env"
{{- end }}
```

**Never use** - This will cause template failures:
```go-template
{{- /* WRONG - Don't do this! */ -}}
{{- if output "command" "-v" "rustup" }}
```

### Checking Prerequisites in Scripts

```bash
# Validate required tools before proceeding
require_tools "git" "curl" "brew"

# Check if a specific command exists
if command_exists "docker"; then
    print_message "success" "Docker is installed"
else
    print_message "skip" "Docker not found, skipping Docker setup"
fi
```

### Directory and File Operations

```bash
# Ensure directory exists
ensure_directory "$HOME/.config/myapp"

# Ensure directory with sudo
ensure_directory "/usr/local/etc" "sudo"

# Download file with progress
download_file "https://example.com/file.tar.gz" "/tmp/file.tar.gz"

# Cleanup temporary directory
trap 'cleanup_temp_dir "$temp_dir"' EXIT
temp_dir=$(mktemp -d)
```

### Waiting for Application Installation

```bash
# Wait for app with timeout and cancellation support
wait_for_app_installation "/Applications/Docker.app" "Docker Desktop"
```

### User Prompts

```bash
# Default prompt
prompt_ready

# Custom message
prompt_ready "Press any key when app installation is complete..."
```

---

## Common Patterns

### Script Template Structure

```bash
{{- if eq .chezmoi.os "darwin" -}}
#!/bin/bash
set -euo pipefail

# Source shared utilities
source "{{ .chezmoi.sourceDir -}}/scripts/shared-utils.sh"

# Print info message
print_message "info" "Starting script execution"

# Check prerequisites
require_tools "git" "brew"

# Main logic
if command_exists "myapp"; then
    print_message "skip" "myapp already installed"
    exit 0
fi

print_message "info" "Installing myapp..."
brew install myapp

# Verify installation
if command_exists "myapp"; then
    print_message "success" "myapp installed successfully"
else
    print_message "error" "myapp installation failed"
    exit 1
fi

{{ end -}}
```

### Tag-Based Conditional Logic

```go-template
{{- if has "dev" .tags }}
# Development tools configuration
{{- end }}

{{- if has "work" .tags }}
# Work-specific setup
{{- end }}

{{- if and (has "dev" .tags) (has "ai" .tags) }}
# AI development tools
{{- end }}
```

---

## Memory Note

This is a practical quick reference for applying coding conventions. For the complete, authoritative standards, rationale, and patterns, see [`openspec/project.md`](../../openspec/project.md).
