# Tasks

## 1. Prerequisites and remaining spike

- [ ] 1.1 Confirm `chezmoi-managed-plugin-marketplace` is applied on this machine: `claude plugin marketplace list --json` resolves `chezmoi-personal` to `~/.local/share/claude-plugins` in every persona. Note that the MacBook Pro still needs that change's tasks 3.4–3.6.
- [ ] 1.2 Archive `chezmoi-managed-plugin-marketplace` before archiving this change, so the main `claude-plugin-marketplace` spec contains its "chezmoi-managed and templatable" requirement that this change's delta builds on. Verify `grep -c "templatable" openspec/specs/claude-plugin-marketplace/spec.md` returns at least 1.
- [ ] 1.3 In a logged-in scratch persona (copy of `~/.claude-personal`, never the live dir), install a minimal local plugin whose `PreToolUse` hook (matcher `Read`) emits `additionalContext` once. Verify the context reaches the model, and that it fires inside a subagent. Log the raw hook payload in both cases and record whether the subagent's payload carries the parent's `session_id` and an `agent_id`. If it has no field that tells it apart from the parent, stop and revisit the marker key in design D4. This closes the one spike question left untested.

## 2. claude-session-index plugin (external repo, before any legacy removal)

- [ ] 2.1 In `cearley/claude-session-index`, add `.claude-plugin/plugin.json` and `hooks/hooks.json` declaring `UserPromptSubmit`, `PreCompact`, and `SessionEnd` → `session-topic-capture <Event>`. Verify with `claude plugin validate --strict` in that repo, then push.
- [ ] 2.2 Add a `claude-session-index` entry to `home/dot_local/share/claude-plugins/dot_claude-plugin/marketplace.json.tmpl` (`source: url`, pinned `sha`) and `claude-session-index@chezmoi-personal` to `packages.yaml` `claude_code.plugins`. Verify `tests/run-template` renders valid JSON (`| jq .`).

## 3. claude-tooling plugin

- [ ] 3.1 Add `home/dot_config/claude-tooling/config.env.tmpl` (CT_SOURCE_DIR, CT_REPO_ROOT, CT_PERSONAS from `machine-settings`). Verify `tests/run-template` output is shell-sourceable (`bash -n`, then source it and echo each variable).
- [ ] 3.2 Add `home/.chezmoitemplates/plugin-content-hash` and document it in `home/.chezmoitemplates/CLAUDE.md`. Verify the hash is stable across two renders, changes after touching a file in the plugin directory, and does not change when only `plugin.json.tmpl` is edited (design D3).
- [ ] 3.3 Create `plugins/claude-tooling/` containing:
  - `.claude-plugin/plugin.json.tmpl` (version `1.0.0+<hash>`, and `author` templated from `{{ .fullname }}` and `{{ .gh_commit_email }}`; `validate --strict` fails without it)
  - `hooks/hooks.json`:
    - `PreToolUse` with matcher `Bash|Edit|Write|Read`, running the guard
    - `SessionStart` with matcher `startup`, running `check-claude-overrides`
    - `SessionStart` with matcher `compact|clear`, running `guard --reset`

  Add the marketplace entry. Verify with `claude plugin validate --strict` against the rendered directory.
- [ ] 3.4 Port the guard to `plugins/claude-tooling/scripts/executable_claude-tooling-write-guard`. Make these changes:
  - read `config.env` instead of template values
  - add `--reset`
  - add the `Read` fast path
  - replace the informational message with the contents of the rendered `~/.config/claude-tooling/claude-tooling.md` (no substitution in the guard)
  - key the once-per-context marker on `session_id`, plus `agent_id` when present; `--reset` clears all of the session's markers
  - remove `permissionDecision: "allow"`

  Verify with a fixture script under `tests/` that pipes sample hook payloads through the guard and checks each case:
  - `deny` and `ask` cases unchanged
  - no `"allow"` anywhere
  - context emitted once per session, and again after `--reset`
  - a payload with an `agent_id` gets the context even when the parent's marker exists, and only once per `agent_id`
  - no output for unrelated paths
  - exit 0 with no context when `config.env` or the rendered context file is missing
  - `Read` fast path under 50 ms (`time`)
- [ ] 3.5 `git mv home/dot_claude/rules/claude-tooling.md.tmpl home/dot_config/claude-tooling/claude-tooling.md.tmpl`. Drop the `paths:` frontmatter, and condense the file to 80 rendered lines or fewer. It must cover every Content Coverage topic, including where hooks live, and keep `{{ .chezmoi.sourceDir }}` for source paths. Verify:
  - a checklist diff against the modified `claude-tooling-rule` spec topics
  - `grep -c '/Users/'` on the template returns 0
  - the `tests/run-template` output is 80 lines or fewer and contains no `{{`

## 4. Settings modifier, retirements, references

- [ ] 4.1 In `home/.chezmoitemplates/claude-settings-hooks-modifier`, remove `managed_hooks` and `retired_commands`, and remove the six legacy commands at the inner-hook level, pruning groups and events left empty. Update the header comment. Verify by piping a copy of each persona's live `settings.json` through the rendered modifier: only the legacy commands disappear, and `bd prime` and every other key are unchanged.
- [ ] 4.2 Delete `home/dot_local/bin/executable_claude-tooling-write-guard.tmpl` (the rule template was moved in 3.5). Create `home/.chezmoiremove` listing `.local/bin/claude-tooling-write-guard` and `.claude/rules/claude-tooling.md`. Verify `chezmoi managed | grep claude-tooling` shows only plugin paths and `.config/claude-tooling/`.
- [ ] 4.3 Update script 39: add the `plugin-content-hash` trigger comment and the per-persona `claude plugin update claude-tooling@chezmoi-personal --scope user -y` step. Verify the rendered script passes `bash -n` and that the trigger line changes when plugin content changes.
- [ ] 4.4 Point the three `claude-tooling.md` references (`global-preferences.md.tmpl:37`, `check-claude-overrides.tmpl:47`, `clean-claude-orphans/SKILL.md.tmpl:26`) at `~/.config/claude-tooling/claude-tooling.md`. Verify `grep -rn "rules/claude-tooling" home` returns nothing.
- [ ] 4.5 Open a `bd` follow-up issue: "Delete the legacy hook removal list from claude-settings-hooks-modifier once every persona on every ai machine has applied claude-tooling-plugin". Include the six command strings and the fixture case to remove. This change owns the list (design D6), and archiving does not wait for the deletion. Verify with `bd show <id>`.

## 5. Rollout and integration checks

- [ ] 5.1 Run `chezmoi apply` in an interactive terminal (KeePassXC needs a TTY). Then, for each of the four personas, verify:
  - `claude plugin list` shows `claude-tooling` and `claude-session-index`
  - `jq '.hooks' settings.json` contains no legacy commands
  - the rule file and the old guard binary are gone
- [ ] 5.2 Start a new session in two personas. Verify:
  - the override check runs once
  - reading a persona `settings.json` injects the tooling context once
  - after `/compact`, a matching read injects it again
  - a subagent that reads a persona `settings.json` after the parent already got the context receives it too
  - topic capture writes one record per prompt
- [ ] 5.3 Edit a comment in the guard and run `chezmoi apply`. Verify every persona's `installed_plugins.json` shows the new `1.0.0+<hash>` version, and that the previous cache directory still exists.
