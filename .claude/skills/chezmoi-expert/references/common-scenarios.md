# Common Chezmoi Scenarios

## Adding VS Code Settings

```bash
# macOS/Linux
chezmoi add ~/.config/Code/User/settings.json

# For machine-specific settings:
chezmoi forget ~/.config/Code/User/settings.json
chezmoi add --template ~/.config/Code/User/settings.json
chezmoi edit ~/.config/Code/User/settings.json
```

Template example:
```json
{
    "editor.fontSize": {{ if eq .chezmoi.hostname "work-laptop" }}14{{ else }}16{{ end }},
    "window.zoomLevel": {{ .vscode.zoomLevel | default 0 }}
}
```

## Syncing SSH Config (Not Keys!)

```bash
chezmoi add --private ~/.ssh/config

# Ignore private keys
chezmoi cd
echo ".ssh/id_*" >> .chezmoiignore
echo ".ssh/*.pem" >> .chezmoiignore

# Verify
chezmoi managed | grep "\.ssh"
```

## Different Git Configs for Work vs Personal

1. Set up machine data in `.chezmoi.toml.tmpl`:
```toml
[data]
    email = {{ promptStringOnce . "email" "Git email address" }}
    work = {{ promptBoolOnce . "work" "Is this a work machine" }}
```

2. Convert to template:
```bash
chezmoi forget ~/.gitconfig
chezmoi add --template ~/.gitconfig
```

3. Edit template:
```
[user]
    name = {{ .name }}
    email = {{ .email }}
{{ if .work }}
[http]
    proxy = http://corporate-proxy:8080
{{ end }}
```

## Installing Packages via Brewfile

Create `Brewfile.tmpl` and `run_onchange_install-packages.sh.tmpl`:

```bash
# run_onchange_install-packages.sh.tmpl
{{- if eq .chezmoi.os "darwin" }}
#!/bin/bash
{{ if lookPath "brew" }}
brew bundle install --global --no-lock
{{ else }}
echo "Homebrew not found, skipping"
{{ end }}
{{- end }}
```

Force re-install:
```bash
chezmoi state delete --bucket=entryState --key="$(chezmoi source-path)/run_onchange_install-packages.sh.tmpl"
chezmoi apply -v
```

## Setting Up a New Machine

```bash
# Install chezmoi
brew install chezmoi
# Or: sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin

# Set up SSH keys first (for private repos)
ssh-keygen -t ed25519 -C "email@example.com"
# Add to GitHub

# Initialize (full SSH URL, not short form)
chezmoi init git@github.com:user/dotfiles.git

# Review and apply
chezmoi diff
chezmoi apply -v
```

## Testing Config Changes Safely

```bash
chezmoi edit ~/.zshrc           # Make changes
chezmoi diff ~/.zshrc           # Preview
chezmoi apply ~/.zshrc          # Apply
zsh                             # Test in new shell
exit
```

If broken:
```bash
chezmoi cd
git checkout HEAD -- dot_zshrc
exit
chezmoi apply --force ~/.zshrc
```

## Migrating Existing Dotfiles to Chezmoi

```bash
chezmoi init
chezmoi add ~/.zshrc
chezmoi add ~/.gitconfig
chezmoi add --recursive ~/.config/nvim
chezmoi diff && chezmoi verify

chezmoi cd
git init && git add .
git commit -m "Initial dotfiles commit"
gh repo create dotfiles --private --source=. --remote=origin
git push -u origin main
exit
```

## Excluding Files from Management

```bash
chezmoi forget ~/.zsh_history

chezmoi cd
echo ".zsh_history" >> .chezmoiignore
echo ".zsh_sessions/" >> .chezmoiignore
git add .chezmoiignore && git commit -m "Ignore zsh history"
exit
```

## Debugging Template Errors

```bash
chezmoi apply -v                # See which template fails
chezmoi data                    # Check available variables
chezmoi execute-template < path/to/template.tmpl
chezmoi cat ~/.gitconfig        # View rendered output
```

Common fixes:
- Missing variable: add `| default "fallback"` 
- Wrong syntax: `{{ if .work }}` not `{{ if .work = true }}`
