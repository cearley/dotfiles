## 1. Transition Script

- [x] 1.1 Create `home/.chezmoiscripts/run_onchange_before_darwin-36-transition-skills-to-symlinks.sh.tmpl`: iterate over `claude_envs`, skip missing dirs and existing symlinks, remove real `skills/` directories with a log message
- [x] 1.2 Verify the script handles missing `~/.claude-bedrock` dir gracefully (skip, no error)
- [x] 1.3 Verify the script is idempotent when `skills/` is already a symlink

## 2. Chezmoi Symlink Files

- [x] 2.1 Create `home/dot_claude-bedrock/symlink_skills.tmpl` with content `{{ .chezmoi.homeDir }}/.claude/skills`
- [x] 2.2 Create `home/dot_claude-personal/symlink_skills.tmpl` with content `{{ .chezmoi.homeDir }}/.claude/skills`
- [x] 2.3 Create `home/dot_claude-work/symlink_skills.tmpl` with content `{{ .chezmoi.homeDir }}/.claude/skills`

## 3. Simplify the Skills Install Script

- [x] 3.1 In `home/.chezmoiscripts/run_onchange_after_darwin-37-install-claude-skills.sh.tmpl`, verify whether `npx skills update` and `npx skills add` respect `CLAUDE_CONFIG_DIR` or use `~/.claude` by default
- [x] 3.2 Remove the `for_each_claude_env` loop and `_install_skills_for_env` function; run `npx skills update -g -y` and `npx skills add` once, targeting `~/.claude` via explicit `CLAUDE_CONFIG_DIR`
- [x] 3.3 Confirm the simplified script still installs all declared skills correctly

## 4. Verification

- [x] 4.1 Run `chezmoi apply` and confirm no errors (transition script removes real dirs, chezmoi places symlinks)
- [x] 4.2 Confirm `~/.claude-personal/skills` and `~/.claude-work/skills` are symlinks pointing to `~/.claude/skills`
- [x] 4.3 Confirm locally-managed skills (e.g., `parallel-worktrees`) are visible when running with `CLAUDE_CONFIG_DIR=~/.claude-personal`
- [x] 4.4 Confirm npm-installed skills appear in all environments after a single install pass
