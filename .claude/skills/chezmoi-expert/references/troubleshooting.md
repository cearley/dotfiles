# Chezmoi Troubleshooting Guide

## "file has changed since last read"

Another process modified the file while chezmoi was processing.

**Solutions:**
- `chezmoi apply --force ~/.zshrc` (force apply)
- `chezmoi re-add ~/.zshrc` then `chezmoi apply` (re-read and apply)
- `lsof ~/.zshrc` (check for concurrent processes)

**Prevention:** Don't edit files while chezmoi runs. Use `chezmoi edit` instead.

## Template Execution Failed

Template references a variable that doesn't exist.

**Diagnosis:**
```bash
chezmoi data                    # Check available data
chezmoi execute-template < ~/.local/share/chezmoi/dot_gitconfig.tmpl
chezmoi execute-template '{{ .email }}'
```

**Solutions:**
- Add missing data to `.chezmoi.toml`
- Use default: `{{ .email | default "user@example.com" }}`
- Make optional: `{{ if .email }}email = {{ .email }}{{ end }}`

## Permission Denied

**Solutions:**
```bash
ls -la ~/.ssh/config            # Check current permissions
chezmoi forget ~/.ssh/config    # Remove from management
chezmoi add --private ~/.ssh/config  # Re-add with correct attributes
```

## Merge Conflict During Update

```bash
chezmoi cd
git status                      # See conflicted files
vim dot_zshrc                   # Resolve <<<< ==== >>>> markers
git add dot_zshrc
git rebase --continue           # Or git commit
exit
chezmoi apply
```

## Script Won't Re-run

`run_onchange_*` script not running after changes.

```bash
chezmoi state delete --bucket=entryState --key="$(chezmoi source-path)/run_onchange_script.sh"
chezmoi apply -v
```

## Unwanted File Being Managed

```bash
chezmoi forget ~/.unwanted
chezmoi cd
git rm dot_unwanted
git commit -m "Remove unwanted file"
exit
```

## Changes Not Syncing Between Machines

```bash
chezmoi cd
git fetch && git status         # Check if behind
git pull
exit
chezmoi diff                    # Should show incoming changes
chezmoi apply
```

Also check:
- Is the file templated? (`chezmoi cat` vs `chezmoi source-path`)
- Is the file ignored? (`cat .chezmoiignore`)

## Diff Shows Changes But File Hasn't Changed

Common causes:
1. **Line ending differences:** `file ~/.zshrc` to check, `dos2unix` to fix
2. **Trailing whitespace:** `chezmoi re-add ~/.zshrc`
3. **Template rendering differently:** `chezmoi data` to check template variables

## Template Drift (Silent Out-of-Band Edits)

A `.tmpl` source exists, target was edited directly, but `chezmoi status`/`diff`/`verify` all report nothing.

**Why:** Chezmoi suppresses output when `chezmoi apply` would be a no-op, even if the file was edited outside chezmoi.

**Detection:**
```bash
chezmoi source-path <target>    # Ends in .tmpl? Susceptible to silent drift
chezmoi state dump              # Find entryState SHA256
shasum -a 256 <target>          # Compare hashes
```

**Resolution:**
- `chezmoi re-add <target>` -- accept target changes (WARNING: strips template directives from .tmpl files!)
- `chezmoi apply --force <target>` -- overwrite target with rendered template
- Edit the `.tmpl` source manually -- safest for template-managed files

**Prevention:**
- Use `chezmoi edit <target>` instead of editing directly
- After direct edits, immediately `chezmoi re-add`
- For frequently edited files (IDE settings), consider plain managed files over templates

## Failed to Decrypt File

```bash
chezmoi cd
cat .chezmoi.toml | grep -A 5 "\[encryption\]"
ls -la ~/.config/chezmoi/key.txt
```

Install age (`brew install age`), generate key (`age-keygen -o ~/.config/chezmoi/key.txt`), update recipient in `.chezmoi.toml`.

## Hook Script Fails

```bash
bash -n run_after_install.sh    # Check syntax
bash -x run_after_install.sh    # Debug execution
```

Make scripts resilient with prerequisite checks:
```bash
if ! command -v brew &> /dev/null; then
    echo "Homebrew not found, skipping"
    exit 0
fi
```

## Nuclear Options (Last Resort)

**Backup first:**
```bash
cp -r ~/.local/share/chezmoi ~/chezmoi-backup-$(date +%Y%m%d)
```

**Complete reset:**
```bash
rm -rf ~/.local/share/chezmoi
chezmoi init git@github.com:user/dotfiles.git
chezmoi apply
```

**Reset single file:**
```bash
chezmoi forget ~/.zshrc
chezmoi cd
git checkout HEAD -- dot_zshrc
exit
chezmoi apply ~/.zshrc
```

## Debug Information to Collect

When stuck, gather:
```bash
chezmoi --version
uname -a
chezmoi managed
chezmoi diff
chezmoi doctor
chezmoi data
chezmoi state dump | head -50
```

## Common Gotchas

1. **Editing files outside chezmoi** -- changes overwritten on next apply
2. **Forgetting to commit** -- changes apply locally but don't sync
3. **Template vs static file** -- use `chezmoi cat` to see rendered output
4. **Wrong prefix** -- check `private_`, `executable_`, etc.
5. **Ignored files** -- check `.chezmoiignore` (doesn't work for scripts!)
6. **State staleness** -- delete entryState for that script
7. **Multiple .chezmoi.toml files** -- check `.chezmoi.toml` vs `.chezmoi.toml.local`
