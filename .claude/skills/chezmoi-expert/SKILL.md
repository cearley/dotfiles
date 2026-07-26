---
name: Chezmoi Expert
description: This skill should be used when the user asks to "edit dotfiles", "manage dotfiles", "add a config file", "chezmoi add", "chezmoi apply", "chezmoi diff", "chezmoi status", "sync configurations", "set up a new machine", "template a config file", "encrypt a config", "chezmoi encrypt", "manage secrets in dotfiles", mentions chezmoi commands or workflows, asks about dotfile management, wants to diff a plist file, or is working inside a chezmoi source directory. Provides comprehensive chezmoi dotfile management guidance.
---

# Chezmoi Dotfiles Management

Chezmoi manages personal configuration files (dotfiles) across multiple machines. It stores dotfiles in a git repository at `~/.local/share/chezmoi` and uses a declarative approach to apply them to the home directory.

## First Steps: Always Explore

Before helping with any chezmoi task, run these commands to understand the current state:

```bash
ls -la
chezmoi managed
chezmoi status
chezmoi diff
```

**IMPORTANT**: The repository contents change over time. Never assume structure based on documentation. Always read actual files.

## Sandbox Considerations

Chezmoi writes its state database at `~/.config/chezmoi/chezmoistate.boltdb`. For the Claude Code sandbox, that file path needs to be in `sandbox.filesystem.allowWrite` so that `chezmoi apply`, `chezmoi re-add`, `chezmoi update`, and `chezmoi state delete` work without bypassing the sandbox.

If a chezmoi command fails with `operation not permitted` on `chezmoistate.boltdb`, **fix the allowlist, don't disable the sandbox**. Reflexive `dangerouslyDisableSandbox: true` retries normalize sandbox bypass.

Read-only commands work inside the sandbox:
- `chezmoi status`, `chezmoi diff`, `chezmoi cat`
- `chezmoi managed`, `chezmoi source-path`, `chezmoi data`

**WARNING**: The sandbox overrides environment variables like `TMPDIR`. Templates using `{{ env "TMPDIR" }}` will render with sandbox values, causing **false positive drift**. For accurate drift detection, run chezmoi commands outside the sandbox. This is a templating concern, not a write-permission issue.

## Reading Chezmoi Diffs Correctly

**This is critical. Getting the direction wrong causes incorrect actions.**

`chezmoi diff` shows the PATCH that `chezmoi apply` would execute.

**Mnemonic: minus = on disk, plus = from template**

- `-` lines = what is currently ON DISK (live/target file) -- would be REMOVED by apply
- `+` lines = what chezmoi would WRITE (rendered from source/template) -- would be ADDED by apply

**Worked example:**

    -    "hookify@claude-plugins-official": true,
    +    "ralph-loop@claude-plugins-official": true,

Correct interpretation:
- hookify is ON DISK (live file has it, template does not)
- ralph-loop is IN THE TEMPLATE (template has it, live file does not)
- `chezmoi apply` would REMOVE hookify and ADD ralph-loop

**COMMON MISTAKE**: Do NOT say "the live file has X" when X appears on a `+` line. Do NOT say "the template has X" when X appears on a `-` line. `-` always means on disk. `+` always means from template.

## File Naming Conventions

| Source prefix | Effect |
|---------------|--------|
| `dot_` | Creates `.filename` |
| `private_` | Sets restricted permissions (0600) |
| `executable_` | Sets execute bit |
| `symlink_` | Creates symbolic link |
| `readonly_` | Sets read-only |
| `.tmpl` suffix | Processed as Go template |
| `run_once_` | Script runs once |
| `run_onchange_` | Script runs when content changes |
| `run_before_` | Script runs before applying |
| `run_after_` | Script runs after applying |

Example: `private_dot_ssh/config` becomes `~/.ssh/config` with 0600 permissions.

## Cross-Platform Scripting

OS-specific filename suffixes (`_darwin`, `_linux`) do NOT work for scripts (`run_once_*`, `run_onchange_*`). Convert to `.tmpl` and wrap the body in a template conditional:

```bash
# Filename: run_once_01_setup-macos.sh.tmpl
{{- if eq .chezmoi.os "darwin" }}
#!/bin/bash
set -euo pipefail
echo "Setting up macOS..."
{{- end }}
```

`.chezmoiignore` also does NOT work for scripts (they have no target path). Use template guards instead.

## Essential Commands

| Task | Command |
|------|---------|
| See pending changes | `chezmoi diff` |
| Apply changes | `chezmoi apply` |
| Apply specific file | `chezmoi apply ~/.zshrc` |
| Force apply (skip TTY prompt) | `chezmoi apply --force ~/.zshrc` |
| Check status | `chezmoi status` |
| List managed files | `chezmoi managed` |
| Add file | `chezmoi add <file>` |
| Add private file | `chezmoi add --private <file>` |
| Add as template | `chezmoi add --template <file>` |
| Edit managed file | `chezmoi edit <file>` |
| Re-add after direct edit | `chezmoi re-add <file>` |
| Remove from management | `chezmoi forget <file>` |
| View rendered template | `chezmoi cat <file>` |
| View template data | `chezmoi data` |
| Find source file | `chezmoi source-path <file>` |
| Update from repo | `chezmoi update` |
| Health check | `chezmoi doctor` |
| Force script re-run | `chezmoi state delete --bucket=entryState --key=<path>` |
| Init from repo (SSH) | `chezmoi init git@github.com:user/dotfiles.git` |

**Note:** `chezmoi init username` defaults to HTTPS. For SSH, always use the full URL.

## Template Basics

Templates use Go template syntax with data from `.chezmoi.toml`:

```toml
# .chezmoi.toml
[data]
    email = "derek@personal.com"
    personal_device = true
```

```
# dot_gitconfig.tmpl
[user]
    email = {{ .email }}
{{ if .personal_device }}
[github]
    user = personal-username
{{ end }}
```

For per-machine data, use `promptBoolOnce` in `.chezmoi.toml.tmpl`:

```toml
[data]
    personal_device = {{ promptBoolOnce . "personal_device" "Is this a personal device" }}
```

## Template Drift (Silent Edits)

When a `.tmpl` source exists, `chezmoi status`/`diff`/`verify` can all report clean even if the target was edited outside chezmoi. This happens when the rendered template matches the edited file.

To detect silent drift:
```bash
chezmoi source-path <target>   # If ends in .tmpl, drift can be silent
chezmoi state dump             # Compare entryState SHA256 vs actual
shasum -a 256 <target>         # Compare hashes
```

**Do NOT use `chezmoi re-add` on template-managed files** -- depending on chezmoi version it either strips template directives or silently no-ops (exit 0, no stdout/stderr, no source change). Edit the `.tmpl` source file directly instead.

## Helper Scripts

The plugin includes helper scripts in `${CLAUDE_PLUGIN_ROOT}/scripts/`:

### diff-plist.sh
Compare binary plist files between chezmoi source and target by converting to XML:
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/diff-plist.sh Library/Preferences/com.example.App.plist
```

### reconcile-status.sh
Detect ALL chezmoi drift, including silent template drift:
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/reconcile-status.sh [--verbose]
```

**Plist format preservation:** When editing plists, always convert back to the same format (XML or binary). Check with `head -c 6 file.plist` -- XML starts with `<?xml`, binary starts with `bplist`.

## Best Practices

1. **Always diff before apply:** `chezmoi diff` before `chezmoi apply`
2. **Use specific operations:** `chezmoi apply ~/.zshrc` over bare `chezmoi apply`
3. **Edit through chezmoi:** Use `chezmoi edit` or edit the source, not the target
4. **Meaningful commits:** "Add neovim config" not "update files"
5. **Test on one machine first:** Apply and test before syncing to others
6. **Use `--force` when needed:** Non-interactive shells (like Claude Code) hang on TTY prompts

## Additional Resources

### Reference Files

For detailed information, consult:

- **`references/commands.md`** - Complete command reference with all options and examples
- **`references/templates-and-workflows.md`** - Template syntax, machine-specific configs, daily workflows, Brewfile management
- **`references/troubleshooting.md`** - Comprehensive troubleshooting for all common errors
- **`references/common-scenarios.md`** - Step-by-step walkthroughs for real-world scenarios (VS Code, SSH, new machine setup, etc.)
- **`references/encryption.md`** - Age/GPG encryption, secret management, 1Password integration
