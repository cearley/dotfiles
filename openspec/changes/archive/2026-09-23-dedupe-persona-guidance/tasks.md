# Tasks

## 1. claude-tooling.md (sole home of persona layout)

- [x] 1.1 In `home/dot_claude/rules/claude-tooling.md.tmpl`, rewrite the "What's not shared" paragraph so it is the only statement of the per-persona layout:
  - The per-persona items are `settings.json`, `.claude.json`, `plugins/`, `projects/`, and `CLAUDE.md`, and each resolves as `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/<name>`.
  - `.claude.json` is the exception, worded per design D2.
  - Carry over from `global-preferences.md`: "when an audit or cleanup could mean every persona, ask which is wanted".

  Verify by rendering with `tests/run-template`: `$CLAUDE_CONFIG_DIR/.claude.json is the correct reference for all` has no matches, `~/.claude.json` appears exactly once, and the string "every persona" appears.
- [x] 1.2 Add `**/.claude*/projects/**` to the rule's `paths:` (design D1). Verify that the rendered frontmatter lists ten globs.

## 2. global-preferences.md (every-session facts only)

- [x] 2.1 In `home/dot_claude/rules/global-preferences.md.tmpl`, cut the persona bullet down to three things: the persona list, the instruction to confirm the active persona with the `echo` check before diagnosing, and nothing else. Delete the old line-40 paragraph (per-persona paths, `.claude.json`, "every persona"). Its content now lives in `claude-tooling.md`. Verify by rendering: `.claude.json` appears only in the fork pre-brief bullet or not at all, and `skillUsage` has no matches.
- [x] 2.2 Rewrite the fork pre-brief bullet's trigger list per design D3, and remove the `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/` path prefix that implied the wrong `.claude.json` location. Verify that the rendered bullet names `settings.json`, `.claude.json`, `plugins/`, `skills/`, `rules/`, `CLAUDE.md`, transcripts, `dot_claude*` and `packages.yaml`, and contains no `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.claude.json`-shaped path.

## 3. Cross-check and deploy

- [x] 3.1 Check that each persona fact has one home. Grep both rendered files for `skills/` and `rules/` are symlinked, `.claude.json`, and `every persona`, and confirm that each concept appears in exactly one file. The persona list and the `echo` check are expected in `global-preferences.md` only. Done 2026-09-23. The cross-check also found a bare `~/.claude/settings.json` in `claude-tooling`'s plugins section, now changed to "each persona's `settings.json`".
- [x] 3.2 Run `chezmoi apply ~/.claude/rules/global-preferences.md ~/.claude/rules/claude-tooling.md`. Verify that `chezmoi status` on both targets is clean afterwards.
- [x] 3.3 Run `openspec validate dedupe-persona-guidance --strict`. Verify that it reports the change as valid.
