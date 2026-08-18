## Context

See `proposal.md` - Why. Two established patterns already exist in this repo and are being extended rather than replaced: (1) the `skills/` symlink-sharing model in `claude-environments` (`symlink_skills.tmpl` in each persona dir, pointing at `~/.claude/skills`), and (2) chezmoi's `.chezmoiignore` allow-list carving exceptions out of an otherwise-ignored `.claude/*`. This change adds a `rules/` sibling to both.

## Goals / Non-Goals

**Goals:**
- Make the tooling knowledge trigger reliably on the files that actually signal installation-health/diagnosis work, on every persona, in every project.
- Reuse the existing symlink-sharing and chezmoiignore-allowlist patterns exactly, rather than inventing a new deployment mechanism.

**Non-Goals:**
- No hook, prompt-matching, or `/doctor`-specific trigger. (See Decisions below for why this was dropped.)
- No change to how `skills/` itself is deployed or shared — `rules/` is added alongside it, not merged into it.
- No change to `packages.yaml` or the package-management/machine-config capabilities — this is purely a knowledge-delivery mechanism change.

## Decisions

**Native path-scoped rule instead of a `UserPromptSubmit` hook.** The original idea was a hook matching `/doctor`/`/checkup` via a `matcher` regex. Research during design (confirmed against Claude Code's official hooks documentation) established that `UserPromptSubmit` hooks support no `matcher` field at all — they fire on every prompt submission — and that a hook can only inject text it reads and emits itself; there is no built-in "load this file" directive. Separately, the `hookify` plugin only generates warn/block rules (PreToolUse-style, plus a `prompt` event that can warn on prompt text) and has no file-content-injection capability, so it couldn't produce the desired behavior either way. A custom hand-written hook script was the only way to implement the original idea, and it would have needed to re-implement, in bash, logic the native `paths:`-scoped rules mechanism already provides — with a narrower trigger (only the literal typed command, not plain-English requests or Claude's own initiative) and an extra moving part to maintain in `claude-settings-hooks-modifier`. The native rule was chosen as strictly simpler and strictly more reliable.

**`paths:` glob list.** Chosen to match files whose *content*, not the user's phrasing, signals relevance:
- `**/.claude*/settings.json`, `**/.claude*/.claude.json` — per-persona config, matches `~/.claude/`, `~/.claude-personal/`, `~/.claude-work/`, `~/.claude-bedrock/` since `.claude*` matches the whole directory-name segment.
- `**/.claude*/plugins/**`, `**/.claude*/skills/**`, `**/.claude*/CLAUDE.md` — deployed artifacts, in case Claude inspects the installed copy rather than the chezmoi source.
- `**/.chezmoidata/packages.yaml` — narrowed to the `.chezmoidata` parent directory (rather than a bare `**/packages.yaml`) to avoid false-triggering on an unrelated `packages.yaml` in some other project.
- `**/dot_claude/**`, `**/dot_claude-*/**` — the chezmoi source tree itself, covering skill authoring, template edits, and persona-specific `modify_settings.json.tmpl` edits.

**Content migration, not content rewrite.** The rule's body is the existing `skills/CLAUDE.md` text plus the "before disabling anything" bullet from `CLAUDE.md.tmpl`, with source-tree paths converted to `{{ .chezmoi.sourceDir }}` for consistency with the fix already applied elsewhere in `CLAUDE.md.tmpl` (commit `1edba4c`). No new guidance is being authored as part of this change — only relocated and re-triggered.

## Risks / Trade-offs

- **[Risk]** Native `paths:`-scoped rules are a newer Claude Code feature; behavior nuances (e.g. exact glob-matching semantics, whether it matches on read vs. edit vs. both) are taken from current documentation and may shift in future Claude Code releases. → **Mitigation**: the content itself is harmless if it over- or under-triggers slightly; worst case is the same "sometimes doesn't load automatically" gap the current mechanism already has, not a regression. No other part of the system depends on this triggering with hard guarantees.
- **[Risk]** Broad globs like `**/dot_claude-*/**` could trigger on files unrelated to tooling diagnosis if a persona directory ever hosts unrelated content. → **Mitigation**: persona directories in this repo are exclusively Claude Code config; no other content is expected there.
- **[Trade-off]** Losing the literal `/doctor` command as an explicit, guaranteed trigger. → Accepted: the path-scoped trigger covers the actual mechanism `/doctor` uses (reading settings/config files) and additionally covers cases `/doctor` regex-matching would have missed.

## Migration Plan

1. Add the new rule file, symlink templates, and chezmoiignore entry (additive — no deletion yet).
2. Delete `home/dot_claude/skills/CLAUDE.md` and its chezmoiignore line, and trim `CLAUDE.md.tmpl`, in the same change (both live in the same commit; there is no meaningful intermediate state to preserve since the old file was never deployed).
3. `chezmoi apply` on each persona machine picks up the new `rules/` symlink and rule content on next run — no manual steps, no rollback beyond reverting the commit.
