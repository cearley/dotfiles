# AI Agent Tooling in This Repo

Guidance for diagnosing installation health, editing settings/plugins, or reasoning about
skill/MCP usage — this repo's Claude Code tooling spans this directory, `.chezmoidata/`,
`.chezmoiscripts/`, and the repo root, so start here.

## Two Sources of Skills — Don't Confuse Them

**Native skills (this directory)**: authored and version-controlled in this repo. Run `ls`
here rather than trusting a hand-maintained list — same anti-drift principle as
`.chezmoiscripts/` (see `home/CLAUDE.md`). Deployed by `chezmoi apply` to `~/.claude/skills/`.

**External skills**: declared in `packages.darwin.ai.agents.claude_code.skills` in
`home/.chezmoidata/packages.yaml`, fetched from third-party GitHub repos (e.g.
`basicmachines-co/basic-memory-skills`, `specstoryai/agent-skills`) by
`run_onchange_after_darwin-37-install-claude-skills.sh.tmpl`. Their source of truth is the
external repo, not this one — edit `packages.yaml` to add/remove/pin, don't expect to find
their files here. They land in the same `~/.claude/skills/` directory as the native ones, so
`~/.claude/skills/` on disk is a merge of both sources.

## MCP Servers and Plugins

Also declared under `packages.darwin.ai.agents.claude_code` in `packages.yaml`:

- `mcp_servers` — installed by `run_onchange_after_darwin-38-install-claude-mcp-servers.sh.tmpl`
- `plugin_marketplaces` / `plugins` — installed/enabled by
  `run_onchange_after_darwin-39-install-claude-plugins.sh.tmpl`; the `plugins` list maps to
  `enabledPlugins` in `~/.claude/settings.json`

**Global MCP servers** (used across all projects) are separately deployed via
`home/private_dot_config/claude-extend/tools.json.tmpl` → `~/.config/claude-extend/tools.json`.

## Personas Share Skills and CLAUDE.md via Symlink

Each persona (`home/dot_claude-<name>/`) gets `symlink_skills.tmpl` and
`symlink_CLAUDE.md.tmpl` pointing back at `~/.claude/skills` and `~/.claude/CLAUDE.md` — so a
skill edit here or a `CLAUDE.md.tmpl` edit takes effect for every persona after one
`chezmoi apply`, with no per-persona copy to keep in sync.

**Not a "local" file, despite the path**: `~/.claude*/CLAUDE.md` is this symlink — checked-in
content sourced from `home/dot_claude/CLAUDE.md.tmpl`, not personal/local content. Any check
that distinguishes "LOCAL/personal" CLAUDE.md from "checked-in" (e.g. a `/doctor`-style dedup
pass) should treat it as checked-in. A genuinely personal, non-chezmoi-managed layer only
exists if the user separately created a `CLAUDE.local.md` alongside it — verify that file's
actual presence before assuming one exists.

What's **not** shared per persona: `settings.json`, `.claude.json`, `plugins/`, and session
history (`projects/`). Use `$CLAUDE_CONFIG_DIR/.claude.json` for all of these, never the bare
`~/.claude.json` — it belongs to a different persona and won't reflect (or affect) the active
one. Each persona's `modify_settings.json.tmpl` chezmoi-manages a baseline
`skillOverrides`/`enabledPlugins`/`permissions` posture for that machine's/profile's typical
workload (see the comment at the top of `home/dot_claude-personal/modify_settings.json.tmpl` —
these postures are derived from `/doctor` runs per-persona and should not be copied verbatim
between personas without re-running that analysis).

**Drift note**: the live `~/.claude*/settings.json` on any given machine can carry more
`skillOverrides`/`enabledPlugins` entries than the chezmoi template declares — ad hoc `/plugin`
toggles made directly in a session survive `chezmoi apply` (a `modify_` script only enforces
the specific keys it sets; it doesn't strip additions). When diagnosing "why is skill X off",
check both the template *and* the live file — they can legitimately disagree.

## Two Deliberately Different Install Models

- **`dot_claude/skills/` + `packages.yaml`** (this file's subject): global, always-on,
  identical across every persona and project on this machine.
- **The `chezmoi-personal` marketplace** (`.claude-plugin/marketplace.json` + `plugins/` at the
  repo root): a **separate, deliberately not-chezmoi-managed** catalog for convenient
  per-project opt-in/opt-out (`/plugin marketplace add`, then `/plugin install`) — registered
  once via `run_onchange_after_darwin-44-register-claude-plugin-marketplace.sh.tmpl`, but which
  plugins are actually *installed* into a given project is a per-project decision, not a
  machine-wide one. Don't add something here just because it's useful somewhere — that's what
  the marketplace is for.
