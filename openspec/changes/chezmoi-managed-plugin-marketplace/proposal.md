# Bring the chezmoi-personal plugin marketplace under chezmoi management

## Why

`.claude-plugin/marketplace.json` and `plugins/` currently live at this repo's root, outside `home/` — never templated, never deployed, never touched by `chezmoi apply`. Registration goes through a dedicated `run_onchange_after_darwin-44-register-claude-plugin-marketplace.sh.tmpl` script rather than the generic `plugin_marketplaces` list in `packages.yaml`, because its source is `dirname {{ .chezmoi.sourceDir }}` — a template expression that can't live in `packages.yaml`'s static, non-templated YAML.

An audit-tooling review on 2026-08-20 surfaced two concrete problems with this arrangement:

1. Because `chezmoi-personal` is undeclared in `plugin_marketplaces`, `audit-packages`'s installed-vs-declared orphan check (`audit_claude_marketplaces`) would otherwise flag it as a false-positive orphan. The workaround is a hardcoded exception in `clean-claude-orphans` ("Name is `chezmoi-personal`... NEVER an orphan") rather than the checker correctly recognizing a genuinely declared marketplace. The same fragility would recur for any future locally-sourced marketplace.
2. This repo's entire purpose is chezmoi-managed dotfiles, yet its own plugin marketplace content is completely outside chezmoi's apply/template mechanism — a second, disconnected "install this stuff" system living beside chezmoi's own, with none of its templating capability (secret injection, per-machine/tag conditionals) available to it.

A separate GitHub repository was explored as an alternative fix and rejected — see `design.md`'s Alternatives Considered. It solves neither problem directly and costs the current zero-step "edit a plugin file, it's immediately live" loop.

## What Changes

- Move `.claude-plugin/` and `plugins/` from the repo root into `home/` (as `home/dot_local/share/claude-plugins/`), so chezmoi deploys them to a fixed target under `$HOME` (`~/.local/share/claude-plugins`) like every other chezmoi-managed file.
- Declare `~/.local/share/claude-plugins` as a plain string entry in `packages.darwin.ai.agents.claude_code.plugin_marketplaces`, so registration flows through the existing generic `run_onchange_after_darwin-39-install-claude-plugins.sh.tmpl` loop.
- Delete `run_onchange_after_darwin-44-register-claude-plugin-marketplace.sh.tmpl` — its one job is now handled generically.
- Remove the "`chezmoi-personal` is never an orphan" hardcoded exception from `clean-claude-orphans` (`executable_list-claude-orphans.sh.tmpl` + `SKILL.md.tmpl`) — once genuinely declared, `audit_claude_marketplaces` accounts for it without special-casing.
- Delete the orphaned `plugins/basic-memory-workflow/` leftover (stray untracked `__pycache__`, no `marketplace.json` entry, dead since the 2026-08-17 deprecation) while relocating the tree.
- Revise the `claude-plugin-marketplace` spec: the marketplace's own registration is no longer a self-referential path into the chezmoi *source* tree — it's a fixed, chezmoi-*deployed* target path, declared like any other marketplace instead of chezmoi-bootstrapped by a dedicated script. Marketplace/plugin content becomes chezmoi-templatable (previously explicitly disallowed).
- Convert `marketplace.json` and each of the 5 local `plugin.json` files to `.tmpl`, replacing their hardcoded `owner`/`author` `name` ("Craig Earley") and `email` (`craig@craigearley.software`) with `{{ .fullname }}` and `{{ .gh_commit_email }}` — the same chezmoi data fields `dot_gitconfig.tmpl` already uses for identical purposes — so personally-identifying content no longer sits in plain committed JSON.

**Non-goals**
- Not renaming the marketplace or any plugin — `chezmoi-personal` stays chezmoi-personal, and arguably becomes a more accurate name than before.
- Not moving to a separate GitHub repository.
- Not changing per-project plugin enablement — still a manual `claude plugins install <name>@chezmoi-personal` step.
- Beyond the `owner`/`author` `name`/`email` templating above, not templating any other plugin file content as part of this change — this change otherwise only makes templating *possible*; using it further (e.g. injecting a secret into a `.mcp.json`) is a separate future decision.
- Not touching the 5 marketplace entries that already point at third-party sources (`code-quality`, `systems-design`, `atlassian`, `aws-core`, `cloudflare`) beyond copying their existing JSON verbatim into the relocated `marketplace.json`. Their entries carry no personal name/email, so nothing in them needs templating.
- Not changing `marketplace.json`'s `owner.url` (`https://github.com/cearley/dotfiles`) — a public repo URL, not personally-identifying in the same sense, and out of scope for this fix.

## Capabilities

### Modified Capabilities
- `claude-plugin-marketplace`: registration mechanism changes from a dedicated self-referential `run_onchange` script to a plain declared entry in `plugin_marketplaces`; marketplace/plugin content moves under `home/` and becomes eligible for chezmoi templating (previously explicitly disallowed).

## Impact

- **Affected files**: `home/.chezmoidata/packages.yaml` (new `plugin_marketplaces` entry); new `home/dot_local/share/claude-plugins/` tree (moved and chezmoi-attribute-prefixed from `.claude-plugin/` + `plugins/`, with `marketplace.json` and each of the 5 local `plugin.json` files converted to `.tmpl`); `home/.chezmoiscripts/run_onchange_after_darwin-44-register-claude-plugin-marketplace.sh.tmpl` (deleted); `home/.chezmoiscripts/run_onchange_after_darwin-39-install-claude-plugins.sh.tmpl` (small fix so a `$HOME`-relative entry expands correctly — today's array insertion is single-quoted); `home/dot_claude/skills/clean-claude-orphans/scripts/executable_list-claude-orphans.sh.tmpl` and `SKILL.md.tmpl` (remove the exception); `home/dot_local/bin/executable_audit-packages.tmpl` (fix `audit_claude_marketplaces`'s `.source == "directory"` handling and `$HOME` expansion — a genuine pre-existing bug uncovered during implementation, see `design.md`); `home/dot_claude/rules/claude-tooling.md.tmpl` (the "Two Deliberately Different Install Models" section described the pre-migration mechanism); `openspec/specs/claude-plugin-marketplace/spec.md` (requirement revisions).
- **Affected tags**: `ai` only.
- **Affected personas**: registration re-runs for every `CLAUDE_CONFIG_DIR` persona via `for_each_claude_env`, same as today.
- **Migration**: machines that already have `chezmoi-personal` registered at the old source-tree path need that stale registration removed before the new declared entry is added at the new path, or `claude plugins marketplace add` may conflict/duplicate. Covered explicitly in `tasks.md`, not left implicit.
- **Security implications**: `owner.name`/`owner.email` and each `author.name`/`author.email` move from plain committed JSON to `{{ .fullname }}`/`{{ .gh_commit_email }}` template references. `name` renders identically ("Craig Earley"). `email` does **not** render identically: `.gh_commit_email` currently resolves to `cearley@users.noreply.github.com` (confirmed via `chezmoi execute-template`), not the currently-hardcoded `craig@craigearley.software` — the deployed `marketplace.json`/`plugin.json` files will show a different email after this change. That's arguably a further privacy improvement (a GitHub noreply address rather than a real personal address), consistent with the motivation for this task, but it is a real, visible behavior change worth confirming is wanted before implementation, not an unchanged re-templating. Beyond that, this change makes further secret-templating in plugin files possible but injects none itself.
- **External dependencies**: none added.
