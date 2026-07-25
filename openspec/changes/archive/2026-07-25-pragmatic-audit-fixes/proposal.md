# Refactor: Pragmatic audit fixes — reduce complexity, remove dead code, fix DRY violations

## Current State

A pragmatic programmer audit of the chezmoi dotfiles repo identified 13 issues across templates, scripts, data files, and the AI tooling layer. Issues range from a fragile machine-config lookup that substring-matches root context keys, to a hand-rolled DSL parser for MCP server declarations, to dead migration scripts, duplicate iCloud checks, and various YAGNI violations.

## Problems

### High severity

1. **Machine config uses fragile substring matching** (`machine-config` template) — iterates all root context keys and matches against computer name via `contains`. Requires a growing exclusion list and would silently false-match any future top-level key.

2. **MCP server entries use a hand-rolled string DSL + ~40-line bash parser** (script 38, `packages.yaml`) — custom mini-language `'name -e VAR -- command args'` breaks on values with spaces. Should be structured YAML.

### Medium severity

3. **Migration script 33 still runs and carries `rm -rf` risk** — one-time layout migration, already complete on all machines. Dead code with destructive potential.

4. **iCloud status checked two different ways** (`icloud-account-id` template vs `shared-utils.sh`) — template-time bakes result in; runtime function re-checks. Script 23 and 28 use different approaches, leading to potential divergence.

5. **`zsh-defer` conditional in zshrc is always-false dead code** — the plugin is commented out, so the `else` branch always runs. Remove the branch.

6. **`trusted` list in `packages.yaml` must be manually synced** with tap/formula category declarations — miss one, it installs without the trust flag silently.

7. **Two entries for the same AWS knowledge MCP endpoint** in `tools.json.tmpl` — `aws-knowledge-mcp-server` (mcp-remote) and `aws-knowledge` (uvx fastmcp) both point to `knowledge-mcp.global.api.aws`.

8. **Manual date string as re-run trigger in script 41** — inconsistent with the `time-bucket` pattern used everywhere else. Also has an undocumented manual clone prerequisite.

### Low severity

9. **Two LM Studio PATH entries in zshrc** — old install location not removed when LM Studio changed paths.

10. **Empty `taps:` / `brews:` stubs in packages.yaml** (`personal`, `mobile` categories) — noise, the partial handles missing keys.

11. **`ai.cargo` key in packages.yaml is entirely commented out** — `cargo: null` adds nothing.

12. **`includeCore: false` parameter name misleads callers** in `package-layer-items` — only script 27 uses it; the name implies "exclude core" but means "core never auto-eligible."

13. **`eval` for dynamic variable assignment in `shared-utils.sh`** — bash associative array is cleaner and safer.

## Proposed Changes

Address issues in priority order:
- **#2**: Replace MCP server string DSL in `packages.yaml` with structured YAML maps; simplify script 38 template.
- **#1**: Move machine data under a `machines:` key in `config.yaml`; simplify `machine-config` to a direct `index` lookup.
- **#3**: Delete `run_onchange_before_darwin-33-transition-skills-to-symlinks.sh.tmpl`.
- **#4**: Consolidate iCloud check to runtime only.
- **#5, #9**: Remove dead code in `dot_zshrc.tmpl`.
- **#7**: Remove duplicate AWS knowledge MCP entry.
- **#8**: Replace manual date trigger with `time-bucket`; document prereq.
- **#10, #11**: Clean up empty/null stubs in `packages.yaml`.
- **#6**: Document `trusted` sync requirement in CLAUDE.md (or refactor inline).
- **#12**: Rename `includeCore` parameter in `package-layer-items`.
- **#13**: Replace `eval` with associative array in `shared-utils.sh`.

## Benefits

- Eliminates fragile substring-matching in machine config lookup
- Removes ~40 lines of bash string parsing; MCP server declarations become readable
- Removes an `rm -rf` risk vector
- Consistent iCloud handling across scripts
- Cleaner zshrc startup path
- No more silent trust-flag omissions for new taps

## Risks

- **#1 (machine-config restructure)** is the highest-risk change — touches `config.yaml` structure and the template, with call sites in 5+ scripts and the plist. Needs careful verification with `chezmoi cat` on each affected output.
- **#2 (MCP DSL restructure)** changes `packages.yaml` format; the generated `claude mcp add` invocations must be verified to produce identical results.
- All other changes are low-risk (dead code removal, documentation, minor refactors).
