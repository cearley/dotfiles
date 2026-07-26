# Chezmoi Command Reference

## Setup & Initialization

**Initialize from repository:**
```bash
# HTTPS (default for short username form)
chezmoi init https://github.com/user/dotfiles.git

# SSH (required for SSH agent forwarding)
# NOTE: `chezmoi init username` defaults to HTTPS. Use full URL for SSH:
chezmoi init git@github.com:user/dotfiles.git
```

**Initialize and apply in one command:**
```bash
chezmoi init --apply git@github.com:user/dotfiles.git
```

**One-liner for new machines (install + init + apply):**
```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin init --apply git@github.com:user/dotfiles.git
```

## Viewing Changes

**See what would change (ALWAYS do this before apply!):**
```bash
chezmoi diff
```

**Check status of managed files:**
```bash
chezmoi status
```

**List all managed files:**
```bash
chezmoi managed
chezmoi managed --include=files --path-style=absolute
```

**See data available to templates:**
```bash
chezmoi data
```

**View rendered template output:**
```bash
chezmoi cat ~/.gitconfig
```

**Find source file for a target:**
```bash
chezmoi source-path ~/.zshrc
```

## Applying Changes

**Apply all changes:**
```bash
chezmoi apply
```

**Apply specific file:**
```bash
chezmoi apply ~/.zshrc
```

**Apply with verbose output:**
```bash
chezmoi apply -v
```

**Dry run (show what would happen):**
```bash
chezmoi apply --dry-run --verbose
```

**Force apply (overwrite target without prompting):**
```bash
chezmoi apply --force ~/.zshrc
```

When to reach for `--force`:
- The user says "overwrite", "force", "apply anyway"
- `chezmoi apply` hung or failed on a TTY prompt (common in Claude Code)
- The user has reviewed the diff or explicitly doesn't need to

If the user hasn't seen the diff yet, run `chezmoi diff <path>` first.

## Managing Files

**Add file to chezmoi management:**
```bash
chezmoi add ~/.zshrc
```

**Add with attributes:**
```bash
chezmoi add --private ~/.ssh/config
chezmoi add --template ~/.gitconfig
chezmoi add --executable ~/.local/bin/script.sh
```

**Edit managed file (opens in $EDITOR):**
```bash
chezmoi edit ~/.zshrc
```

**Edit directly and re-add:**
```bash
vim ~/.zshrc
chezmoi re-add ~/.zshrc
```

**Remove from management:**
```bash
chezmoi forget ~/.zshrc
```

## Working with the Repository

**Enter source directory:**
```bash
chezmoi cd
# Now in ~/.local/share/chezmoi
exit
```

**Update from repository:**
```bash
chezmoi update
# Equivalent to: cd source && git pull && exit && chezmoi apply
```

## Script State Management

**Force run_onchange scripts to re-run:**
```bash
chezmoi state delete --bucket=entryState --key="$(chezmoi source-path)/run_onchange_script.sh"
chezmoi apply -v
```

**Delete all script states:**
```bash
chezmoi state delete-bucket --bucket=entryState
chezmoi apply -v
```

## Verification & Troubleshooting

**Verify files match source:**
```bash
chezmoi verify
```

**Doctor command (checks for issues):**
```bash
chezmoi doctor
```

**Debug template rendering:**
```bash
chezmoi execute-template < ~/.local/share/chezmoi/dot_gitconfig.tmpl
chezmoi execute-template '{{ .email }}'
```

## Chezmoi Status Column Meanings

| Column | Compares | Meaning |
|--------|----------|---------|
| 1 | Last-applied entry state vs. actual file on disk | "Was this edited outside chezmoi?" |
| 2 | Actual file on disk vs. rendered template output | "Would `chezmoi apply` change anything?" |

Status codes: A (added), M (modified), D (deleted), R (will run script)
