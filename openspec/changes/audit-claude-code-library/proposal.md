## Why

`audit-packages`' Claude Code orphan detection and `clean-claude-orphans`' `list-claude-orphans.sh` duplicate the same facts independently and disagree as a result. Two concrete bugs surfaced during a working session on `clean-claude-orphans`, both traced to `audit-packages`:

- `audit_claude_plugins` built its installed-plugin list with `sort` (no dedup) from `claude plugins list --json`, which emits one row per *scope* a plugin is installed in (e.g. once for `user`, once for `project`). `report_orphans`' `comm -23` pairs lines positionally, not as a set — a plugin installed in two scopes but declared once in `packages.yaml` left one spurious "orphan" behind (confirmed live: `claude-md-management@claude-plugins-official`, `superpowers@claude-plugins-official`). **This specific fix (`sort` → `sort -u` on the installed side) has already been applied directly to the working tree's `home/dot_local/bin/executable_audit-packages.tmpl`, uncommitted and separate from this change's own diff** — it's mentioned here only as context; this change's job is to preserve it when that logic moves into the shared library (Decision 5 in `design.md`), not to introduce it. (That standalone fix should be committed on its own before — or folded into — this change's implementation commits, so the two aren't conflated in history.)
- Neither `audit_claude_plugins` nor `audit_claude_skills` know that a plugin sourced from this repo's own chezmoi-personal marketplace (`.id` ends `@chezmoi-personal`), or a skill deployed via `chezmoi apply` under `dot_claude/skills/`, is just as legitimately "declared" as a `packages.yaml` entry. Both are reported as false orphans by `audit-packages` itself today — for *every* direct user of the tool, not just `clean-claude-orphans`. **This gap is still open; fixing it is this change's primary job.**

`clean-claude-orphans`' `list-claude-orphans.sh` worked around the second gap by shelling out to the entire `audit-packages` CLI (which also runs Homebrew/UV/Bun/Cargo/SDKMAN checks it doesn't need), `awk`-parsing its human-readable terminal prose (`=== Claude Code Plugins ===` headers, `[INFO]`/`[TIP]` prefixes, indentation) back into structured data, and separately re-deriving the chezmoi-personal/chezmoi-managed-skill exclusions itself in its own script. It never addressed the first gap (the dedup bug) at all — that bug lived entirely inside `audit-packages` and was invisible to a script that only ever consumed whatever `audit-packages` printed. `audit-packages`' `main()` runs unconditionally with no `BASH_SOURCE` guard, so nothing can source it to call its functions directly — scraping stdout was the only interface it exposed.

## What Changes

- New sourceable shared library, `home/dot_local/lib/audit-claude-code.sh.tmpl`, deployed by `chezmoi apply` to `~/.local/lib/audit-claude-code.sh`. **Revised after initial implementation**: the first version lived at `home/scripts/audit-claude-code.sh` as plain bash with no template syntax, since `home/scripts/` is listed in `home/.chezmoiignore.tmpl` and is never rendered — callers had to set `PACKAGES_YAML`/`CHEZMOI_MANAGED_SKILLS_DIR` as plain shell variables before sourcing it. Moved to `dot_local/lib/` (not chezmoiignored) and made a real `.tmpl` so the library computes those two paths itself via `{{ .chezmoi.sourceDir }}`, removing the caller-side setup contract entirely — each caller now just `source "$HOME/.local/lib/audit-claude-code.sh"` with no preceding variable assignments. The trade-off: editing the library now requires `chezmoi apply` to take effect, same as every other `dot_local/` deployment in this repo (previously, editing the `home/scripts/` copy took effect immediately, with no apply step). No `main()`, nothing executes on source.
- The library holds: `declared_for_agent` (moved verbatim from `audit-packages`), a chezmoi-managed-skill-name lookup, a chezmoi-personal-plugins lookup (name + bundled skills, from the deployed `marketplace.json`), and one JSON-Lines-emitting function per Claude Code category — `claude_orphan_plugins_jsonl`, `claude_orphan_marketplaces_jsonl`, `claude_orphan_skills_jsonl`, `claude_orphan_mcp_servers_jsonl`, plus `claude_installed_plugins_jsonl` (the per-plugin `{id, scope, projectPath, chezmoi_personal, enabled}` detail view `clean-claude-orphans`' `## installed-plugins` section already needs today). The plugin and skill orphan functions exclude chezmoi-personal plugins (by the `@chezmoi-personal` id suffix — the same rule already in use, not a new marketplace-name cross-reference) and chezmoi-managed skills as declared, and the plugin function's installed side stays deduped.
- `home/dot_local/bin/executable_audit-packages.tmpl`'s `audit_claude_plugins`/`audit_claude_marketplaces`/`audit_claude_skills`/`audit_claude_mcp_servers` become thin callers of the shared library: same `print_message` headers, same stderr uninstall hints, same `TOTAL_ORPHANS`/`MANAGERS_WITH_ORPHANS` bookkeeping, same exit-code behavior — the human-facing output format is unchanged — but the underlying set computation is now correct. `yq`-based `declared_for_agent` is removed from `audit-packages.tmpl` itself (now library-only).
- `home/dot_claude/skills/clean-claude-orphans/scripts/executable_list-claude-orphans.sh.tmpl` sources the same library directly instead of shelling out to `audit-packages` and `awk`-parsing its prose. Drops the `audit-packages` subprocess call, the `awk` state-machine parser, and the independent marketplace/chezmoi-managed-skills re-derivation it was doing — its `## chezmoi-personal-plugins` and `## chezmoi-managed-skills` display sections now call the same library lookups the orphan functions use internally, rather than querying `marketplace.json`/the skills directory a second time. Gains a `yq` prerequisite check (needed by `declared_for_agent`, which this script didn't call before).
- `openspec/specs/package-audit/spec.md` gains scenarios documenting that chezmoi-personal-sourced plugins and chezmoi-managed skills count as declared for their respective categories, and that the installed side of the plugins comparison specifically is deduped before diffing (the only category where the same item can produce more than one installed-side row).

## Capabilities

### New Capabilities

_(none)_

### Modified Capabilities

- `package-audit`: the declared-set computation for Claude Code plugins and skills expands beyond `packages.yaml` to also recognize chezmoi-personal marketplace membership and chezmoi-managed skill directories; the installed side of the plugins comparison is deduped before diffing.

## Impact

- `home/dot_local/lib/audit-claude-code.sh.tmpl` — new file, deployed to `~/.local/lib/audit-claude-code.sh`.
- `home/dot_local/bin/executable_audit-packages.tmpl` — `audit_claude_*` functions refactored to call the shared library; `declared_for_agent` removed (moved to the library); output format unchanged; declared-set semantics expand (bug fix).
- `home/dot_claude/skills/clean-claude-orphans/scripts/executable_list-claude-orphans.sh.tmpl` — rewritten to source the shared library directly; drops the `audit-packages` subprocess call and `awk` parsing; gains a `yq` prerequisite check.
- `home/dot_claude/skills/clean-claude-orphans/SKILL.md.tmpl` — wording updates only if the JSONL shape changes from what the skill currently documents (it should not — this change keeps the `{category, item, skill_tag}` schema already in place, with `skill_tag` always present as `null` or a string, never omitted).
- `openspec/specs/package-audit/spec.md` — scenario additions/amendments.
- No changes to `packages.yaml`, Homebrew/UV/Bun/Cargo/SDKMAN audit logic, or any other script.
- Affects the `ai` tag only (Claude Code sections are already gated on it).
- No security implications; both scripts remain strictly read-only.

## Non-goals

- Not touching Homebrew/Cask/Tap/UV/Bun/Cargo/SDKMAN audit logic — scope stays Claude Code only.
- Not changing `audit-packages`' human-readable output format or contract (prose, headers, stderr hints, exit codes) — those stay byte-for-byte identical.
- Not adding a `--json` flag or any new CLI surface to `audit-packages` itself — the shared library is consumed directly by scripts that need structured data, not via a new `audit-packages` mode.
- Not auditing MCP-server-bundled-by-plugin duplication — no evidence this session that the MCP servers section has a parallel gap, and its installed side is already deduped (`sort -u` already present).
- Not changing the skills audit's hardcoded `~/.claude/skills` path to something `$CLAUDE_CONFIG_DIR`-relative — pre-existing behavior, unrelated to this change.
