# Design

## Context

See proposal.md, "Why". Both files are user-level rules at the same memory tier. `global-preferences.md` has no `paths:` and loads in every session. `claude-tooling.md` loads when any of its nine `paths:` globs match, which covers every file a persona-layout task touches.

## Goals / Non-Goals

**Goals:**
- Each fact appears once, in the file whose loading condition matches when an agent needs it.
- Every `.claude.json` reference is correct for both the unset and set cases.

**Non-Goals:**
- New content. This change only moves, merges, and deletes text.

## Decisions

### D1. Placement test: "is it needed before any tooling file is touched?"
- Content that is needed **before** an agent touches a tooling file goes in `global-preferences.md`. This covers:
  - what `$CLAUDE_CONFIG_DIR` means and how to confirm it
  - the persona list, which is needed to answer "which persona am I in?"
  - the fork pre-brief instruction, because a coordinator dispatching a subagent may never touch a tooling file itself, so the path-scoped rule wouldn't load for it
- Everything else, meaning the layout, per-persona paths, `.claude.json`, and audit scoping, goes in `claude-tooling.md`. Any task that needs it reads or writes one of that rule's globbed paths, which loads it.
- **Alternative: keep the per-persona path rules in `global-preferences.md` as insurance.** Rejected. Reading `.claude.json`, `settings.json`, `plugins/` or `projects/` matches a glob, so the rule is already in context at the point of need.
  - `projects/` isn't globbed. A transcript read under `~/.claude*/projects/` wouldn't load the rule, so an agent could use the wrong persona's transcripts.
  - **Resolution:** add `**/.claude*/projects/**` to `claude-tooling.md`'s `paths:`, so the rule loads for any transcript read.

### D2. The `.claude.json` statement, written once in `claude-tooling.md`
- Wording: *"`.claude.json` is `$CLAUDE_CONFIG_DIR/.claude.json` when `CLAUDE_CONFIG_DIR` is set, and `~/.claude.json` (in the home directory, not in `~/.claude/`) when it is unset. Resolve it that way rather than assuming either path."*
- Every other per-persona item (`settings.json`, `plugins/`, `projects/`, `CLAUDE.md`) follows `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/<name>`. `.claude.json` is the one exception, and the text says so.

### D3. Fork pre-brief trigger list
- `global-preferences.md`'s list becomes "tasks touching Claude Code config (`settings.json`, `.claude.json`, `plugins/`, `skills/`, `rules/`, `CLAUDE.md`, transcripts) or the chezmoi `dot_claude*` sources and `packages.yaml`". It no longer restates paths, because `claude-tooling.md` has them.

## Risks / Trade-offs

- **[Risk]** An agent reasons about persona layout without touching a globbed file, for example by answering from memory. → Accepted. `global-preferences.md` still tells it to confirm the active persona, and to read `claude-tooling.md` when briefing a fork.
- **[Trade-off]** Adding the `projects/**` glob loads the ~150-line rule on transcript reads. → Accepted. Those are exactly the cross-persona mistakes the rule prevents.

## Migration Plan

Edit the two templates, render them with `tests/run-template`, apply the two targets with `chezmoi apply`, and commit. Rollback is `git revert`.

## Open Questions

- Fixing the fallback in scripts 38 and 39 (see proposal Non-goals) is a separate change. Deciding whether the default persona's scripts should unset `CLAUDE_CONFIG_DIR` instead of setting it to `~/.claude` doesn't affect this change.
