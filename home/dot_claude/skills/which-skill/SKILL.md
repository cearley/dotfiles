---
name: which-skill
description: Use when the user asks whether a skill already exists for a task — "do I have a skill for X", "which skill handles X", "is there already a skill installed for this" — or wants a reminder of what's currently installed before assuming no skill exists or building one from scratch. Not for finding or installing a new skill from the public registry (see find-skills for that).
---

# Which Skill

Searches every skill actually usable on this machine — native, external, and
plugin-bundled (only plugins that are both installed and enabled), plus whatever the
current project declares — and matches it against a described task. This is about
*what's already here*, not discovering something new to install (`find-skills` does that).

## Step 1: Gather the full local inventory

```bash
~/.claude/skills/which-skill/scripts/list-skills.sh
```

Read-only. Outputs one line per skill: `invoke<TAB>origin<TAB>description` (description
truncated to ~160 chars):

- **invoke** — the ready-to-use id. Bare name (`/name`) for native/project skills,
  `plugin:skill` for plugin-bundled ones (e.g. `superpowers:brainstorming`) — use this
  column verbatim, don't construct it from the origin column yourself.
- **origin** — `native` (native + external, shared across every persona),
  `plugin:<marketplace>` (bundled in a plugin that's both installed and enabled under this
  persona — stale cache entries and disabled plugins are excluded), or `project`
  (`.claude/skills/*` at the current project's root). Context only, not for invoking.

Plugins and their marketplaces are **not** shared across personas — run this from the
persona (`$CLAUDE_CONFIG_DIR`) the user actually means, or re-run under
`CLAUDE_CONFIG_DIR=<other persona>` if they're asking about a different one.

**This list is not everything.** Skills that ship built into Claude Code itself (e.g.
`code-review`, `security-review`, `run`, `init`, `dataviz`) have no `SKILL.md` on disk and
won't appear in the script's output. Cross-check those against the skill names already
visible in the current session's own available-skills listing before concluding nothing
matches.

## Step 2: Match against the task

This is the judgment call the script can't make. Read the full inventory (and the
in-session skill listing for built-ins) and look for skills whose `description` covers the
user's actual task — not just keyword overlap. A skill's description is written as
trigger conditions, so match on the underlying problem it solves, not surface wording.

## Step 3: Report findings

- **One clear match**: name it, one line on why it fits, and how to invoke it — use the
  `invoke` column's value exactly as printed.
- **Several plausible matches**: list the top 2-3 with the same one-liner each, and note
  how they differ so the user can pick.
- **Nothing fits**: say so plainly. Don't force a weak match. Point to `find-skills` to
  search the public skills.sh registry for something to install, or offer to help with the
  task directly.

## Common mistakes

- Trusting the script's output as exhaustive — it misses built-in Claude Code skills (Step 1).
- Checking only the current persona's plugins when the user is asking about a different one.
- Recommending a skill on name/keyword match alone without reading what its description
  actually covers.
- Reconstructing an invoke string from the `origin` column instead of using the `invoke`
  column as printed.
