## 1. Pre-work: verify assumptions

- [x] 1.1 Confirm `wondelai/skills` is a public GitHub repo with each skill at a top-level path (`clean-code`, `refactoring-patterns`, `clean-architecture`, `software-design-philosophy`, `pragmatic-programmer`, `domain-driven-design`, `ddia-systems`, `system-design`), matching the `wondelai/skills/<name>` convention already used in `packages.yaml`'s `npx skills add` entries — confirmed via `gh api repos/wondelai/skills/contents/`, all 8 exist as top-level directories. Also discovered `wondelai/skills` is itself a Claude Code plugin repo with its own `.claude-plugin/marketplace.json`, whose own `code-craftsmanship`/`systems-architecture` bundles split domain-driven-design and clean-architecture differently than our plan — raised to the user, who chose to keep the original 5/3 split via our own custom `skills` array rather than adopt upstream's grouping or re-point at their bundles wholesale.
- [x] 1.2 Not needed — layout matched, no glue-script fallback required.

## 2. MCP-bundling plugins

- [x] 2.1 Create `plugins/aws-local-dev/.claude-plugin/plugin.json` (name, description, author) and `plugins/aws-local-dev/.mcp.json` registering `localstack-mcp-server` with `command: mcp-env-wrapper localstack-mcp-server npx -y @localstack/localstack-mcp-server` (copied from the current `packages.yaml` entry)
- [x] 2.2 Create `plugins/browser-tools/.claude-plugin/plugin.json` and `plugins/browser-tools/.mcp.json` registering `playwright` (`npx @playwright/mcp@latest`) and `safari` (`npx safari-mcp`)
- [x] 2.3 Create `plugins/openspec-dashboard/.claude-plugin/plugin.json` and `plugins/openspec-dashboard/.mcp.json` registering `openspec` (`npx openspec-mcp --with-dashboard`)

## 3. Skill-wrapping plugins

- [x] 3.1 Add the `code-quality` entry to `.claude-plugin/marketplace.json`: `source` pointing at `wondelai/skills`, `skills: ["clean-code", "refactoring-patterns", "clean-architecture", "software-design-philosophy", "pragmatic-programmer"]` (adjust path format based on task 1.1's findings)
- [x] 3.2 Add the `systems-design` entry to `.claude-plugin/marketplace.json`: same `source`, `skills: ["domain-driven-design", "ddia-systems", "system-design"]`

## 4. Re-pointed third-party plugins

- [x] 4.1 Add the `atlassian` entry to `.claude-plugin/marketplace.json`, with a freshly-fetched `sha` (via `gh api repos/atlassian/atlassian-mcp-server/commits/HEAD`) rather than reusing the local marketplace cache's potentially-stale pin
- [x] 4.2 Add the `aws-core` entry (`git-subdir`, `aws/agent-toolkit-for-aws.git`, path `plugins/aws-core`), with a freshly-fetched sha for `main`
- [x] 4.3 Add the `cloudflare` entry (`url`, `cloudflare/skills.git`), with a freshly-fetched sha for `HEAD`

## 5. Register the new plugins in marketplace.json

- [x] 5.1 Add `aws-local-dev`, `browser-tools`, `openspec-dashboard` entries to `.claude-plugin/marketplace.json` with local relative-path `source`s (matching the existing `basic-memory-workflow` entry's shape)
- [x] 5.2 Confirm all 8 new entries plus the existing `basic-memory-workflow` entry are present and the file is valid JSON

## 6. Spec and documentation updates

- [x] 6.1 Update `## Purpose` in `openspec/specs/claude-plugin-marketplace/spec.md` directly (not via delta) to reflect that plugins may now be re-pointed at externally-published content, not only authored inside this repo

## 7. Remove moved entries from packages.yaml

- [x] 7.1 Remove `localstack-mcp-server`, `playwright`, `safari`, `openspec` from `packages.darwin.ai.agents.claude_code.mcp_servers` in `home/.chezmoidata/packages.yaml`
- [x] 7.2 Remove the 8 `wondelai/skills/*` entries from `packages.darwin.ai.agents.claude_code.skills`
- [x] 7.3 Remove the commented-out `atlassian@claude-plugins-official`, `aws-core@agent-toolkit-for-aws`, `cloudflare@cloudflare` lines from `packages.darwin.ai.agents.claude_code.plugins`
- [x] 7.4 Confirm the `@fission-ai/openspec@latest` Bun CLI entry elsewhere in `packages.yaml` is untouched

## 8. Verification

- [x] 8.1 Validate `.claude-plugin/marketplace.json` and each new `plugins/*/.mcp.json` / `plugin.json` as well-formed JSON — all valid; `claude plugin validate` also run, only pre-existing-style "no version" warnings remain (matches `basic-memory-workflow`'s own versionless `plugin.json`), added a missing marketplace-level `description` it flagged
- [x] 8.2 Registered the marketplace (`claude plugins marketplace add`, confirmed already present) and installed 3 representative new entries — one per mechanism (`aws-local-dev` for `.mcp.json`, `code-quality` for the skills-array wrap, `atlassian` for the re-pointed third-party source) — in a scratch project at `--scope project`. `claude plugin details` confirmed each resolved correctly: `aws-local-dev` → 1 MCP server (`localstack-mcp-server`); `code-quality` → exactly the 5 intended skills with real token costs computed from actual content; `atlassian` → the full upstream plugin (6 skills + MCP server) resolved live from the re-pointed source. Did not individually install the remaining 5 (`browser-tools`, `openspec-dashboard`, `systems-design`, `aws-core`, `cloudflare`) — same two proven mechanisms, lower marginal verification value. Scratch project deleted afterward; the 3 test plugins were disabled (`claude plugin disable --scope local`) — `claude plugins list` still shows them as inert cached entries pointing at the deleted directory (a Claude Code CLI quirk when a project dir is removed without `uninstall` first), harmless and outside this change's files.
- [x] 8.3 `aws-local-dev`'s `.mcp.json` routes through the global `mcp-env-wrapper`, which sources `~/.config/mcp-env/localstack-mcp-server.env` — that file is deployed independently by the pre-existing `home/private_dot_config/mcp-env/private_localstack-mcp-server.env.tmpl` (gated on `ai`+`dev` tags, unrelated to `packages.yaml`'s `mcp_servers` list), so the same env injection that worked before this change continues to work unchanged.
- [x] 8.4 `chezmoi status` fails machine-wide on an unrelated pre-existing template (`dot_aws/modify_private_credentials.tmpl` needs a KeePassXC TTY prompt, per the documented non-interactive limitation) — not caused by this change. Used the more targeted `tests/run-template` instead on scripts 37/38/39: all three render cleanly against the trimmed `packages.yaml` (37 lists only the 3 remaining skills entries; 38 registers only `basic-memory`/`fast-filesystem`; 39 lists only the 5 remaining always-on plugins).
- [x] 8.5 `audit-packages` flags `atlassian@chezmoi-personal`, `aws-local-dev@chezmoi-personal`, `code-quality@chezmoi-personal` as "installed but not declared" — expected and correct: these are the moved capabilities, now intentionally installable without a `packages.yaml` declaration (that's this change's entire point), plus residue from this session's own verification testing (8.2). Remaining orphans in the audit output (`basic-memory-workflow@chezmoi-personal`, `fulcrum-skills@viewpoint-tools`, `plugin-dev`, `swift-lsp`, various skills) are pre-existing and unrelated to this change.
- [x] 8.6 `openspec validate --strict move-project-plugins-to-marketplace` → "Change 'move-project-plugins-to-marketplace' is valid"
