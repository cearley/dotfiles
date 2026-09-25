# Proposal

## Why

Chezmoi-managed Claude Code hooks are currently merged into each persona's `settings.json`,
a file chezmoi shares with Claude Code, plugins, and other tools. Retiring a hook depends on
a manually kept `retired_commands` list, and a missed entry leaves the old hook firing
silently. A plugin's `hooks/hooks.json` is owned entirely by its author, so a hook deleted
from source simply disappears. Moving the hooks there removes the drift at its root.

The same move fixes three related problems:

- **The rule doesn't reach every session.** The path-scoped `claude-tooling` rule doesn't
  reliably reach subagents, and can be lost when a conversation is compacted.
- **The write guard auto-approves some commands.** Its informational branch returns
  `permissionDecision: "allow"`, so a Bash command that modifies a tooling file in a way the
  guard doesn't recognize runs without a permission prompt.
- **Hooks live with the wrong owner.** The `session-topic-capture` hooks are registered by
  this repo but belong to `claude-session-index`.

A spike on 2026-09-23 (scratch `CLAUDE_CONFIG_DIR`, Claude Code 2.1.281) confirmed the
plugin mechanics this relies on. The findings are in design.md.

## What Changes

- **New self-authored plugin `claude-tooling`** in the `chezmoi-personal` marketplace
  (`home/dot_local/share/claude-plugins/plugins/claude-tooling/`), declared in
  `packages.yaml` so script 39 installs it in every persona. It holds:
  - `hooks/hooks.json`: the only place these hooks are declared
    - `PreToolUse` guard (matcher `Bash|Edit|Write|Read`)
    - `SessionStart` override check
    - `SessionStart` re-injection after `compact` and `clear`
  - `scripts/claude-tooling-write-guard`: moved out of `~/.local/bin` and de-templated
- **Static plugin code plus chezmoi-rendered machine files.** Machine-specific values
  (source dir, repo root, persona list) move into a chezmoi-rendered
  `~/.config/claude-tooling/config.env` that the scripts read at run time. The tooling rule
  becomes `home/dot_config/claude-tooling/claude-tooling.md.tmpl`, condensed and rendered
  to `~/.config/claude-tooling/claude-tooling.md`. That rendered file is the single stable
  path read by both the guard and fork pre-briefs. The plugin tree contains no chezmoi
  templates except `plugin.json.tmpl`, and it ships no context file.
- **Version derived from content.** A new `plugin-content-hash` partial feeds both the
  plugin's `version` and script 39's `run_onchange` trigger. When the content changes,
  script 39 runs `claude plugin update … -y` in every persona. Nobody bumps versions by hand.
- **BREAKING:** `~/.claude/rules/claude-tooling.md` is retired as a rule. The guard
  delivers the tooling context instead, as a short notice of 1 KB or less: a pointer to
  `Read` the rendered file, plus a digest of the rules that must not be missed. Hook
  payloads larger than a few KB are cut to a preview, so the full text is never inlined. It fires the first time a tooling path is read or
  modified in each context window (the main conversation and each subagent), and again
  after compaction or clear.
- **Security fix:** the guard never returns `permissionDecision: "allow"`. It emits only
  `additionalContext`, `ask`, or `deny`.
- **Hooks leave `settings.json`.** `claude-settings-hooks-modifier` stops writing hooks.
  During migration it removes the commands it used to write (a fixed legacy list), in the
  same apply that installs the plugin, so no hook runs twice.
- **`session-topic-capture` hooks move to `claude-session-index`.** That repo ships its own
  `hooks/hooks.json` and gets a `chezmoi-personal` marketplace entry (third-party `url`
  source) plus a `packages.yaml` plugin declaration.
- Three references to `claude-tooling.md` are updated to point at
  `~/.config/claude-tooling/claude-tooling.md`:
  - `global-preferences.md.tmpl` (the fork pre-brief instruction)
  - `check-claude-overrides`
  - the `clean-claude-orphans` SKILL.md

## Non-goals

- Moving `check-claude-overrides` into the plugin. It stays a templated `~/.local/bin` CLI,
  and the plugin hook calls it by name.
- Moving the `clean-claude-orphans` or `audit-skills` skills. Moving them would add plugin
  prefixes to their names, force `skillOverrides` keys to be rewritten, and change the
  native-skill list `check-claude-overrides` uses, for little benefit.
- Extra-settings ownership (`permissions`, `env`, `skillOverrides`). That belongs to the
  `claude-settings-ledger` change, which lands after this one.
- Renaming `claude-settings-hooks-modifier`. A follow-up can do it once hooks are gone
  from it.
- Deleting old plugin cache versions during apply, because running sessions still use them.

## Capabilities

### New Capabilities
- `claude-tooling-plugin`: the self-authored plugin that owns chezmoi-managed Claude Code
  hooks. Covers:
  - plugin layout and hook declarations
  - the static-code/runtime-config split
  - content-hash versioning and automatic per-persona updates
  - the guard's context injection and permission behavior
  - removal of the old hooks from `settings.json`

### Modified Capabilities
- `claude-tooling-rule`: delivery changes from a path-scoped user rule file to guard-injected
  context, rendered to `~/.config/claude-tooling/claude-tooling.md`. The content-coverage
  topics stay the same, and machine paths are still resolved at render time.
- `claude-override-audit`: the automatic `SessionStart` invocation is declared by the
  `claude-tooling` plugin's `hooks.json`, not by `claude-settings-hooks-modifier`.
- `claude-plugin-marketplace`: self-authored plugins may be installed in every persona
  through a `packages.yaml` declaration, and may use a content-derived version with
  automatic updates instead of a manual version bump.

## Impact

- **New:**
  - `home/dot_local/share/claude-plugins/plugins/claude-tooling/**`
  - `home/.chezmoitemplates/plugin-content-hash`
  - `home/dot_config/claude-tooling/config.env.tmpl`
  - `home/dot_config/claude-tooling/claude-tooling.md.tmpl` (moved and condensed from
    `home/dot_claude/rules/claude-tooling.md.tmpl`)
  - a `marketplace.json.tmpl` entry
- **Changed:**
  - `home/.chezmoiscripts/run_onchange_after_darwin-39-install-claude-plugins.sh.tmpl`
    (hash trigger and update step)
  - `home/.chezmoidata/packages.yaml` (`plugins:` gains `claude-tooling@chezmoi-personal`
    and `claude-session-index@chezmoi-personal`)
  - `home/.chezmoitemplates/claude-settings-hooks-modifier` (stops writing hooks; removes
    legacy ones)
  - `home/dot_claude/rules/global-preferences.md.tmpl`
  - `home/dot_local/bin/executable_check-claude-overrides.tmpl` (comment pointer only)
  - `home/dot_claude/skills/clean-claude-orphans/SKILL.md.tmpl`
- **Removed:**
  - `home/dot_local/bin/executable_claude-tooling-write-guard.tmpl`
  - `home/dot_claude/rules/claude-tooling.md.tmpl` (moved, see New)
- **External:** `cearley/claude-session-index` gains `.claude-plugin/plugin.json` and
  `hooks/hooks.json`.
- **Depends on:** `chezmoi-managed-plugin-marketplace` (marketplace deployed to
  `~/.local/share/claude-plugins`). Its remaining MacBook Pro migration tasks must finish
  first on that machine, and that change must be **archived before this one**, because
  this change's `claude-plugin-marketplace` delta builds on its templatable-content
  requirement.
- **Related:** `claude-settings-ledger` edits the same modifier template and lands after
  this change. This change owns the legacy hook removal list, including its eventual
  deletion.
- **Tags:** darwin with the `ai` tag. All four personas (`~/.claude`, `~/.claude-personal`,
  `~/.claude-work`, `~/.claude-bedrock`).
- **Security:**
  - The auto-approval gap in the guard is closed.
  - If the plugin is disabled or uninstalled in a persona, the guard stops running there.
    `check-claude-overrides` already flags `enabledPlugins: false` for plugins declared in
    `packages.yaml`, which covers this case.
  - No secrets involved. `config.env` and the rendered context hold only paths, persona
    names, and guidance.
