## Context

`audit-packages.sh` audits all six package ecosystems plus Claude Code skills/plugins/marketplaces against `packages.yaml`. For every other section, the script computes a declared set and diffs it against what is installed, reporting orphans. The Claude Code skills section is an exception: it prints the declared spec list and the installed skill directory names side-by-side with no comparison, delegating the diff to the user.

The root cause is a real mapping problem: a single declared spec can expand to many skill names (e.g. `specstoryai/agent-skills -all`), and the installed skill name does not always equal the repo name (e.g. `cearley/claude-session-index` → `session-index`). The previous implementation chose to skip matching entirely rather than do partial matching. The result is a noisy, unhelpful section.

## Goals / Non-Goals

**Goals:**
- Extract skill names from declared specs wherever the mapping is deterministic
- Attribute all remaining installed skills to collection-wildcard specs when at least one such spec is declared
- Report only skills that cannot be attributed to any declared spec (direct or wildcard) as orphans
- Match the orphan-report output format used by all other managers

**Non-Goals:**
- Resolving what skills a `-all` collection installs at audit time (would require network/npm execution)
- Auditing project-scope skills (only `~/.claude/skills/` user scope)
- Removing or modifying installed skills

## Decisions

### Decision: Two-tier matching (deterministic → prefix-narrowed wildcard)

Map installed skills to declared specs in two passes:

1. **Deterministic pass** — parse each declared spec string to extract a skill name:
   - Pattern `*/skills/<name>` (path-style, e.g. `wondelai/skills/clean-code`) → skill name `clean-code`
   - Flag `--skill <name>` anywhere in the spec string → skill name `<name>` (repeatable)
   - If neither pattern applies, the spec is a **wildcard** (e.g. `specstoryai/agent-skills -all`)
2. **Prefix-narrowed wildcard fallback** — for each wildcard spec, derive a prefix from the org name by stripping known company suffixes (`ai`, `hq`, `io`, `dev`, `co`, `labs`, `inc`, `app`, `apps`, `tech`, `ware`, `js`, `ly`) and trailing hyphens. An unmatched skill is attributed to a wildcard only if its name starts with that prefix (e.g. `specstoryai` → `specstory` → covers `specstory-*` skills).
3. **Orphan** — an installed skill that wasn't matched in either pass (including skills that don't start with any wildcard's derived prefix)

**Why prefix-narrowed rather than blanket wildcard?** The original blanket approach caused false negatives: `specstoryai/agent-skills -all` would suppress orphan detection for unrelated personal skills (e.g. `integrate-worktrees`, `memory-organize`) that happened to be installed alongside it. Prefix narrowing attributes a wildcard only to skills that plausibly originate from that org, while still reporting genuinely untracked skills as orphans.

**Why not try to derive names from bare repo specs?** The repo name rarely matches the installed skill name (`claude-session-index` ≠ `session-index`). The prefix heuristic is imperfect but far less noisy than guessing from the repo name.

**Alternatives considered:**
- *Execute `npx skills ls` per spec to get exact names* — requires network access and `npx`, breaks offline runs, out of scope
- *Blanket wildcard suppression* — original approach; superseded because it hid unrelated orphans
- *Maintain an explicit mapping in `packages.yaml`* — adds maintenance burden; deterministic parsing covers the common case without any extra config

### Decision: Output format

When orphans exist, emit them as plain lines (one per skill, no `print_message` wrapper), matching every other manager section. When none exist, emit `print_message "success" "No orphans"`. Drop the `print_message "tip"` and the dual-list display entirely.

When wildcards are present and cover all unmatched skills, note which collection specs are wildcards so the user knows why those skills weren't checked individually — but do not list every skill attributed to the wildcard.

## Risks / Trade-offs

- **False negative if wildcard covers a genuinely orphaned skill** → The `-all` wildcard is the declared intent; a skill that came from a now-removed collection install won't be detected. Mitigation: if the user removes a collection spec from `packages.yaml`, its skills become unattributable and will surface as orphans on the next run.
- **`--skill` flag parsing is naive (space-split)** → Could break on unusual quoting. Mitigation: the `packages.yaml` entries follow a consistent format; document in spec that `--skill <name>` must appear as a space-delimited token pair.

## Migration Plan

1. Rewrite `audit_claude_skills()` in-place — no schema changes, no new files
2. Run `audit-packages` locally to verify output
3. Commit; no `chezmoi apply` needed (script is not deployed by chezmoi, it runs from source)

## Open Questions

*(none)*
