# Tasks

## 1. Move global preferences into a shared rule

- [x] 1.1 `git mv home/dot_claude/CLAUDE.md.tmpl home/dot_claude/rules/global-preferences.md.tmpl`. Keep the `has "ai" .tags` guard, the variables, and the body, and add no `paths:` frontmatter. Verify that `tests/run-template home/dot_claude/rules/global-preferences.md.tmpl` renders the "# Global Preferences" content with no frontmatter block.
- [x] 1.2 Reword the persona bullet in `global-preferences.md.tmpl` per design D5. It should say that this rule (via `rules/`) and `skills/` are shared, and that `CLAUDE.md` is per-persona and tool-owned. Verify by re-rendering and grepping the output: `symlinked from ~/.claude/CLAUDE.md` should no longer appear.
- [x] 1.3 Remove the `!.claude/CLAUDE.md` line from `home/.chezmoiignore.tmpl`. Verify that `chezmoi managed | grep -c 'CLAUDE.md$'` prints `0`, with no `.claude/CLAUDE.md` or `.claude-*/CLAUDE.md` in the list.

## 2. Remove persona CLAUDE.md symlinks

- [x] 2.1 Delete `home/dot_claude-{personal,work,bedrock}/symlink_CLAUDE.md.tmpl`. Verify that `ls home/dot_claude-*/symlink_CLAUDE.md.tmpl` finds nothing, and that `chezmoi managed` no longer lists `.claude-<name>/CLAUDE.md`.
- [x] 2.2 Create `home/.chezmoiscripts/run_onchange_after_darwin-44-migrate-claude-md-symlinks.sh.tmpl` per design D3:
  - Wrap it in the darwin conditional and the `ai` guard, and use the shared-utilities messaging.
  - Iterate over `claude_envs`, and remove `<dir>/CLAUDE.md` only when it is a symlink whose target is exactly `$HOME/.claude/CLAUDE.md`.
  - Log a skip for everything else.

  Verify with `tests/run-template` that it renders for MacBook Pro and Mac Studio data, and that `bash -n` passes on the rendered output.
- [x] 2.3 Test script 44's rendered output against a **sandboxed** `HOME` in the scratchpad, never the real `~`. The fixtures:
  - `.claude-a/CLAUDE.md` is a symlink to `$HOME/.claude/CLAUDE.md`.
  - `.claude-b/CLAUDE.md` is a regular file.
  - `.claude-c/CLAUDE.md` is a symlink to a foreign target.
  - `.claude-d/` has no `CLAUDE.md`.

  Verify that only `a` is removed, `b` and `c` are byte-identical to before, `d` is unchanged, and a second run changes nothing (idempotent).

## 3. Drift detection in check-claude-overrides (removed during apply; see design D4)

- [x] 3.1 A `claude-md-symlink` drift kind was implemented and sandbox-tested, then removed at the user's direction because it's speculative scope. Verify that `git diff --quiet home/dot_local/bin/executable_check-claude-overrides.tmpl` exits 0, meaning the script matches HEAD.

## 4. Documentation text

- [x] 4.1 Revise the body of `home/dot_claude/rules/claude-tooling.md.tmpl` per design D5:
  - In the intro ownership sentence (line ~14), replace "CLAUDE.md" with the global-preferences rule, and add that each persona's `CLAUDE.md` is tool-owned.
  - Rename the persona-sharing section, and update the line ~32 cross-reference.
  - Delete the "Not a local file" paragraph. Replace it with a single statement in the intro of where global preferences live and their edit target.
  - Add `CLAUDE.md` to the "What's not shared" list.
  - Write it as a steady-state description: no mention of symlinked `CLAUDE.md`, the migration, or `omc setup` (design D5 writing principle).

  Verify by rendering it and grepping:
  - `symlink_CLAUDE.md`, `dot_claude/CLAUDE.md.tmpl`, and `CLAUDE.md are managed` have no matches.
  - `claude-md-symlink`, `omc setup`, and `tool-owned` have no matches.
  - `global-preferences.md.tmpl` has at least one match.
- [x] 4.1a Update the `paths:` frontmatter in `claude-tooling.md.tmpl` per design D5:
  - Keep `**/.claude*/CLAUDE.md`.
  - Add `**/.claude*/rules/**`, `**/dot_claude/**`, `**/dot_claude-*/**`, and `**/.chezmoidata/packages.yaml`. The spec requires a matching glob for every listed location, and `packages.yaml` had none either.

  Verify two things:
  - The rendered frontmatter lists all nine globs.
  - In a fresh session, reading `home/dot_claude/skills/<any>/SKILL.md` in the chezmoi source tree shows the rule loading, via `/memory` or `/context`. Observed on 2026-09-23: an Edit to `home/dot_claude/rules/claude-tooling.md.tmpl` loaded the deployed rule with `[Match: glob: **/dot_claude/**]`.
- [x] 4.2 Update the header comment in `home/dot_local/bin/executable_claude-tooling-write-guard.tmpl` so it no longer lists `CLAUDE.md` as a symlinked target. Verify with `grep -n CLAUDE.md` on the file.
- [x] 4.3 Run `grep -rn "dot_claude/CLAUDE.md\|symlink_CLAUDE.md" home/ CLAUDE.md .claude/` and fix any remaining live references. Archived openspec changes are exempt. Verify the grep returns only intentional hits.

- [x] 4.4 Remove `CLAUDE\.md` from `broad_pattern` in `executable_claude-tooling-write-guard.tmpl`, so a Bash command that touches a tool-owned persona `CLAUDE.md` no longer fires the "chezmoi manages this" nudge. Found during apply, and approved by the user. Verify in a sandbox: a payload whose command is `cat ~/.claude-work/CLAUDE.md` produces no output, and one whose command is `cat ~/.claude-work/settings.json` still produces the nudge.

## 5. Apply and verify on this machine

- [x] 5.1 Run `chezmoi apply`. Verify these three things:
  - `~/.claude/rules/global-preferences.md` exists.
  - `find ~/.claude-* -maxdepth 1 -name CLAUDE.md -type l` prints nothing.
  - `~/.claude/CLAUDE.md` still holds the OMC block, unchanged.
- [x] 5.2 In each persona that uses OMC, run `/oh-my-claudecode:omc-setup`. Verify that it completes without `Refusing symlink` and that each persona's `CLAUDE.md` is a regular file containing `<!-- OMC:START -->`. Verified 2026-09-23: `~/.claude` and all three personas have regular 6001-byte files with the identical OMC 5.5.0 block.
- [x] 5.3 Start a fresh session in one named persona and check `/memory` or `/context`. Verify that both `rules/global-preferences.md` and the persona's `CLAUDE.md` are loaded. Verified 2026-09-23 in bedrock: both are listed. The same run revealed the parent-folder leak in 5.6.
- [x] 5.4 Run `chezmoi status`. Verify that the output has no `CLAUDE.md` entries.
- [x] 5.5 Run `openspec validate claude-md-tool-ownership --strict`. Verify that it reports the change as valid.
- [x] 5.6 On machines with named personas, move `~/.claude/CLAUDE.md` aside (design D2 amendment). Claude Code reads `.claude/CLAUDE.md` in every parent folder of the working directory, so for any project under `$HOME` it loads the unused default persona's file as project memory, on top of the persona's own copy. Verify that `~/.claude/CLAUDE.md` is absent and that `/context` in a named persona no longer lists it. Done on MacBook Pro 2026-09-23 (backup at `~/.claude/CLAUDE.md.bak-2026-09-23`).
- [ ] 5.7 Mac Studio: pull and run `chezmoi apply` (script 44 removes the persona symlinks), run `omc setup` in each OMC persona, then move `~/.claude/CLAUDE.md` aside as in 5.6. Verify with `/context` in a named persona: exactly one `~/.claude-<name>/CLAUDE.md`, no `~/.claude/CLAUDE.md`, and `rules/global-preferences.md` present.
