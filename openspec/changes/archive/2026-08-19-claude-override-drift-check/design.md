## Context

See `proposal.md` - Why for motivation. Relevant existing pieces this design builds on:

- `home/dot_local/bin/executable_claude-tooling-guard.tmpl`: the established pattern for a
  PATH-deployed executable rendered directly by chezmoi (no separate symlink file) in this
  exact directory — `check-claude-overrides` follows it, not `audit-packages.sh`'s
  symlink-into-the-source-tree pattern, since `home/scripts/` (where `audit-packages.sh`
  lives) is excluded from chezmoi rendering entirely (`home/.chezmoiignore.tmpl` has
  `scripts/`) and this script needs render-time template logic that pattern can't provide.
- `home/dot_claude/skills/clean-claude-orphans/scripts/executable_list-claude-orphans.sh.tmpl`:
  the sectioned-TSV output convention (`## section-name` header, tab-separated rows, empty
  section when nothing to report) this change also reuses.
- `home/.chezmoitemplates/machine-settings`: resolves this machine's `config.yaml` entry
  (via `machine-config`'s hostname/pattern matching) and returns it as a JSON-encoded
  string — its own doc comment shows the call site needs `| fromJson` before indexing it.
  `claude_envs` (used elsewhere by `darwin-38`/`-39`/`-44`'s `{{ range $claudeEnvs }}`) comes
  from this.
- `home/dot_claude-<name>/modify_settings.json.tmpl` (one per persona, plus the unnamed
  default's `home/dot_claude/modify_settings.json.tmpl`): each computes an `$extra` Go
  `dict(...)` and passes it to `includeTemplate "claude-settings-hooks-modifier"` as
  `claudeExtraSettings`.
- `home/.chezmoitemplates/claude-settings-hooks-modifier`: the shared partial that renders
  `extra_settings='{{ get . "claudeExtraSettings" | default (dict) | toJson }}'` into the
  bash script chezmoi runs as the `modify_` step — i.e. it already turns the Go-template
  dict into a JSON literal, chezmoi just never persists that intermediate output anywhere.

## Goals / Non-Goals

**Goals:**
- Derive each persona's real intended `skillOverrides`/`enabledPlugins` baseline without
  reimplementing a Go-template-dict parser.
- Keep the script a drop-in peer of `audit-packages`/`list-claude-orphans.sh` so it composes
  the same way (manual run, shelled out to by a skill, read directly by an agent).

**Non-Goals:**
- Resolving the "drop the override" direction automatically (see proposal.md - Non-goals) —
  that remains the existing manual `/skill`/`/plugin` command.
- Scaffolding a brand-new `$extra`/`claudeExtraSettings` dict (or a missing
  `skillOverrides`/`enabledPlugins` sub-dict) for a persona that has none yet — `--fix`
  requires the target sub-dict to already exist (see Decisions below).

## Decisions

**Baseline extraction: render-and-grep the template, don't parse the source `dict(...)`.**
Alternatives considered: (a) regex/awk over the `.tmpl` source's Go `dict(...)` calls —
rejected, brittle against any reformatting of the template and duplicates parsing logic
chezmoi itself already has; (b) maintain a parallel plain-JSON baseline file next to each
`modify_settings.json.tmpl` — rejected, that's a second source of truth for the same data,
exactly the kind of drift this change exists to catch elsewhere. Chosen approach: run
`chezmoi execute-template < home/dot_claude-<name>/modify_settings.json.tmpl`, which
produces the same bash script chezmoi would actually apply, then extract the
`extra_settings='...'` JSON literal from it with a stable prefix match. This always reflects
exactly what `chezmoi apply` would write, because it *is* chezmoi's own rendering pipeline.

**`check-claude-overrides` is a chezmoi-rendered executable
(`home/dot_local/bin/executable_check-claude-overrides.tmpl`), deployed directly to
`~/.local/bin/check-claude-overrides` — not a plain script reached via a symlink into the
source tree.** `home/scripts/` (where `audit-packages.sh` lives) is excluded from chezmoi
rendering entirely (`home/.chezmoiignore.tmpl` has `scripts/`), which is exactly why
`audit-packages.sh` is a plain, non-templated file there, reachable only via
`symlink_audit-packages.tmpl`'s `{{ .chezmoi.sourceDir }}` pointer. That pattern doesn't fit
this script: it needs machine-specific data (the persona list) resolved through template
logic, which a file chezmoi never renders can't have. `home/dot_local/bin/` already holds a
script with exactly this shape — `executable_claude-tooling-guard.tmpl` — rendered directly
by chezmoi on every `chezmoi apply`, no symlink involved. `check-claude-overrides` follows
that precedent instead.

**Both the persona list and every chezmoi-source path are baked in as literal strings at
`chezmoi apply` render time — not resolved, discovered, or re-derived at runtime.** Because
the script is rendered (not merely symlinked), `{{ range $claudeEnvs }}` (from
`includeTemplate "machine-settings" . | fromJson`) can build the persona-name, live-config-dir,
and source-template-path arrays directly as bash array literals, and `{{ .chezmoi.sourceDir }}`
can be written straight into `PACKAGES_YAML`/`NATIVE_SKILLS_DIR`/each persona's template
path. An earlier iteration of this design instead had the script shell out to `chezmoi
execute-template` *at runtime* to re-resolve `claude_envs` on every invocation, reasoning that
"always reflects the machine's current config" was more correct than a value baked in at the
last `chezmoi apply` — that reasoning didn't hold up under scrutiny: `claude_envs` is genuinely
static machine configuration (it only changes when the user edits `config.yaml` and runs
`chezmoi apply`, and that same apply is what provisions the corresponding persona's
`~/.claude-<name>/` directory in the first place), so baking it in is not just simpler, it
matches the exact freshness model `darwin-38`/`-39`/`-44` already rely on for the same data,
and it eliminates an entire runtime subprocess-with-inline-heredoc-template mechanism along
with the self-location logic (`realpath "${BASH_SOURCE[0]}"`/`SCRIPT_DIR`) that pattern would
otherwise have required. Baseline extraction (below) is the one piece that genuinely still
needs to happen at runtime, since a persona's `modify_settings.json.tmpl` *content* — and the
live `settings.json` it's compared against — really can change without a `chezmoi apply`
having run. The unnamed default (`~/.claude` → `home/dot_claude/modify_settings.json.tmpl`)
is always the first baked-in entry, independent of `claude_envs`. A directory that exists on
disk but isn't in `claude_envs` (e.g. a stale rename leftover) is correctly never baked in,
matching how the rest of the deploy pipeline already treats `claude_envs` as authoritative.
Across this entire change, `{{ .chezmoi.sourceDir }}` is used in exactly one file — this
script's own template — and never appears as a literal string anywhere in source; the
absolute path only exists in each machine's own rendered, untracked output.

**Declared-plugin reference reads `packages.yaml` directly, not `audit-packages`' output.**
`audit-packages`/`list-claude-orphans.sh` report the opposite direction
(installed-but-undeclared); they never surface "declared but currently `false`" comparisons,
so shelling out to them wouldn't provide what this script needs. The script reads
`packages.yaml`'s `claude_code.plugins` list directly (same file, independent read).

**Output has no `shared-utils.sh` dependency.** `audit-packages` uses
`print_message`/colorized human-facing output because a human reads it interactively.
This script's primary consumers are `clean-claude-orphans` and an agent following
`claude-tooling.md` — both want plain parseable TSV, matching `list-claude-orphans.sh`'s
existing convention rather than `audit-packages`'s.

**`--fix` writes a single, live-value-sourced entry, verified via a temp-file render before
touching the real source.** `modify_settings.json.tmpl` isn't JSON — it's a hand-formatted Go
`dict(...)` literal — so a general-purpose structural editor is out of scope for what this
change needs. Instead: `--fix <persona> <skillOverrides|enabledPlugins> <key>` takes no
`<value>` argument — it re-runs drift detection scoped to that one entry (refusing if it
isn't currently flagged, so a stale or already-resolved invocation errors instead of
silently no-oping or double-writing) and reads the value to codify directly from the
persona's live `settings.json`, so the written value can never diverge from what's actually
in effect. The insertion point is anchored on the `"skillOverrides" (dict` /
`"enabledPlugins" (dict` opener line, inserting the new `"<key>" <value>` line immediately
after it — not before the sub-dict's closing paren, which would require matching balanced
parens across a hand-formatted, variably-indented block. The edit is made on a copy of the
file first; that copy is rendered with `chezmoi execute-template` and its extracted
`extra_settings` JSON is checked for the new key/value before the real file is overwritten.
If the target sub-dict (or the whole `$extra` dict) doesn't exist in that persona's template
at all, `--fix` errors out pointing at a one-time manual bootstrap rather than attempting to
synthesize Go-template structure — considered and rejected as materially more edit-surface
and risk for a case that affects only 2 of the 4 current personas today.

**Scope is `skillOverrides` + `enabledPlugins` only.** `disabledMcpServers` is intentionally
not chezmoi-managed (see Chezmoi Current Status environment facts) and is out of scope per
proposal.md - Non-goals; adding it later is a separate, additive change if ever needed.

## Risks / Trade-offs

- **[Risk]** The `extra_settings='...'` extraction is a textual match against
  `claude-settings-hooks-modifier`'s rendered output; if that partial's variable name or
  quoting style ever changes, extraction could silently break.
  **Mitigation:** match on the stable `extra_settings='` prefix and fail loudly (non-zero
  exit, stderr error) rather than falling back to an empty baseline — a parse failure must
  never be interpreted as "no baseline entries," since that would mask real drift as clean.
- **[Risk]** Because the persona list is baked in at render time, the deployed script goes
  stale relative to `config.yaml` until the next `chezmoi apply` (e.g. a `claude_envs` entry
  added but not yet applied on this machine).
  **Mitigation:** accepted, and not a new class of staleness — the same is true of every
  other chezmoi-rendered executable in this repo (`claude-tooling-guard` included), and a
  newly-added persona wouldn't have a provisioned `~/.claude-<name>/` directory or baseline
  to check yet anyway until that same `chezmoi apply` runs.
- **[Risk]** Baseline extraction (rendering each persona's `modify_settings.json.tmpl` at
  runtime, per invocation) and reading `packages.yaml`/live `settings.json` still depend on
  `chezmoi`, `jq`, and `yq` being on `PATH` — same class of dependency `audit-packages.sh`
  already has on `chezmoi data --format=json`, not new exposure.
  **Mitigation:** fail with a clear error (matching `audit-packages`' own "X is required but
  not found in PATH" handling) rather than silently reporting no drift.
- **[Risk]** `claude_envs` declares a persona whose `home/dot_claude-<name>/` source
  directory doesn't actually exist yet (a genuine chezmoi-source inconsistency — every
  currently-declared persona already has one, but nothing enforces this).
  **Mitigation:** covered by the spec's "Missing-Baseline Graceful Skip" requirement — an
  explicit skip notice to stderr, not a silent false-negative or a hard crash. A stale
  filesystem directory *not* in `claude_envs` (e.g. `~/.claude-old` left over from a rename)
  is simply never examined — out of scope by design, not a risk needing mitigation, since
  `claude_envs` is treated as authoritative the same way it already is elsewhere.
- **[Risk]** Rendering every persona's template on every invocation costs a few subprocess +
  template-parse round trips.
  **Mitigation:** acceptable — this is an on-demand diagnostic, not a `chezmoi apply`-time
  hook, so there's no latency budget to protect.
- **[Risk]** `--fix` writes to a tracked chezmoi source file — a bug in the anchor-matching
  insertion logic could corrupt a hand-maintained template that four personas depend on.
  **Mitigation:** the temp-file-render-and-verify step means a broken insertion never reaches
  the real file — verification happens before the overwrite, not after, so there's nothing to
  roll back. The existing git workflow (nothing auto-committed; the user reviews `git diff`
  before ever committing) is the remaining safety net for a change that passes verification
  but still isn't what the user wanted.
- **[Risk]** Reading the value to write from the live `settings.json` instead of accepting it
  as an argument removes a class of typo bugs, but means `--fix`'s behavior depends on
  `check-claude-overrides`' own detection logic being correct — a false-positive drift report
  would get faithfully codified into the template.
  **Mitigation:** the re-check-before-write step (refuse if not currently flagged) is the
  same detection path a human already reviewed in the plain (no-flag) output before deciding
  to run `--fix`, so this isn't new exposure beyond trusting the detection logic in the first
  place.
