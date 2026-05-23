## Context

`home/.chezmoitemplates/claude-environments` is the single source of Claude shell wiring. After the `derive-claude-envs` change, it generates per-env base functions (`claude-<name>`) and per-env spec wrappers (`claude-<name>-spec`) by ranging over `claude_envs`. The base functions are shell functions; the spec wrappers are shell aliases. The non-env wrappers (`claude-spec`, `codex-spec`, `gemini-spec`) are also aliases.

Aliases differ from functions in three ways relevant here:
1. **Non-interactive expansion**: bash with `expand_aliases` off (the default for `bash -c`, scripts, and cron) does not expand aliases. `bash -c 'claude-work-spec'` fails today. Functions are sourced by `~/.bashrc` only when bash is interactive — but they remain available within any shell that did source them. More importantly, when sourced in a chezmoi-managed environment, *function* definitions resolve uniformly under `bash -i`, `bash -l`, and zsh; alias definitions only resolve under interactive shells.
2. **Introspection**: `type claude-work` says "function"; `type claude-work-spec` says "alias". `which`, `command -V`, and shell completion treat each differently.
3. **Argument forwarding**: aliases work by textual substitution (the alias body is prepended to whatever the user typed), so `claude-work-spec --resume` becomes `CLAUDE_CONFIG_DIR=... specstory run claude --no-cloud-sync --resume`. Functions forward arguments only via explicit `"$@"`.

Today the alias-based forwarding works because the shell concatenates. Converting to functions requires replicating that with `"$@"` to preserve `claude-work-spec --resume` behavior.

## Goals / Non-Goals

**Goals:**
- Eliminate the asymmetry: every `*-spec` wrapper is defined the same way (function with `"$@"`).
- Close the non-interactive expansion gap so `bash -c 'claude-work-spec ...'` and similar invocations work.
- Preserve all current interactive behavior bit-for-bit (same `CLAUDE_CONFIG_DIR`, same final command line, same exit semantics).

**Non-Goals:**
- Touching `openspecui`. It is an alias for `npx openspecui@latest` and does not need argument forwarding or env injection.
- Touching the per-env base functions `claude-<name>` (already functions).
- Folding multiple wrappers into a parameterized helper. Each wrapper is short; the loop in the template already handles repetition.
- Changing argument-passing semantics. `"$@"` is the only forwarding mechanism — no `--specstory-flag -- claude-flag` two-positional split.

## Decisions

### Decision 1: Use functions with explicit `"$@"` forwarding

```sh
claude-spec() {
    specstory run claude --no-cloud-sync "$@"
}

claude-<name>-spec() {
    CLAUDE_CONFIG_DIR="$HOME/.claude-<name>" \
        specstory run claude --no-cloud-sync "$@"
}

codex-spec() {
    specstory run codex --no-cloud-sync "$@"
}

gemini-spec() {
    specstory run gemini --no-cloud-sync "$@"
}
```

**Why:** functions resolve uniformly across interactive and non-interactive shells (when the relevant rc has been sourced). `"$@"` preserves today's user-facing behavior (`claude-work-spec --resume` still appends `--resume`).

**Alternatives considered:**
- Keep the non-env wrappers as aliases, convert only the per-env ones. *Rejected:* same expansion gap; partial fix.
- Use `eval` inside a function. *Rejected:* unnecessary; `"$@"` is the canonical mechanism and avoids the quoting hazards of `eval`.
- Add a single helper function `_specstory <env_path> <cli> "$@"` and call it from one-line wrappers. *Rejected:* one extra indirection for no real saving — the template `range` already produces uniform output, and the wrappers are easier to read inline.

### Decision 2: Leave `openspecui` as an alias

`openspecui` is `npx openspecui@latest`. It does not interact with `CLAUDE_CONFIG_DIR`, does not accept extra arguments, and is not an AI-CLI wrapper. Converting it for symmetry would only add lines without addressing any real gap.

**Why:** the proposal scope is specifically the SpecStory CLI wrappers and their CLAUDE_CONFIG_DIR / argument-forwarding asymmetry. `openspecui` shares neither concern.

### Decision 3: Preserve `CLAUDE_CONFIG_DIR` inheritance semantics

`claude-spec` (no env) does not set `CLAUDE_CONFIG_DIR`; it inherits from the parent shell. The per-env `claude-<name>-spec` functions set it inline as a single-command-scope assignment (the `VAR=value cmd` form), so the parent shell's `CLAUDE_CONFIG_DIR` is unaffected. This matches today's alias semantics exactly.

**Why:** preserves the contract documented in the existing requirements (default-spec inherits, per-env-spec shadows).

## Risks / Trade-offs

- **[Risk]** Tab-completion of `claude-w<TAB>` may behave differently for functions vs aliases under zsh's `compinit`. **Mitigation:** functions are completed via `_command_names -e` like external commands, which is fine and possibly better than alias completion. Verify post-apply by typing `claude-w<TAB>` in a fresh zsh.
- **[Risk]** A user's downstream override of the form `alias claude-work-spec='...'` placed in a separate rc fragment would be silently ignored when a function of the same name is defined first (functions take precedence over later aliases at lookup time). **Mitigation:** unlikely to exist; `git grep` of the dotfiles repo confirms no such overrides. If one is found later, the override would need to be a function definition instead.
- **[Trade-off]** Five lines per wrapper (function body + closing brace + blank line) instead of one line per wrapper (alias). Total partial line count grows by ~12 lines for an `ai`-tagged machine with three envs. Acceptable: clarity and correctness win over compactness.

## Migration Plan

1. Edit `home/.chezmoitemplates/claude-environments` to replace the four `alias` lines (one for `claude-spec`, the `range`-generated `claude-<name>-spec` block, `codex-spec`, `gemini-spec`) with function definitions, preserving `"$@"` forwarding.
2. Update the spec at `openspec/specs/claude-environments/spec.md`: rename `SpecStory Wrapper Aliases` to `SpecStory Wrappers`, change scenario language from "alias" to "function", add a scenario for argument forwarding.
3. Run `chezmoi diff` for `~/.zshrc` and `~/.bashrc` on the current machine to confirm the rendered output matches expectations.
4. Run `chezmoi apply`, then in a fresh shell verify:
   - `type claude-work-spec` reports "function".
   - `claude-work-spec --version` (or `--help`) forwards the argument.
   - `bash -c 'type claude-work-spec'` reports the function (after `~/.bashrc` is sourced — confirm bash interactivity assumptions).

**Rollback:** revert the partial change. The previous version is one commit back and matches today's runtime behavior for interactive shells.

## Open Questions

None.
