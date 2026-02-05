---
name: new-script
description: Create a new chezmoi setup script following all project conventions
argument-hint: "<description> [--frequency run_once|run_onchange] [--timing before|after] [--order NN]"
disable-model-invocation: true
allowed-tools: Read, Write, Bash, Glob, Grep
---

# Create New Chezmoi Script

Create a new script in `home/.chezmoiscripts/` following all project conventions.

## Arguments

Parse from $ARGUMENTS:
- **description** (required): Kebab-case description (e.g., "install-docker", "setup-github-auth")
- **--frequency**: `run_once` (default) or `run_onchange`
- **--timing**: `before` (default) or `after`
- **--order**: Two-digit number (suggest one if not provided)

## Naming Convention

```
{frequency}_{timing}_darwin-{order}-{description}.sh.tmpl
```

## Order Categories

- **00-09**: System Foundation (Rosetta 2)
- **10-19**: Development Toolchains (Rust, Java/JVM)
- **20-29**: Package Management (SDKMAN, Homebrew, SDKs, UV tools)
- **30-39**: Environment Managers (uv, nvm, Claude Code)
- **40-49**: Environment Setup (GitHub auth, shell plugins)
- **80-89**: System Configuration (security, VPN, Defender, GlobalProtect)
- **90-99**: Validation & Maintenance (hosts, syncthing, SSH test, system defaults)

If --order is not provided, suggest an appropriate number based on the description and these existing scripts:

!`ls home/.chezmoiscripts/`

## Required Boilerplate

Every script MUST use this structure:

```bash
{{- if eq .chezmoi.os "darwin" -}}
#!/bin/bash
source "{{ .chezmoi.sourceDir -}}/scripts/shared-utils.sh"

# Script logic here

{{ end -}}
```

## Conventions

- Use `print_message "level" "message"` for ALL output (info, success, warning, error, skip, tip)
- Use `command_exists "cmd"` to check command availability
- Use `require_tools "tool1" "tool2"` to validate dependencies at the start
- Use `lookPath` in template conditionals (NEVER `output "command" "-v"`)
- Handle already-installed/configured cases with `print_message "skip"`
- Include proper error handling with meaningful messages

## Steps

1. Parse arguments or ask for missing info (description, frequency, timing, order)
2. Verify the order number doesn't conflict with existing scripts
3. Generate the filename following the naming convention
4. Create the script with all required boilerplate
5. Implement the script logic based on the description
6. Validate the template: `chezmoi execute-template < <file>`
