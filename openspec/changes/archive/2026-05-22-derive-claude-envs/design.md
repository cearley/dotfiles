## Context

The `claude-environments` partial at `home/.chezmoitemplates/claude-environments` is the single source of shell wiring for Claude Code multi-environment support, included by both `dot_zshrc.tmpl` and `dot_bashrc.tmpl`. It currently hardcodes three pieces of per-env logic:

1. Three function definitions: `claude-bedrock`, `claude-personal`, `claude-work`.
2. Three `*-spec` aliases: `claude-bedrock-spec`, `claude-personal-spec`, `claude-work-spec`.
3. The `claude-env` switcher's `case "$1" in work|personal|bedrock)` pattern and its usage string.

Meanwhile `home/.chezmoidata/config.yaml` already lists `claude_envs` per machine (e.g., `MacBook Pro` has `[~/.claude-bedrock, ~/.claude-personal, ~/.claude-work]`; `Mac Studio` has `[~/.claude-personal, ~/.claude-work]`). That list is consumed by `run_onchange_after_darwin-37-install-claude-skills.sh.tmpl` and `run_onchange_after_darwin-38-install-claude-plugins.sh.tmpl` to install skills and plugins per env.

The partial does not consult `claude_envs`. Three drift modes exist:
- `claude_default` typo or pointing at an env not in `claude_envs` (silent — LaunchAgent sets `CLAUDE_CONFIG_DIR` to a never-provisioned path).
- `claude-env <name>` accepting a name that isn't in `claude_envs` (silent — exports a path to a non-existent directory).
- The hardcoded function/alias triplet diverging from `claude_envs` when a fourth env (e.g., `claude-school`) is added.

The `claude-environments` capability spec at `openspec/specs/claude-environments/spec.md` currently has explicit per-name scenarios (one each for bedrock, personal, work).

## Goals / Non-Goals

**Goals:**
- Make `claude_envs` the single source of truth for which Claude environments exist on a machine.
- Generate per-env shell functions, `*-spec` aliases, and the `claude-env` case statement from `claude_envs` at template-render time.
- Validate `claude_default ∈ claude_envs` at template-render time so a typo blocks `chezmoi apply` instead of silently setting `CLAUDE_CONFIG_DIR` to a stale path.
- Validate that every `claude_envs` entry matches the `~/.claude-<name>` path convention.
- Preserve existing behavior on machines that still match the `bedrock|personal|work` shape; introduce no behavior change for those machines.

**Non-Goals:**
- Making `prompt_claude_env` colors data-driven. New env names render in p10k color 244 (grey). A follow-up may shape `claude_envs` as a list of `{path, color}` objects.
- Detecting that an env listed in `claude_envs` lacks a `~/.claude-<name>` directory on disk. Existing install scripts already skip missing directories silently; this change does not add a separate provisioning check.
- Templating non-env-specific aliases (`claude-spec`, `codex-spec`, `gemini-spec`, `openspecui`).
- Changes to `dot_p10k.zsh`, the LaunchAgent plist, or any chezmoi script.

## Decisions

### Decision 1: Single source of truth is `claude_envs`, with a strict path convention

`claude_envs` is a list of paths in the shape `~/.claude-<name>`. Names are derived by trimming the `~/.claude-` prefix.

**Why:** Two readable conventions are simpler than one machine and one human convention. Today's data already conforms.

**Alternatives considered:**
- Add a separate `claude_env_names` list. *Rejected:* introduces a second list that can drift from `claude_envs`.
- Treat `claude_envs` as opaque paths and look up directories at runtime. *Rejected:* defers the validation surface to shell init, where errors are quieter and don't block apply.

### Decision 2: Validation fires at template-render time

The partial fails — using `fail` in a Go template — when:
- Any `claude_envs` entry does not start with `~/.claude-`.
- `claude_default` is set and does not equal `claude-<name>` for some `<name>` derived from `claude_envs`.

`chezmoi apply`, `chezmoi diff`, and `chezmoi cat` all error with a precise message naming the offending key and value.

**Why:** Catches the typo at the point of editing, before the LaunchAgent script runs and exports `CLAUDE_CONFIG_DIR` to a stale path. The same render is reused by both rc templates and any test invocation, so the check runs in every code path that touches the partial.

**Alternatives considered:**
- Fail in the LaunchAgent script (`run_onchange_after_darwin-39-load-claude-launchagent.sh.tmpl`). *Rejected:* leaves `dot_zshrc.tmpl` rendering successfully with stale aliases on a partially failed apply. Template-time fail catches all code paths uniformly.
- Belt-and-suspenders (template-time fail + script-time print). *Rejected:* the template-time check is unconditional; redundancy adds complexity without value.

### Decision 3: Case statement and usage are generated from derived names

The `claude-env` function's `case "$1" in <names>)` and `Usage: claude-env [<names>]` strings are rendered with `{{ join "|" $envNames }}` and `{{ join "|" $envNames }}` respectively.

**Why:** A single derivation produces both the accept-list and the human-facing usage message. Cannot drift.

**Alternatives considered:**
- Validate at runtime by checking `[ -d "$HOME/.claude-$1" ]`. *Rejected:* does not gracefully reject a typo like `claude-env wrok` — it just fails with a confusing "directory not found" instead of "valid: bedrock|personal|work". Generated case statements give a precise list back.

### Decision 4: Empty `claude_envs` on an `ai`-tagged machine is allowed

The partial renders no per-env wrappers. The `claude-env` switcher's case statement is rendered with no name branches; the `*)` arm prints `Usage: claude-env []` (literal empty brackets) and returns 1.

**Why:** A machine with `ai` tag but `claude_envs: []` is a valid configuration (e.g., a fresh setup that hasn't decided on envs yet). The partial should not crash.

**Alternatives considered:**
- Fail at template-render time when `claude_envs` is empty on an `ai` machine. *Rejected:* punishes the empty-list case more harshly than the typo case, with no real benefit.

### Decision 5: `*-spec` aliases per-env are generated; non-env aliases stay hardcoded

`claude-<name>-spec` is generated for each `<name>` in `claude_envs`. `claude-spec`, `codex-spec`, `gemini-spec`, and `openspecui` remain hardcoded.

**Why:** The non-env aliases are not parameterized by `claude_envs` — they wrap different binaries or are environment-agnostic.

## Risks / Trade-offs

- **[Risk]** A user adds a new env to `claude_envs` and expects color coding in `prompt_claude_env`. **Mitigation:** New envs render in grey 244 with the basename verbatim. Documented in proposal as out-of-scope. Color is functional; only aesthetic suffers until a follow-up adds per-env colors.
- **[Risk]** `fail` template error messages on typo could be cryptic across `chezmoi diff` invocations from non-interactive contexts. **Mitigation:** Error message includes the key name (`claude_default` or `claude_envs`), the offending value, and the derived list — readable in any `chezmoi` output.
- **[Risk]** Generated functions/aliases produce subtly different shell formatting than the hardcoded versions, breaking shell-init in an unforeseen way. **Mitigation:** Render output via `chezmoi execute-template` and diff against current `dot_zshrc` / `dot_bashrc` rendering for MacBook Pro (where the env set is identical) to confirm byte-equivalent or trivially-equivalent output. Verify on Mac Studio that `claude-bedrock` and `claude-bedrock-spec` are absent.
- **[Trade-off]** Template logic gets denser. The partial gains a guard block (~10 lines) and three `range` loops replace nine static lines. Net: roughly the same line count, more conditional density. The benefit — single source of truth and fail-fast validation — outweighs the readability cost.

## Migration Plan

1. Implement the partial changes and validation guard.
2. On the development machine (MacBook Pro), run `chezmoi diff` for `~/.zshrc` and `~/.bashrc`. Expected: no functional change in rendered output.
3. Render the partial for `Mac Studio` via `chezmoi execute-template` with appropriate machine-name override; confirm `bedrock` no longer appears.
4. Test the typo case: temporarily set `claude_default: claude-wrok` in `config.yaml` on a scratch branch, run `chezmoi diff`, confirm the apply fails with a precise error message, revert.
5. Apply on each machine.

**Rollback:** revert the partial change. The previous version of `claude-environments` is hardcoded and matches today's `claude_envs` content for all known machines.

## Open Questions

None. All decisions made during brainstorming.
