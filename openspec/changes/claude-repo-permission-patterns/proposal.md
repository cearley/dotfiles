# Proposal

## Why

Every Claude Code persona this repo manages (`~/.claude`, `-work`, `-personal`, `-bedrock`) carries one uniform permission posture, chosen by which `CLAUDE_CONFIG_DIR` you launch into (`claude-environments`, `claude-settings-ledger`). That axis answers *whose account is this* — it says nothing about *how much rope should this task get*, which instead depends on the repo and task in front of you: a production client repo, a personal/PoC repo, or a long-running unattended batch task each warrant a different permission posture regardless of persona. Today that posture is set entirely ad hoc, one approval prompt at a time, into each repo's untracked `.claude/settings.local.json` — this repo's own copy of that file has grown to ~200 hand-accumulated `allow` entries with no template, no starting point, and no way to reset or reproduce it on a new machine or a new repo.

An external framework for this (https://hidekazu-konishi.com/entry/claude_code_harness_and_environment_engineering_guide.html) names three reusable postures — Pattern A (approval-first, for production/sensitive work), Pattern B (curated allow-list, for personal/exploratory work), and Pattern C (sandboxed full-auto, for long-running batch tasks, safe only because an OS/container boundary contains it) — and this proposal adapts that framing into chezmoi-templated, reusable starting points instead of continuing to accrete Pattern B by accident in every repo.

## What Changes

- Add three chezmoi-templated permission-block snippets (Pattern A/B/C) under `home/.chezmoitemplates/`, each holding just a `permissions` block (`defaultMode`, `allow`/`ask`/`deny`) in `settings.json`'s own shape — no hooks, no persona-scoped keys, nothing that belongs to the existing settings ledger.
- Add a stamping script/skill that writes the chosen pattern's `permissions` block into the *current* repo's `.claude/settings.local.json` (gitignored, project-local, standard Claude Code precedence — never a tracked `.claude/settings.json` and never a persona's `settings.json`). Selection is explicit (`apply-claude-pattern a|b|c`), not auto-detected, for this iteration.
- For Pattern C only, additionally template a minimal container/devcontainer definition (non-root user, bind-mount only the working tree, no host credentials) as a separate reusable template — Pattern C's safety comes from that OS boundary, not from `settings.json` alone, and the stamping tool SHALL warn rather than silently apply Pattern C's `permissions` block without it.
- Document, in the new capability's spec and in `claude-tooling.md`, that this is a **second, independent axis** from persona selection: applying a pattern never touches `~/.claude*/settings.json` or the `_chezmoiManaged` ledger, and persona selection never implies a permission pattern.

**Non-goals**

- No automatic detection of "which pattern does this repo want" from cwd, git remote, or branch — that's future work once explicit selection has been used for a while (mirrors the article's own "graduated promotion," not a green light to skip it).
- No change to the existing identity-persona mechanism (`claude-environments`, `claude-settings-ledger`, `claude-settings-modifier`) — it is out of scope and untouched.
- No attempt to fold Pattern A/B/C into the `_chezmoiManaged` ledger merge/retraction machinery; that ledger's jurisdiction is `~/.claude*/settings.json`, not arbitrary project repos elsewhere on disk, and its current shape already took three prior changes to stabilize (`claude-settings-ledger`, `generalize-claude-settings-ledger`, `simplify-claude-settings-source`).
- No container *runtime* orchestration (spinning up, tearing down, or scheduling Pattern C sandboxes). This proposal only templates the container definition; launching it is a separate concern, likely an extension of the `project-session-manager` skill in a follow-up change.

## Capabilities

### New Capabilities
- `claude-repo-permission-patterns`: chezmoi-templated Pattern A/B/C permission snippets, a stamping mechanism that writes a chosen pattern into a target repo's `.claude/settings.local.json`, and a companion Pattern C container template.

### Modified Capabilities
(none — this is additive and does not change requirements of `claude-environments`, `claude-settings-ledger`, `claude-tooling-write-guard`, or any other existing capability)

## Impact

- **New files**: three permission-pattern templates in `home/.chezmoitemplates/` (or a `home/.chezmoitemplates/claude-patterns/` subdirectory — decided in design.md); a Pattern C devcontainer/Dockerfile template; a stamping script (`home/dot_local/bin/executable_apply-claude-pattern.tmpl` or a new Claude Skill, decided in design.md).
- **Affected tags**: `ai` (mirrors the existing persona settings' `ai`-tag gate) and `dev` (container tooling for Pattern C likely needs Docker/`docker` or similar, gated the same way other `dev`-tagged tooling is).
- **No changes** to `home/dot_claude*/`, `home/.chezmoitemplates/claude-settings-modifier`, or any persona's `.claude-settings.json`.
- **Security implications**: Pattern A/B are permission-scoped only and carry the same risk profile as any hand-written `settings.local.json` allow-list (over-broad `allow` entries can approve more than intended — the stamping tool should draw from vetted, reviewed snippets rather than the ad hoc accretion this proposal replaces). Pattern C is higher-stakes: its snippet is only safe when the accompanying container definition is actually running, mirrors the source article's explicit warning against `bypassPermissions` on a bare host, and the stamping tool must refuse or loudly warn if Pattern C is requested without evidence of container isolation (e.g., no `/.dockerenv`, no devcontainer marker). No secrets are introduced; the container template must bind-mount only the working tree, never `$HOME` or credential stores.
