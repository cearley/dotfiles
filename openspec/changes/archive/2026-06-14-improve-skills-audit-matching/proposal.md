## Why

The `audit-packages` skills section currently lists declared specs and installed skills as two separate flat lists and tells the user to "review manually." This defeats the tool's stated purpose — users cannot tell which installed skills are orphans without doing the comparison by hand. In particular, skills installed from single-entry specs (e.g. `wondelai/skills/clean-code`) or explicit `--skill` flags are unambiguously mappable to a skill name but the script never performs that mapping.

## What Changes

- The skills section will derive skill names from declared specs wherever the mapping is deterministic:
  - `<owner>/skills/<name>` (path-style specs) → skill name is the last path segment
  - `<spec> --skill <name>` (explicit flag) → skill name from the flag value
- Specs that install multiple skills (`-all` or bare `<owner>/<repo>` with no skill selector) will be treated as **collection wildcards** — any installed skill can be attributed to them as a fallback
- Installed skills will be checked against the derived set first; if not matched and any wildcard exists, they are attributed to the wildcard collection
- Only skills that cannot be matched to any declared spec (direct or wildcard) will be reported as orphans
- The "review manually" tip and dual-list output are replaced with the standard orphan-report format used by all other managers

## Capabilities

### New Capabilities
- *(none)*

### Modified Capabilities
- `package-audit`: The Claude Code skills scenario requirement changes — the audit SHALL perform deterministic spec-to-skill-name mapping and report genuine orphans, replacing the current "informational only" dual-list output.

## Impact

- **`home/scripts/audit-packages.sh`** — `audit_claude_skills()` function rewritten
- **`openspec/specs/package-audit/spec.md`** — Claude Code skills scenario updated to specify the matching algorithm
- No changes to `packages.yaml`, chezmoi templates, or other scripts
- Tags affected: `ai` (skills audit is gated on `ai` tag)

## Non-Goals

- Automatically discovering what skills a collection spec (`-all`) installs — that would require executing `npx skills` and is out of scope
- Removing or managing orphaned skills
- Auditing skills installed at project scope (only user-scope `~/.claude/skills/` is in scope)
