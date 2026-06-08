## Context

The chezmoi dotfiles repo manages Claude Code configuration across three named environments (`~/.claude-bedrock`, `~/.claude-personal`, `~/.claude-work`) in addition to the default `~/.claude`. Two categories of skills must be available in all environments:

1. **npm-installed skills** — installed via `npx skills add` in the position-37 script; currently looped over every `claude_envs` entry.
2. **Locally-managed skills** — chezmoi source files under `home/dot_claude/skills/`; deployed only to `~/.claude/skills/` and invisible to the other environments.

The `CLAUDE_CONFIG_DIR`-based environment switching works because Claude Code reads `$CLAUDE_CONFIG_DIR/skills/` directly. Skills are filesystem-resident (markdown/YAML directories), not registered entries in `.claude.json`.

The existing pattern for cross-env shared config is the `CLAUDE.md` symlink already in each env source dir (`symlink_CLAUDE.md.tmpl → ~/.claude/CLAUDE.md`). That pattern is the direct precedent for this change.

Currently, `~/.claude-personal/skills/` and `~/.claude-work/skills/` exist as real directories (auto-created by Claude Code). `~/.claude-bedrock/skills/` may or may not exist.

## Goals / Non-Goals

**Goals:**
- All locally-managed skills are visible in every Claude Code environment without duplication in source.
- npm-installed skills land in a single location, eliminating redundant per-env install iterations.
- The implementation is idiomatic chezmoi (symlink_ prefix, no custom logic needed at read time).
- Transition is automated — no manual directory removal required.

**Non-Goals:**
- Per-environment skill differentiation (all environments share the exact same skill pool).
- Changes to MCP server registration (per-env by design, not affected).
- Plugin installation changes (also per-env, unaffected).
- Non-darwin platform support.

## Decisions

### Decision 1: Symlink the whole `skills/` directory, not individual files

**Chosen**: Add `symlink_skills.tmpl` in each env source dir pointing to `{{ .chezmoi.homeDir }}/.claude/skills`.

**Alternatives considered**:
- *Per-file symlinks inside a real directory* — allows per-env augmentation, but requires a `run_onchange` script to iterate files, new skills won't propagate until the hash changes, and the hybrid dir is hard to reason about.
- *Canonical neutral location* (`~/.local/share/claude-skills/`) — cleanest architecture (`~/.claude` becomes a peer, not a base), but requires relocating the chezmoi source dir and updating tooling references. Worth revisiting if a fourth or fifth env is added.

Directory-level symlink mirrors the existing `CLAUDE.md` symlink pattern and requires no script logic.

### Decision 2: `~/.claude/skills` is the symlink target (not a neutral path)

**Chosen**: `{{ .chezmoi.homeDir }}/.claude/skills`

`~/.claude` is already the designated home for chezmoi-managed skill source files; it is the natural target. The neutral-location refactor is deferred as a separate change. The three env dirs will reference `~/.claude` as a base for shared read-only assets (CLAUDE.md and skills/), which is consistent and already established.

### Decision 3: Transition via `run_onchange_before` script

**Chosen**: A `run_onchange_before` script removes the existing real `skills/` directories before chezmoi attempts to place the symlinks.

chezmoi will fail (or warn) if it tries to replace a non-empty directory with a symlink. The transition script checks whether the path is a real directory (not already a symlink) and removes it. This is safe because:
- The directory contents (npm-installed skills) will be reinstalled by the position-37 script in the same apply run.
- Any user-added skills in those dirs would be lost, but that's an unsupported workflow (chezmoi is the source of truth for skills).

An alternative is documenting the manual `rm -rf` step, but automation is preferred for a chezmoi repo.

### Decision 4: Remove the per-env loop from the skills install script

**Chosen**: Install npm skills once, targeting `~/.claude` (the symlink origin), and drop the `for_each_claude_env` loop.

Once all environment `skills/` dirs are symlinks to `~/.claude/skills`, running `npx skills add` with any one environment's `CLAUDE_CONFIG_DIR` has the same effect as running it with all of them — writes go through the symlink to the same location. The loop was previously necessary to ensure each env's `skills/` dir was populated; it is now redundant and misleading.

The `npx skills update -g -y` call is also simplified to run once.

## Risks / Trade-offs

- **Real skills/ dirs with user content** → Mitigated by documenting that user-managed skills must live in `~/.claude/skills/` (i.e., they already work). The transition script logs a warning before removing.
- **chezmoi apply ordering** — the `run_onchange_before` script must run before the `dot_claude-*/symlink_skills` files are placed. chezmoi's `before_` prefix guarantees this.
- **Skills installed by Claude Code to a specific env** (e.g., via `claude /install-skill`) land in `~/.claude/skills/` through the symlink, affecting all environments. This is the intended behavior but could surprise a user who expected env isolation for skill installs.
- **~/.claude-bedrock env dir may not yet exist at transition time** — the transition script must handle missing dirs gracefully (skip, not error).

## Migration Plan

1. `chezmoi apply` runs the `run_onchange_before` transition script, which removes real `skills/` dirs in env dirs (if present and not already symlinks).
2. chezmoi places `symlink_skills` in each env dir.
3. The position-37 script runs once, installing npm skills to `~/.claude/skills/` (shared by all envs via symlinks).
4. Locally-managed skills under `home/dot_claude/skills/` are already in `~/.claude/skills/`.

**Rollback**: Remove the symlinks, run `mkdir -p skills` in each env dir, re-run the original script. No data is lost since skills are fully reinstallable.

## Open Questions

- Should `~/.claude` itself also get a `symlink_skills` pointing to a neutral path (making it a full peer rather than the base)? Deferred — the canonical-neutral-location refactor is a separate concern.
- Does `npx skills update -g -y` need `CLAUDE_CONFIG_DIR` to resolve the skills dir, or does it use `~/.claude` by default? Needs verification during implementation — if it ignores `CLAUDE_CONFIG_DIR`, the loop removal is trivially safe; if it respects it, we must pass `CLAUDE_CONFIG_DIR=~/.claude` explicitly.
