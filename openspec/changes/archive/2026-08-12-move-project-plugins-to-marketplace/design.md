## Context

See `proposal.md` for motivation. Relevant existing mechanics:

- `packages.darwin.ai.agents.claude_code.{mcp_servers,skills,plugin_marketplaces,plugins}` in `home/.chezmoidata/packages.yaml` are installed user-scope by `run_onchange_after_darwin-37/38/39` (skills / MCP servers / plugins+marketplaces respectively) — governed by the `package-management` spec's "Claude Code Agent Configuration Keys" requirement. Removing entries from these lists is a data change, not a spec change; that requirement's shape is untouched.
- `chezmoi-personal` marketplace (`.claude-plugin/marketplace.json` + `plugins/`) is registered once by `run_onchange_after_darwin-44-register-claude-plugin-marketplace.sh.tmpl`, governed by the `claude-plugin-marketplace` spec. It currently holds one plugin, `basic-memory-workflow`, which ships `skills/`, `hooks/hooks.json`, and glue scripts — no `.mcp.json`, no external `source`.
- `mcp-env-wrapper` (`home/dot_local/bin/executable_mcp-env-wrapper`, governed by the `mcp-env-injection` spec) sources `~/.config/mcp-env/<server-name>.env` before exec-ing its target command. It is invocation-agnostic — nothing in its own spec ties it to `packages.yaml` specifically, so a plugin's `.mcp.json` can invoke it exactly as `packages.yaml`-driven registration does today. No change needed to that capability.
- The official `claude-plugins-official` marketplace (cached at `~/.claude/plugins/marketplaces/claude-plugins-official/.claude-plugin/marketplace.json`) confirms two patterns this design reuses directly: (1) plugin entries with `source: {source: "url"|"github"|"git-subdir", url/repo, path, sha/ref}` pointing at arbitrary third-party repos, and (2) a plugin entry needing no `plugin.json` of its own — the `box` entry there is just a `source` plus a top-level `skills: ["./skills/box", ...]` array.

## Goals / Non-Goals

**Goals:**
- Every moved capability becomes independently installable via `claude plugins install <name>@chezmoi-personal`, with no loss of the underlying configuration (env var routing, command flags) it had in `packages.yaml`.
- `atlassian`/`aws-core`/`cloudflare` installable from `chezmoi-personal` without depending on their upstream marketplaces being registered.
- No vendored copies of wondelai's skill content — `code-quality` and `systems-design` reference `wondelai/skills` live.

**Non-Goals:**
- No new chezmoi script or automation for per-project plugin enablement (confirmed manual workflow).
- No change to how `basic-memory-workflow` itself is packaged.
- No change to the `mcp-env-wrapper` script or the `mcp-env-injection` capability — it already works unmodified for plugin-bundled `.mcp.json` commands.
- No attempt to keep `atlassian`/`aws-core`/`cloudflare` in perfect lockstep with upstream — their `source` sha/ref is a point-in-time copy, same staleness model `claude-plugins-official` itself uses.

## Decisions

**1. Six new plugin directories, not one mega-plugin.** `aws-local-dev`, `browser-tools`, `openspec-dashboard`, `code-quality`, `systems-design` are separate plugin directories under `plugins/`, each independently toggleable — matches the bundling boundaries agreed in the explore session (grouped by actual co-usage: browser MCPs together, code-craft skills together, systems-design skills together; AWS-local and openspec-dashboard each stand alone since nothing else shares their concern).

**2. `atlassian`/`aws-core`/`cloudflare` are marketplace.json entries only — no `plugins/` directory.** Since their `source` points entirely at an upstream repo, there is no local content for them in this repo at all; they exist purely as entries in `.claude-plugin/marketplace.json`. This is the same shape `claude-plugins-official` itself uses for the majority of its listings (most entries there have no corresponding local directory in that repo either — `source` is the entire definition).

**3. `.mcp.json` over a glue install-script for the three MCP-only plugins.** `aws-local-dev`, `browser-tools`, and `openspec-dashboard` need nothing beyond registering MCP servers — no skills, hooks, or commands — so a static `.mcp.json` is sufficient and avoids the install-time script complexity `basic-memory-workflow` needed for its stateful workflow logic. Alternative considered: keep using `run_onchange_after_darwin-38`'s `claude mcp add` mechanism but scope it per-plugin — rejected because that mechanism is inherently chezmoi-apply-triggered and user-scope, which is exactly the always-on behavior this change is trying to move away from.

**4. `code-quality`/`systems-design` use the marketplace's native `source` + `skills` array, not a glue script that shells out to `npx skills add`.** The already-installed `~/.claude/skills/clean-code/SKILL.md` confirmed wondelai's content is a completely ordinary Claude Code skill (plain frontmatter, `metadata.author: wondelai`), and the official marketplace's `box` entry proves the `source` + `skills` array pattern works without any `plugin.json`. This is simpler and keeps the skills live-synced to wondelai's repo rather than pinned to a glue script's install-time snapshot.
   - **Verification needed before implementation**: confirm `wondelai/skills` is in fact a public GitHub repo with each skill at a top-level path (`wondelai/skills/clean-code` → repo `wondelai/skills`, path `clean-code`), matching the `npx skills add wondelai/skills/<name>` argument convention already used in `packages.yaml` today. If the actual repo layout doesn't match (e.g. skills are generated/bundled rather than stored as plain directories), fall back to a thin glue-script plugin modeled on `basic-memory-workflow`'s install scripts, invoking `npx skills add wondelai/skills/<name> -a claude-code -y` (project-scoped, no `-g`) instead.

**5. Loosen the `claude-plugin-marketplace` spec's source restriction at the plugin-entry level, not the marketplace-registration level.** The existing requirement conflated two things: (a) the marketplace's own registration must be a local path (true, unaffected, still chezmoi-bootstrapped against the source tree) and (b) every plugin entry's source must be a local path (was only true because there was exactly one, self-authored plugin). The delta in `specs/claude-plugin-marketplace/spec.md` splits these — (a) stays, (b) is loosened.

**6. Update the capability's `## Purpose` line directly in `openspec/specs/claude-plugin-marketplace/spec.md` at implementation time**, not via the delta (delta `## Purpose` sections are ignored for existing capabilities, per `openspec instructions specs`). Current wording ("plugins defined inside this repo become installable") is no longer fully accurate once `atlassian`/`aws-core`/`cloudflare` exist as pure re-pointing entries with no local content. Tracked as a task, not a spec delta.

## Risks / Trade-offs

- **[Risk] `wondelai/skills` repo layout doesn't match the assumed convention** → Mitigation: verification step in Decision 4 before writing the marketplace entries; documented glue-script fallback if it doesn't hold.
- **[Risk] Pinning `atlassian`/`aws-core`/`cloudflare` sources by sha/ref means they silently go stale relative to upstream** → Mitigation: same staleness model already accepted for every entry in `claude-plugins-official` itself; not a regression, and refreshing the pin is a one-line `marketplace.json` edit when needed.
- **[Risk] Duplicated plugin listings (same plugin installable from both `chezmoi-personal` and the original marketplace) could confuse `claude plugins list` output** → Mitigation: acceptable trade-off for the one-stop-shop browsing experience that's the whole point of this change; no functional conflict since Claude Code plugins are keyed by `<name>@<marketplace>`.
- **[Risk] Removing `localstack-mcp-server`/`playwright`/`safari`/`openspec` from `packages.yaml` without first confirming no other machine profile depends on their always-on presence** → Mitigation: tag gating is uniform (`ai` tag, no machine-specific overrides for these entries today, per current `packages.yaml`); tasks.md includes a check of `chezmoi status` after the edit on this machine before considering the change done.

## Lessons Learned (Implementation)

Discovered during `/opsx:apply` and follow-up polish — worth checking again the next time this pattern (pulling something out of `packages.yaml` into a plugin, or adding a new bundle) is repeated:

- **Check whether an external content repo is itself a Claude Code marketplace before assuming a flat skill/plugin layout.** `wondelai/skills` turned out to have its own `.claude-plugin/marketplace.json` bundling these same skills differently — its `code-craftsmanship`/`systems-architecture` bundles split `domain-driven-design`/`clean-architecture` the opposite way from this change's `code-quality`/`systems-design` split, and pull in extra skills outside this change's scope. Fetch and read the source repo's own marketplace.json (if any, via `gh api repos/<owner>/<repo>/contents/.claude-plugin`) before finalizing a custom bundle — if it disagrees with the plan, that's a real design fork needing a user decision, not something to silently resolve either way.
- **Fetch fresh `sha`/`ref` pins via `gh api repos/<owner>/<repo>/commits/<ref>` at write time**, rather than copying a pin out of another marketplace's locally-cached `marketplace.json` (`~/.claude/plugins/marketplaces/.../marketplace.json`) — that cache is itself a point-in-time snapshot and may already be stale.
- **Keep a plugin's `plugin.json` `description` in sync with its `marketplace.json` entry `description`.** They render on different surfaces (marketplace.json → catalog browsing before install; plugin.json → post-install `/plugin` management and `claude plugin details`) and drift silently if only one gets edited. Precedent (`basic-memory-workflow`): plugin.json's description is a superset of marketplace.json's — never less detailed.
- **Verify a plugin resolves correctly without launching a full session or polluting global state**: `claude plugin details <name>@<marketplace>` resolves and prints the real component inventory (skills/MCP servers/agents/hooks) and projected token cost — enough to prove a `.mcp.json` or `source`+`skills`-array entry actually works. If deeper testing via `claude plugins install` in a scratch project is warranted, run `claude plugins uninstall`/`disable` *before* deleting the scratch directory — deleting it first leaves an inert "phantom" entry in `claude plugins list` that neither `uninstall` nor `disable` can fully clear afterward (harmless, but avoidable).
- **A self-referential local marketplace (like `chezmoi-personal`) can never be declared in `packages.yaml`'s `plugin_marketplaces` list.** That list holds static strings, but this marketplace's own source is `dirname {{ .chezmoi.sourceDir }}` — a template expression — and `.chezmoidata/` files are static/non-templated by this repo's own convention. It keeps its own dedicated `run_onchange` script (position 44) for exactly that reason; don't try to fold it into the generic list.

## Migration Plan

1. Add the 8 marketplace entries and 5 local plugin directories (`aws-local-dev`, `browser-tools`, `openspec-dashboard`, `code-quality`, `systems-design`) — additive, no existing behavior removed yet.
2. Verify each new plugin installs cleanly (`claude plugins install <name>@chezmoi-personal` in a scratch project) before touching `packages.yaml`.
3. Remove the now-redundant entries from `packages.yaml` and the dead `atlassian`/`aws-core`/`cloudflare` comments.
4. Run `chezmoi apply` and confirm scripts 37/38/39 complete without error against the shortened lists.
5. No rollback complexity beyond `git revert` — nothing here is a one-way migration (no data deleted, no state that can't be regenerated by re-running the install scripts against the old list).
