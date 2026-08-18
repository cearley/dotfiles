## 1. Author the new rule

- [x] 1.1 Create `home/dot_claude/rules/claude-tooling.md.tmpl` with YAML frontmatter declaring the `paths:` list from `design.md` (`**/.claude*/settings.json`, `**/.claude*/.claude.json`, `**/.claude*/plugins/**`, `**/.claude*/skills/**`, `**/.claude*/CLAUDE.md`, `**/.chezmoidata/packages.yaml`, `**/dot_claude/**`, `**/dot_claude-*/**`)
- [x] 1.2 Migrate the body content of `home/dot_claude/skills/CLAUDE.md` into the new file, converting any hardcoded source-tree path reference to `{{ .chezmoi.sourceDir }}`
- [x] 1.3 Migrate the "before disabling anything" bullet content from `home/dot_claude/CLAUDE.md.tmpl` (Environment Notes section) into the new file, merging it with the migrated content from 1.2 rather than duplicating it
- [x] 1.4 Render the template (`tests/run-template home/dot_claude/rules/claude-tooling.md.tmpl` or `chezmoi execute-template <`) and confirm the frontmatter parses as valid YAML and all `{{ .chezmoi.sourceDir }}` references resolve correctly

## 2. Wire up deployment and symlink sharing

- [x] 2.1 Add `!.claude/rules/` to the `.claude/*` allow-list in `home/.chezmoiignore.tmpl`
- [x] 2.2 Remove the now-unneeded `.claude/skills/CLAUDE.md` ignore line from `home/.chezmoiignore.tmpl`
- [x] 2.3 Add `home/dot_claude-personal/symlink_rules.tmpl` with content `{{ .chezmoi.homeDir }}/.claude/rules` (mirror `symlink_skills.tmpl` in the same directory)
- [x] 2.4 Add `home/dot_claude-work/symlink_rules.tmpl` with the same content pattern
- [x] 2.5 Add `home/dot_claude-bedrock/symlink_rules.tmpl` with the same content pattern

## 3. Trim CLAUDE.md.tmpl and remove the superseded file

- [x] 3.1 Remove the "before disabling anything" bullet from `home/dot_claude/CLAUDE.md.tmpl` (now covered by the new rule)
- [x] 3.2 Remove the trailing pointer sentence to `skills/CLAUDE.md` from the persona-awareness (`$claudeEnvs`) block in `home/dot_claude/CLAUDE.md.tmpl`, keeping the rest of that block always-loaded and unchanged
- [x] 3.3 Delete `home/dot_claude/skills/CLAUDE.md`
- [x] 3.4 Grep the repo for any remaining reference to `skills/CLAUDE.md` and confirm none remain outside this change's own artifacts

## 4. Verify

- [x] 4.1 Run `chezmoi diff` (interactive TTY required) or `chezmoi status` to confirm the expected changes: new `~/.claude/rules/claude-tooling.md`, new `rules` symlinks in each persona dir, updated `~/.claude/CLAUDE.md`, removal of `~/.claude/skills/CLAUDE.md` (should already be absent from any deployed target, since it was chezmoi-ignored)
- [x] 4.2 Run `chezmoi apply` and confirm `~/.claude/rules/claude-tooling.md` exists and its content matches the rendered template
- [x] 4.3 Confirm `~/.claude-personal/rules`, `~/.claude-work/rules`, `~/.claude-bedrock/rules` are symlinks resolving to `~/.claude/rules`
- [x] 4.4 Confirm `home/dot_claude/CLAUDE.md.tmpl` no longer references `skills/CLAUDE.md` and still renders cleanly
