# Templates and Workflows

## Template System

Chezmoi uses Go template syntax. Templates are files with `.tmpl` suffix.

### Template Data Sources

1. `.chezmoi.toml` in source directory (custom data)
2. `.chezmoi.toml.tmpl` in repo root (prompted data via `promptBoolOnce`, etc.)
3. Built-in variables: `.chezmoi.os`, `.chezmoi.arch`, `.chezmoi.hostname`, `.chezmoi.username`, `.chezmoi.homeDir`
4. Command output using `output` function

### Example .chezmoi.toml

```toml
[data]
    email = "derek@personal.com"
    personal_device = true
```

### Using promptBoolOnce for Per-Machine Data

For values that differ per machine, use `promptBoolOnce` in `.chezmoi.toml.tmpl` at repo root. This prompts during `chezmoi init` and stores the answer in `~/.config/chezmoi/chezmoi.toml`:

```toml
# .chezmoi.toml.tmpl (in repo root)
[data]
    personal_device = {{ promptBoolOnce . "personal_device" "Is this a personal device" }}
```

### Template Examples

**Conditional config (dot_gitconfig.tmpl):**
```
[user]
    name = Derek
    email = {{ .email }}

{{ if .personal_device }}
[github]
    user = personal-username
{{ end }}
```

**OS-specific content:**
```
{{ if eq .chezmoi.os "darwin" }}
# macOS-specific settings
{{ end }}

{{ if eq .chezmoi.os "linux" }}
# Linux-specific settings
{{ end }}
```

**External commands in templates:**
```
{{ (output "brew" "--prefix") | trim }}/bin/something

{{ if lookPath "docker" }}
# Docker-specific config
{{ end }}
```

**Default values:**
```
email = {{ .work_email | default "personal@gmail.com" }}
```

### .chezmoiignore

Exclude files from management on certain machines:

```
{{ if .personal_device }}
.ssh/work_config
{{ end }}

{{ if eq .chezmoi.os "windows" }}
.bashrc
{{ end }}
```

**Important:** `.chezmoiignore` only works for regular files (matches target paths). It does NOT work for scripts. Use template guards for scripts.

## Brewfile Management

The user typically has a `Brewfile.tmpl` that manages Homebrew packages.

### Best practices for Brewfile updates

1. Get package info first: `brew info --json <package-name>`
2. Use official descriptions as comments
3. Place packages in appropriate sections (core tools, CLI utils, GUI apps, personal-only)
4. Personal-only packages use `{{ if .personal_device }}`
5. If unsure whether a package should be personal-only, ASK THE USER

### Example Brewfile sections

```
# Development tools
brew "ripgrep"  # Fast grep alternative with smart defaults

{{ if .personal_device }}
# Personal packages
brew "ollama"  # Create, run, and share LLMs
{{ end }}

# GUI applications
cask "iterm2"  # macOS terminal replacement
```

## Daily Workflow

### On Machine A (make changes)

```bash
chezmoi edit ~/.zshrc          # Edit through chezmoi
chezmoi diff                    # Review changes
chezmoi apply                   # Apply locally
chezmoi cd                      # Enter source dir
git add . && git commit -m "Update zsh aliases"
git push
exit
```

### On Machine B (pull changes)

```bash
chezmoi update                  # Pull and apply in one command
# Or manually:
chezmoi cd && git pull && exit
chezmoi diff                    # Review
chezmoi apply                   # Apply
```

### Adding a New Dotfile

```bash
ls -la ~/.newconfig             # Verify file exists
chezmoi add ~/.newconfig        # Add to management
chezmoi cd
git add . && git commit -m "Add newconfig"
git push && exit
```

### Converting to Template

```bash
chezmoi forget ~/.gitconfig
chezmoi add --template ~/.gitconfig
chezmoi edit ~/.gitconfig       # Add template variables
chezmoi apply ~/.gitconfig      # Test rendering
```

## Setting Up a New Machine

```bash
# 1. Install chezmoi
brew install chezmoi

# 2. Initialize (use full SSH URL for SSH agent forwarding)
chezmoi init git@github.com:user/dotfiles.git

# 3. Review and apply
chezmoi diff
chezmoi apply

# promptBoolOnce vars will prompt on first run
# run_onchange scripts will execute automatically
```

## Diff Tools

Configure custom diff tool in `.chezmoi.toml`:

```toml
[diff]
    command = "delta"
```

## Lazygit Config Location

On macOS, lazygit defaults to `~/Library/Application Support/lazygit/config.yml`. The XDG path `~/.config/lazygit/config.yml` works cross-platform but on macOS requires setting `LG_CONFIG_FILE`. On Linux, lazygit uses XDG natively.
