# Design

## Context

See proposal.md (Why). The current pieces:

- `claude-settings-hooks-modifier` upserts five hook commands into four personas'
  `settings.json`.
- `claude-tooling-write-guard` (a templated `~/.local/bin` script, 218 lines) sorts
  tooling-path tool calls into `deny`, `ask`, or an informational pass. It already keeps a
  once-per-session marker in `$TMPDIR/claude-tooling-write-guard/<session_id>`.
- `claude-tooling.md` is a 144-line path-scoped user rule, with render-time `sourceDir` and
  persona values.
- Script 39 runs `claude plugins install` per persona. Install does nothing when the plugin
  is already installed, and nothing currently runs `update`.
- The `chezmoi-personal` marketplace is rendered to `~/.local/share/claude-plugins`
  (change `chezmoi-managed-plugin-marketplace`).

### Spike findings (2026-09-23, Claude Code 2.1.281, scratch `CLAUDE_CONFIG_DIR` and marketplace)

| Question | Finding |
|---|---|
| Does `plugin update` see a new version from a local-dir marketplace? | Yes. No `marketplace update` needed. |
| Is a content edit picked up without a version bump? | **No.** Update reports "already at the latest version". |
| Is `1.0.0+<hash>` a valid version? | Yes. The cache dir becomes `1.0.0-<hash>`. |
| Are old cache versions pruned on update? | No. Sessions that are already running keep their old `installPath` until restarted. |
| Does `${CLAUDE_PLUGIN_ROOT}` work in hooks? | Yes. `validate --strict` warns when it is unquoted; exec form is also supported. |
| Can plugins ship `rules/`? | No. `plugin details` lists skills, agents, hooks, MCP, and LSP only. |
| Can `SessionStart` match on `compact` and `clear`? | Yes (superpowers uses `startup\|clear\|compact`). |

## Goals / Non-Goals

**Goals:**
- Hook declarations have exactly one owner.
- A plugin edit reaches all personas with a single `chezmoi apply`.
- The plugin code has no machine-specific values baked in.
- The migration leaves no window where a hook runs twice.

**Non-Goals:** automatic updates for the other `chezmoi-personal` plugins (they change
rarely and are installed per project). Performance tuning of the guard beyond keeping the
`Read` fast path cheap.

## Decisions

### D1. Hooks in a plugin rather than marker-based `settings.json` ownership
The marker plus ledger approach (previously in `claude-settings-ownership-markers`) still
leaves hooks inside a file other tools write to. A plugin's `hooks.json` has no merge step,
so there is nothing to retire and nothing to mark. The plugin's weak point is stale caches,
which D2 and D3 remove.

*Alternatives:*
- **`--plugin-dir` via the `zsh-claude-env` wrapper** (no cache): rejected because desktop,
  IDE, cmux, and `claude -p` sessions would run without the guard.
- **Managed-settings file:** rejected because it needs sudo and is system-wide.

### D2. Static plugin plus `config.env`
Only `.claude-plugin/plugin.json.tmpl` is templated.
`home/dot_config/claude-tooling/config.env.tmpl` renders shell-sourceable lines:

```sh
CT_SOURCE_DIR=…
CT_REPO_ROOT=…
CT_PERSONAS="~/.claude ~/.claude-personal …"
```

The guard sources that file and exits 0 if it is missing. Because the plugin source then
equals the installed files, a hash of the source identifies the content. Machine data
(persona list, paths) changes without a plugin update.

The tooling context is also rendered by chezmoi, outside the plugin:
`home/dot_config/claude-tooling/claude-tooling.md.tmpl` → `~/.config/claude-tooling/claude-tooling.md`.
It is the current rule template, moved and condensed, and keeps `{{ .chezmoi.sourceDir }}`
and the persona values it already uses. Two readers need one stable, machine-correct path:
- the guard (D4)
- the fork pre-brief in `global-preferences.md.tmpl`

Neither plugin location works for the pre-brief. The installed copy moves with every
version (`plugins/cache/…/1.0.0-<hash>/`), and a marketplace copy would still carry
placeholders. Rendering it once also removes the guard's `sed` step, and editing the
context (digest included) needs no plugin update.

*Alternative:* ship `context/claude-tooling.md` in the plugin with `@@…@@` placeholders,
substituted by the guard with `sed`. Rejected because the pre-brief reader would need its
own substitution step, and every context edit would bump the plugin version.

### D3. `plugin-content-hash` partial
`home/.chezmoitemplates/plugin-content-hash` takes a `plugin` name. It hashes every source
file under that plugin's directory except `plugin.json.tmpl`, in sorted order, using
`output "sh" "-c" "… shasum -a 256 …"`, and returns the first 12 hex characters.

- `plugin.json.tmpl` sets `"version": "1.0.0+{{ hash }}"`. The `1.0.0` stays manual and
  only signals meaningful change.
- `plugin.json.tmpl` is excluded from the hash because it contains the hash. As a result,
  an edit that touches only the manifest (description, author, keywords) does not change
  the version and is not pushed to installed personas. Bump `1.0.0` by hand when a manifest
  edit needs to reach them.
- Script 39 includes `# claude-tooling content: {{ hash }}` in its trigger comment, so any
  content change reruns it.
- After `install`, script 39 runs
  `claude plugin update claude-tooling@chezmoi-personal --scope user -y` for each persona.
  When nothing changed this is a no-op ("already at the latest version").

*Alternative:* a git SHA of the plugin directory. Rejected because uncommitted edits would
be invisible to it, and `chezmoi apply` from a dirty tree is the normal workflow here.

### D4. The guard delivers a pointer plus digest
The existing informational branch keeps its marker. Instead of the one-line message, it
emits a short **tooling notice** as `additionalContext`. The notice has two parts:
1. **Pointer:** one line telling the model to `Read` `~/.config/claude-tooling/claude-tooling.md`
   (D2) in full before acting on Claude Code tooling.
2. **Digest:** the section of that same file between `<!-- digest -->` and
   `<!-- /digest -->`, which the guard extracts with `awk`. It holds the rules that must not
   be missed even if the pointer is ignored:
   - cross-check `packages.yaml` before disabling or removing anything
   - edit chezmoi source, not deployed copies
   - which files are per persona
   - hooks live in the plugin's `hooks.json`

If the rendered file or its digest markers are missing, the guard emits nothing.

The whole notice must stay at or under **1 KB**. Hook `additionalContext` payloads larger
than a few KB are cut to a preview of about 2 KB, and the rest goes to a file the model
usually doesn't open ([[Claude Code Hook additionalContext/systemMessage Payloads Truncate
Past a Few KB]] in basic-memory). In an earlier incident, the model read only that preview
and skipped the guidance. An explicit `Read` is not truncated this way. The previous guard
already switched to a pointer for this reason (`9df01c5`); the digest adds the parts that
matter most in case the pointer isn't followed.

The digest lives inside the full file rather than in a separate file, so each fact has one
home, and anyone reading the full file sees the digest first.

*Alternative:* inject the whole rendered file. Rejected because even 80 lines is several
KB, above the truncation threshold.

- The marker is keyed per context window: `<session_id>` in the main conversation, and
  `<session_id>.<agent_id>` when the hook payload carries an `agent_id`. A subagent has its
  own context window, so an injection in the parent never reaches it. If the marker were
  keyed on `session_id` alone, and subagent payloads carry the parent's `session_id`, the
  parent's injection would suppress the subagent's. The whole reason for the plugin is to
  reach subagents, so that would defeat it. Task 1.3 confirms which fields the subagent
  payload carries.
- The branch drops `permissionDecision` entirely, so the normal permission flow applies.
  The `deny` and `ask` branches are unchanged.
- The matcher adds `Read`.
- A second `SessionStart` entry (matcher `compact|clear`) runs `guard --reset`, which
  deletes the session's markers (the main one and any per-agent ones).
- The path list moves from the rule's `paths:` frontmatter into one `case` pattern set in
  the guard.
- Target size for the rendered context file: 80 lines or fewer, covering every topic in
  the modified `claude-tooling-rule` Content Coverage requirement. It is read in full on
  every followed pointer, so its length is a token cost, not a truncation risk.

### D5. `check-claude-overrides` stays in `~/.local/bin`
It depends heavily on render-time values (baseline rendering, `packages.yaml` paths) and is
also a user command. The plugin hook is
`command -v check-claude-overrides >/dev/null 2>&1 && check-claude-overrides --session-start || true`.

### D6. Migration in one apply
The chezmoi apply order already does what's needed:

1. The file phase rewrites each `settings.json`, with the modifier removing the six legacy
   commands, and renders the marketplace and `config.env`.
2. `run_onchange_after` script 39 installs or updates the plugins.

This change owns the legacy removal list for its whole life, including its eventual
deletion. `claude-settings-ledger` rewrites the modifier's extra-settings stage later but
leaves the removal untouched. Once every persona on every `ai` machine has applied, the
list and its fixture are deleted as a tracked follow-up (task 4.5). This change does not
wait for that step before it is archived.

### D7. Marketplace scope widens to always-installed self-authored plugins
Until now, every self-authored `chezmoi-personal` plugin has been an opt-in, per-project
install with a manual `1.0.0` version. `claude-tooling` is the first one declared in
`packages.yaml` (so it is installed in every persona) and the first whose version comes
from a content hash. This change adds a `claude-plugin-marketplace` delta so that spec
permits both. Other self-authored plugins keep manual versions; nothing forces them to
switch.

The delta builds on the "chezmoi-managed and templatable" requirement from
`chezmoi-managed-plugin-marketplace`. That change must be **archived before this one**,
otherwise the main spec still says plugin content is never templated, and
`plugin.json.tmpl` would contradict it.

The spike showed `claude plugin validate --strict` fails when `author` is missing. The
marketplace spec already requires `author` to be templated from `{{ .fullname }}` and
`{{ .gh_commit_email }}`, so `plugin.json.tmpl` includes it.

### D8. `claude-session-index` owns its hooks
That repo adds `.claude-plugin/plugin.json` and `hooks/hooks.json`, with
`UserPromptSubmit`, `PreCompact`, and `SessionEnd` running
`session-topic-capture <Event>`. The CLI stays installed as a uv tool, and its skill stays
installed through `npx skills` for now.

The `chezmoi-personal` marketplace adds an entry with `source: url` pinned to a `sha`, like
the other third-party entries. `packages.yaml` declares
`claude-session-index@chezmoi-personal`.

**Ordering constraint:** the upstream plugin must exist and be pinned before this repo
removes the legacy `session-topic-capture` hooks.

## Risks / Trade-offs

- **Script 39 fails after the file phase removed the legacy hooks** (e.g. `claude` missing):
  that persona is left with no guard. → Script 39 already warns for each failure. The
  verification task checks that `claude plugin list` shows the plugin in every persona. A
  re-run of apply heals it, because the install step does nothing when the plugin is
  already present.
- **User disables the plugin in one persona** → the guard is silently off there.
  `check-claude-overrides` flags `enabledPlugins: false` for plugins declared in
  `packages.yaml`.
- **The `Read` matcher adds guard latency to every read** → the fast path exits after one
  `jq` call and a `case` match. Measured in tasks, with a budget of 50 ms or less.
- **Cache directories accumulate one per edit** → they are small. Pruning is out of scope
  (running sessions reference them). A follow-up could prune versions older than 7 days.
- **`output "sh"` runs on every template render**, including `chezmoi status` → it hashes a
  handful of small files, which takes milliseconds.
- **Hash inputs use source filenames** (`executable_…`, `dot_…`) → renaming a source file
  changes the version, which is correct: the installed tree changed too.
- **The notice is injected once per context window (main conversation and each subagent
  that touches a tooling path) and again after compaction** → it costs at most 1 KB each
  time. The full file costs tokens only when the model follows the pointer, which is why
  the 80-line target in D4 exists.
- **The model may not follow the pointer** (as in the truncation incident) → the digest
  carries the rules that must not be missed inline, so ignoring the pointer loses detail
  but not the guardrails.

## Migration Plan

1. `claude-session-index`: ship the plugin upstream and pin its `sha` in the marketplace.
2. Land this change. A single `chezmoi apply` then:
   - removes the legacy hooks from all four `settings.json` files
   - renders the plugin, `config.env`, and the tooling context
   - removes `~/.local/bin/claude-tooling-write-guard` and `~/.claude/rules/claude-tooling.md`.
     Chezmoi leaves a target in place when its source file is deleted, so both go into a new
     `home/.chezmoiremove` (none exists yet). `rules/` is symlinked across personas, so
     removing it once covers them all.
   - installs both plugins in every persona
3. Verify on each persona (tasks, group 5). On the MacBook Pro, first finish
   `chezmoi-managed-plugin-marketplace` 3.4–3.6.

**Rollback:** revert the commit and `chezmoi apply`. The old modifier re-adds the hooks to
`settings.json`. Then run `claude plugin uninstall claude-tooling@chezmoi-personal` and
`claude plugin uninstall claude-session-index@chezmoi-personal` in each persona, or the
hooks will run twice.
