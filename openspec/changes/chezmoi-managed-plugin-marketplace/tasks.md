# Tasks for Bring the chezmoi-personal plugin marketplace under chezmoi management

## 1. Relocate the tree

- [x] 1.1 Create `home/dot_local/share/claude-plugins/` and move `.claude-plugin/marketplace.json` → `home/dot_local/share/claude-plugins/dot_claude-plugin/marketplace.json`, and every subdirectory of `plugins/` → `home/dot_local/share/claude-plugins/plugins/` (preserving each plugin's internal structure), applying chezmoi's `dot_` naming attribute to every leading-dot path component — not just the top-level `.claude-plugin/`, but also each plugin's own `.claude-plugin/plugin.json` → `dot_claude-plugin/plugin.json` and `.mcp.json` → `dot_mcp.json` (all 5 local plugins — `aws-local-dev`, `browser-tools`, `fast-filesystem`, `openspec-dashboard`, `serena` — have both). Plugin directory names themselves (`aws-local-dev/`, etc.) stay plain, no `dot_` prefix.
- [x] 1.2 Delete `plugins/basic-memory-workflow/` instead of moving it (dead: no `marketplace.json` entry, only a stray untracked `__pycache__` file)
- [x] 1.3 Confirm `chezmoi execute-template` / `chezmoi apply --dry-run` (or equivalent) would deploy the moved tree to exactly `~/.local/share/claude-plugins/.claude-plugin/marketplace.json` and `~/.local/share/claude-plugins/plugins/...`
- [x] 1.4 Rename `marketplace.json` → `marketplace.json.tmpl`; replace `owner.name` (`"Craig Earley"`) with `{{ .fullname }}` and `owner.email` (`"craig@craigearley.software"`) with `{{ .gh_commit_email }}`, quoted correctly for valid JSON output. Leave `owner.url` hardcoded (see design.md Decision 7).
- [x] 1.5 Rename each of the 5 local `plugin.json` → `plugin.json.tmpl` (`aws-local-dev`, `browser-tools`, `fast-filesystem`, `openspec-dashboard`, `serena`); replace each `author.name`/`author.email` the same way
- [x] 1.6 `chezmoi execute-template` both file types and confirm valid JSON output, with `name` rendering to `Craig Earley` and `email` rendering to `cearley@users.noreply.github.com` (the current `.gh_commit_email` value — not the old hardcoded `craig@craigearley.software`, see design.md Decision 7)

## 2. Wire up declaration and registration

- [x] 2.1 Add `~/.local/share/claude-plugins` (or its templated/expanded equivalent — see design.md Decision 2) as a new entry in `packages.darwin.ai.agents.claude_code.plugin_marketplaces` in `home/.chezmoidata/packages.yaml`
- [x] 2.2 Fix `run_onchange_after_darwin-39-install-claude-plugins.sh.tmpl` so this entry resolves to an absolute path correctly under each persona's environment (resolve the single-quoting issue identified in design.md Decision 2)
- [x] 2.3 Delete `run_onchange_after_darwin-44-register-claude-plugin-marketplace.sh.tmpl`

## 3. Migrate already-registered machines

This has to be repeated per machine — chezmoi's own `home/` content propagates via `chezmoi apply`, but each machine's live Claude Code state (marketplace registration, `enabledPlugins`) is local, not chezmoi-managed. See the basic-memory note [[Auditing and Removing the basic-memory-workflow Plugin]] (`chezmoi/reference/auditing-and-removing-the-basic-memory-workflow-plugin`) — same shape of problem, solved before for the `basic-memory-workflow` plugin deprecation. Its two lessons carried over into the steps below: **don't hardcode the persona list** (enumerate via `ls -d ~/.claude*` on the machine actually being migrated — it may not match another machine's set), and **cross-check raw `settings.json`, not just `claude plugins marketplace list`** (a stray `enabledPlugins` entry can exist independent of what the CLI reports as cached).

### Mac Studio (done this session)
- [x] 3.1 For each local persona (`default`, `personal`, `work`, `bedrock`), run `CLAUDE_CONFIG_DIR=<dir> claude plugins marketplace remove chezmoi-personal` to clear the old source-tree-path registration before the new declared entry is added
- [x] 3.2 Run the updated darwin-39 script (or a full `chezmoi apply`) and confirm `claude plugins marketplace list` shows `chezmoi-personal` registered at the new `~/.local/share/claude-plugins` path for every persona
- [x] 3.3 Verify previously-enabled plugins (e.g. whatever is currently enabled via `<plugin>@chezmoi-personal` in any persona's `settings.json`) still resolve correctly post-migration — don't just assume the name match is sufficient

### MacBook Pro (pending — do on that machine)
- [ ] 3.4 `git pull` (or equivalent) to bring this change's commits to the MacBook Pro, then enumerate that machine's actual personas with `ls -d ~/.claude*` — don't assume it's the same four as the Mac Studio
- [ ] 3.5 For each persona found, check both `CLAUDE_CONFIG_DIR=<dir> claude plugins marketplace list --json | jq '.[] | select(.name=="chezmoi-personal")'` (old-path registration to remove) and `jq '.enabledPlugins // empty' <dir>/settings.json` (raw cross-check per the linked note) before running `claude plugins marketplace remove chezmoi-personal` on any persona that has the old registration
- [ ] 3.6 Run `chezmoi apply` (interactive terminal — KeePassXC needs a real TTY there, unlike this session) to deploy `~/.local/share/claude-plugins` and trigger the updated darwin-39 script; confirm `chezmoi-personal` is registered at the new path for every persona found in 3.4, and re-check `enabledPlugins` per persona to confirm nothing that was working before is now broken

## 4. Remove the now-unnecessary orphan exception

- [x] 4.1 Remove the `chezmoi-personal`-is-never-an-orphan special case from `home/dot_claude/skills/clean-claude-orphans/scripts/executable_list-claude-orphans.sh.tmpl`
- [x] 4.2 Remove the corresponding rows/notes from `home/dot_claude/skills/clean-claude-orphans/SKILL.md.tmpl`
- [x] 4.5 (found during implementation, not in original scope) `audit-packages`'s `audit_claude_marketplaces` had a genuine bug, independent of declaration status: its installed-side `jq` filter only handled `.source == "github"` (→ `.repo`) or fell through to `.url`, but a directory-sourced marketplace (`.source == "directory"`) has neither — only `.path` — so it always produced the literal string `"null"`, which is what the old "null"-skip hack in `clean-claude-orphans` was actually working around. Declaring `chezmoi-personal` alone would not have fixed this. Fixed the jq filter to read `.path` for directory sources, and added a `$HOME` expansion on the declared-side (packages.yaml's `$HOME/.local/share/claude-plugins` is a literal string — chezmoi can't expand it since packages.yaml is static data, so the script expands it via a real shell `sed` substitution at invocation time instead) so the two sides compare as equal absolute paths. Deployed directly to `~/.local/bin/audit-packages` (same no-`chezmoi-apply` workaround as task 3.2).
- [x] 4.3 Run `audit-packages` (or the underlying orphan script) and confirm `chezmoi-personal` no longer appears in `## orphans` and isn't relying on any special-case skip — confirmed: `## Claude Code Plugin Marketplaces` now reports "No orphans" (previously always printed a `null` line, see 4.5)
- [x] 4.4 (found during implementation, not in original scope) `home/dot_claude/rules/claude-tooling.md.tmpl`'s "Two Deliberately Different Install Models" section still described the pre-migration model (old repo-root paths, darwin-44, "deliberately not-chezmoi-managed") — updated to match, and the deployed `~/.claude/rules/claude-tooling.md` re-rendered and copied into place directly (chezmoi apply unusable here — see task 3.2's note)

## 5. Spec updates

- [x] 5.1 Write the `claude-plugin-marketplace` spec delta in this change's `specs/claude-plugin-marketplace/spec.md` (MODIFIED: "Marketplace source is a plain local path, not a published repo"; MODIFIED: "Marketplace registration is chezmoi-bootstrapped and idempotent"; REMOVED: "Marketplace and plugin content are not chezmoi-templated"; ADDED: its replacement allowing templating)
- [x] 5.2 `openspec validate chezmoi-managed-plugin-marketplace --strict` and fix anything it flags

## 6. Verification

- [x] 6.1 Confirm `home/.chezmoiscripts/` still has no duplicate script-position numbers after deleting darwin-44
- [x] 6.2 Confirm every existing marketplace.json entry (all 10 — 5 local, 5 re-pointers) is present at the new location with unchanged structure/fields — `owner`/`author` `name`/`email` are now template expressions rather than literal strings (tasks 1.4–1.6), everything else byte-identical
- [x] 6.5 Grep the committed `home/dot_local/share/claude-plugins/` tree for `Craig Earley` and `craigearley.software` and confirm zero matches — the point of tasks 1.4–1.6
- [x] 6.3 `chezmoi diff` (or `chezmoi status`, given the no-TTY limitation) reviewed before `chezmoi apply` on the primary machine — neither is runnable in this sandboxed session (both hit the KeePassXC/no-`/dev/tty` limitation, not just `diff` as CLAUDE.md documents — `status` does too, since it also renders the full source tree). Substituted `git status --porcelain` + `git diff --stat` over every touched file as the review; a real `chezmoi status`/`diff`/`apply` still needs to run in an interactive terminal.
- [x] 6.4 Full `audit-packages` run shows no new orphans introduced by the move — confirmed: `## Claude Code Plugin Marketplaces` reports "No orphans"; all other orphan categories in the full run (Homebrew, UV tools, other Claude plugins/skills) are pre-existing drift unrelated to this change
