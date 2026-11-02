## Context

Surfaced during a domain-driven-design-style review of this repo's terminology (the kind that
asks "if a concept is hard to name, or has two names, the model is probably wrong"). "Persona"
denotes a named Claude Code config directory, but the word already has a strong, different
meaning in UX/product work (a fictional user archetype), and this repo's own upstream plugin
(`zsh-claude-env`) already uses "environment" for the live, switchable instance of the same
directory concept. Two names already exist for closely related ideas in the same system;
adding a third reading of "persona" on top makes the collision worse, not better.

## Goals / Non-Goals

**Goals:**
- One consistent term, "profile", for "a named config directory for an AI coding agent CLI,
  with its own settings/hooks/overrides" — Claude Code is the only instance this change
  touches, but the term is chosen so that adding another agent CLI later doesn't force a third
  rename. Replacing "persona" everywhere it currently appears as prose, an identifier, or a
  filename.
- Zero behavior change. This is a rename, not a redesign: every rendered script's logic,
  array contents, and control flow stay identical; only names and prose change.
- A clean handoff point: after this change, `GLOSSARY.md`'s `persona` entry becomes a
  `profile` entry, and the repo has no remaining "persona" occurrence outside
  `openspec/changes/archive/**`.

**Non-Goals:**
- Not touching `claude_envs`/`$claudeEnvs` or any "environment" terminology — see Decisions
  below for why that boundary is deliberate, not an oversight.
- Not renaming the on-disk `dot_claude-<name>` directories — their name is the profile's role
  (`personal`, `work`, `bedrock`), never the literal word "persona".
- Not changing `check-claude-overrides`'s `--fix` flag name, drift-detection semantics, or any
  other script's actual behavior.

## Decisions

### New term: "profile", not "environment" or "context"
"Environment" was considered and rejected — it's already taken by `claude_envs` and the
`claude-environments` spec, which describe the *active, switchable* runtime binding (which
`CLAUDE_CONFIG_DIR` a given shell currently has). Reusing it for the *static config bundle*
would recreate the exact two-names-one-concept problem this change exists to fix, just with
the collision pointed the other way. "Context" was also considered and rejected — it's already
established OMC/agent-orchestration jargon in the user's global tooling (`CLAUDE_CONFIG_DIR`-
adjacent but conceptually different: "context" there means conversation/session state, not a
settings bundle). "Profile" is unclaimed in this repo and is the standard term for this exact
shape elsewhere (AWS CLI profiles, browser profiles, shell profiles).

### Term choice checked against other agent CLIs, not just this repo
Before committing to "profile", the six other agent harnesses this user is likely to manage
with chezmoi were checked for an equivalent concept: Codex, Gemini CLI, Copilot CLI, opencode,
`pi`, and `omp`. Four of the six (Claude Code, Codex, Gemini CLI, Copilot CLI) share the exact
mechanism this repo already exploits — one environment variable (`CLAUDE_CONFIG_DIR`,
`CODEX_HOME`, `GEMINI_CLI_HOME`, `COPILOT_HOME`) relocates one config directory — which means
"profile" names the same shape in all four without strain. `omp` independently has a *native*
`--profile <name>` flag with isolated per-profile state, which is direct outside confirmation
that "profile" is the word this category of tool reaches for on its own. `opencode` breaks the
single-directory symmetry (it splits config into `OPENCODE_CONFIG_DIR` and auth/data into
`XDG_DATA_HOME`), and `pi` has no native directory-redirect lever at all — third-party overlay
tools (`pi-harness-factory`, `Outfitter`) call their own concept "profile" too, but implement it
as named config files, not a directory swap. Neither of those two changes the term choice; they
change what *implementing* a profile would mean for that specific tool, which is deferred to the
separate `generalize-agent-profile-management` proposal.

The one real naming risk surfaced: Codex's `config.toml` already has its own `[profiles.<name>]`
concept for model/approval presets, selected via `--profile`, which is a *different* thing from
account/directory switching. If Codex support is ever built, "a Codex profile" will be
ambiguous between "which `CODEX_HOME` directory" (this repo's concept) and "which
`[profiles.name]` preset" (Codex's own concept) unless that future change disambiguates
explicitly (e.g. by always saying "chezmoi profile" or "account profile" in Codex-facing docs).
This is documented here as a known edge case to carry forward, not a reason to pick a different
word now — no alternative considered (environment, context, identity, account, workspace, home,
instance) avoided every existing collision in this repo and the wider landscape as cleanly as
"profile" does; most either recreated the "environment" collision this change already fixes, or
collided with something else already established here (e.g. "home" clashes with this repo's own
`home/` chezmoi-source-root convention, "workspace" is already OMC/basic-memory jargon).

### `claude_envs`/`$claudeEnvs` stay as-is
The config key `claude_envs` and its template variable `$claudeEnvs` are consumed by two
different downstream concerns: the `claude-environments` spec (shell switching, legitimately
"environment"-flavored) and the profile-auditing scripts this change renames (`persona` →
`profile`). Both concerns read the same underlying list, but each already has its own
consumer-level vocabulary layered on top (`$claudeEnvs` feeds `$personas` in
`check-claude-overrides` et al., which this change renames to `$profiles`). Renaming
`claude_envs` itself would touch the `claude-environments` spec's own correct terminology and
expand this change's blast radius for no benefit — the boundary mirrors this repo's own
precedent in `dedupe-persona-list-template`, whose non-goals explicitly excluded changing how
`claude_envs` is declared.

### Template rename: `persona-list` → `profile-list`
The shared template added by `dedupe-persona-list-template` resolves `claude_envs` into a
JSON array of `{name, dir, baseline}` objects — exactly the "profile" concept this change
renames. Its five call sites (`check-claude-overrides`, `uninstall-claude-plugin-everywhere`,
`audit-claude-code.sh`, the darwin-44 migration script, `claude-tooling-write-guard`) are
updated in lockstep; the object shape (`{name, dir, baseline}`) is unchanged.

### Identifier naming scheme
Straight word substitution, preserving each identifier's existing case convention:
`PERSONA_*` → `PROFILE_*`, `$personas`/`$persona` → `$profiles`/`$profile`,
`detect_persona_drift` → `detect_profile_drift`, `resolve_current_persona_index` →
`resolve_current_profile_index`, `$personaList` → `$profileList`, `CLAUDE_PERSONA_DIRS` →
`CLAUDE_PROFILE_DIRS`. No identifier is restructured beyond the word swap — this keeps the
diff reviewable as "rename only."

### Verification approach differs from the `keepassxc_entries` rename precedent
That rename required byte-identical rendered *values* before/after, because only an internal
key name changed and no user-visible text was supposed to move. Here, the visible text is the
point of the change (e.g. `--fix <persona>` → `--fix <profile>` in help output, comments,
error messages), so "byte-identical" isn't the right bar. Instead, each changed `.tmpl` file
must still render without error, and a before/after diff must show *only* persona→profile
substitutions — no incidental logic or value changes.

## Risks / Trade-offs

- **[Risk]** Wide, shallow surface (~20 files, 9 specs) makes it easy to miss one occurrence,
  leaving a stray "persona" that now disagrees with everything around it — arguably worse than
  the pre-change state, since it signals an incomplete rename rather than a deliberate one.
  → **Mitigation**: the verify task runs a repo-wide `grep -rlw "persona\|personas\|PERSONA"`
  across `home`, `CLAUDE.md`, `GLOSSARY.md`, and `openspec/specs`, which must return zero,
  before this change is archived.
- **[Risk]** `check-claude-overrides --fix <persona> ...` is documented, muscle-memory
  invocation syntax; changing the placeholder text in help output could read as a flag rename
  to a skimming user. → **Mitigation**: the actual flag (`--fix`) and argument *order* are
  unchanged — only the human-readable placeholder name changes. Tasks.md calls this out
  explicitly so it isn't mistaken for a breaking CLI change.
- **[Trade-off]** Historical openspec changes under `archive/**` keep saying "persona" forever,
  so a future reader skimming old proposals will see both terms depending on which era they're
  reading. Accepted — rewriting history contradicts this repo's own archival precedent, and the
  dates on archived changes make the terminology shift self-explanatory.
