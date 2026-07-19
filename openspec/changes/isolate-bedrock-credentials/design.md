## Context

`home/.chezmoitemplates/claude-environments` generates one `claude-<name>()` shell function per entry in the active machine's `claude_envs`. Today each function is a single static line:

```sh
claude-{{ $name }}() {
    CLAUDE_CONFIG_DIR="$HOME/.claude-{{ $name }}" command claude "$@"
}
```

`~/.claude-bedrock/settings.json`'s `env` block currently carries `AWS_PROFILE` and `AWS_CREDENTIAL_PROCESS` (plus other Bedrock/OTEL config that's staying put). That file's `env` key is passed through untouched by `modify_settings.json.tmpl` → `claude-settings-hooks-modifier` (which only merges the `hooks` key), so it isn't chezmoi-templated content — it's a live, user-edited file.

This repo (`github.com/cearley/dotfiles`) is public and `home/.chezmoidata/config.yaml` is git-tracked, which rules out a data-driven mechanism (like `claude_env_colors`) for personal values such as an AWS profile name or a local credential-process path. The existing `mcp-env-injection` capability already solved this exact problem for MCP servers: untracked, user-managed `~/.config/mcp-env/<server-name>.env` files sourced right before `exec`.

## Goals / Non-Goals

**Goals:**
- Every `claude-<name>()` function optionally sources `~/.config/claude-env/<name>.env` before invoking `claude`, with no effect when the file is absent.
- Sourced variables apply only to that one `claude` invocation — they must not leak into the interactive shell that called the function.
- No new value (profile names, credential-process paths) is ever written into chezmoi source state or any git-tracked file.
- `AWS_PROFILE` and `AWS_CREDENTIAL_PROCESS` move out of `~/.claude-bedrock/settings.json`'s `env` block into `~/.config/claude-env/bedrock.env`.

**Non-Goals:**
- Reusing `mcp-env-wrapper` itself or its `~/.config/mcp-env/` namespace — that capability's spec scopes `<server-name>` to MCP config keys specifically; conflating it with Claude environment names would blur two distinct concerns.
- Process-tree isolation *within* a single `claude` invocation (e.g., preventing a Bash tool call made by that Claude session from seeing `AWS_PROFILE`). Normal Unix env inheritance still applies once `claude` itself is running; the goal is keeping these values out of a persisted config file, not sandboxing the running session.
- Migrating the rest of `~/.claude-bedrock/settings.json`'s `env` block (region, model overrides, OTEL settings) — those stay exactly where they are.
- A general secrets manager or validation/linting of env file contents.

## Decisions

**Decision: subshell + `source` + `exec`, not inline `VAR=val` prefixes**
The existing per-function pattern (`CLAUDE_CONFIG_DIR="..." command claude "$@"`) works because the variable name and value are both known at template-render time. Here the variable set is user-defined and unknown until runtime, so it must be `source`d from a file. Plain `source` inside a shell function runs in the *current* shell process — any exported vars would persist in the caller's interactive shell after the function returns. Wrapping the body in a subshell `( ... )` and `exec`ing `claude` inside it avoids that: the subshell (and anything it exports) is replaced by the `claude` process itself and never returns control to the parent shell with those exports intact.

```sh
claude-{{ $name }}() {
    (
        [ -f "$HOME/.config/claude-env/{{ $name }}.env" ] && . "$HOME/.config/claude-env/{{ $name }}.env"
        CLAUDE_CONFIG_DIR="$HOME/.claude-{{ $name }}" exec command claude "$@"
    )
}
```
*Alternative considered:* build a `VAR=val` prefix string dynamically (e.g. via `env $(cat file)`). Rejected — fragile with quoting/spaces/special characters, and loses the "wrapper replaces shell process via exec" property already established for `mcp-env-wrapper`.

**Decision: generalize across all `claude_envs`, not just `bedrock`**
The template gains one conditional `source` line per generated function, gated only on file existence — not on the env name. This keeps `claude-environments` internally consistent (every function already follows the same generated shape regardless of name) and costs nothing for `work`/`personal`, which simply won't have a matching file.
*Alternative considered:* special-case `bedrock` by name in the template. Rejected — adds a name-specific branch to a partial whose whole design principle is "one shape, generated per entry" (see existing `claude-env-colors` and skills-symlink requirements, which are already data/existence-driven rather than name-driven).

**Decision: new namespace `~/.config/claude-env/<name>.env`, not reusing `~/.config/mcp-env/`**
Parallel XDG-style convention, same file format (`export KEY=VALUE` lines) as `mcp-env-wrapper` for familiarity, but a distinct directory because the two capabilities key on different identifiers (MCP server name vs. Claude environment name) and `mcp-env-injection`'s spec explicitly scopes its namespace to MCP server names.

**Decision: file format matches `mcp-env-wrapper`'s convention**
Plain `export KEY=VALUE` lines, sourced with `.`. No new parsing logic, no schema — consistent with the one precedent this repo already has for personal/local secret files.

## Risks / Trade-offs

- **[Risk]** If `~/.config/claude-env/bedrock.env` is missing or accidentally deleted, `claude-bedrock` silently launches without `AWS_PROFILE`/`AWS_CREDENTIAL_PROCESS`, likely surfacing as a confusing Bedrock auth failure rather than an obvious "file not found." → **Mitigation:** documented in the capability's spec scenarios and in this design; the fix is a one-line file to recreate. No automated warning is added (would require guessing which envs are "expected" to have a file, which conflicts with the Non-Goals).
- **[Risk]** Malformed lines in the env file (non `export KEY=VALUE` syntax) get sourced as arbitrary shell. → **Mitigation:** same trust model already accepted for `mcp-env-wrapper`'s env files; the file is user-authored and local-only, not attacker-controlled input.
- **[Risk]** Manually editing the live `~/.claude-bedrock/settings.json` to remove the two `env` keys is an out-of-band step (not chezmoi-applied), so it's easy to forget on a fresh machine bootstrap. → **Mitigation:** call out explicitly as a manual task in `tasks.md`; the existing `mcp-env-injection` precedent already accepts this trade-off for personal values.
- **Trade-off:** values still exist in plaintext at rest (`~/.config/claude-env/bedrock.env` instead of `settings.json`) — this change relocates rather than encrypts them. Encryption/KeePassXC integration is out of scope (see Non-Goals in the proposal).

## Migration Plan

1. Update `home/.chezmoitemplates/claude-environments` with the subshell/source/exec pattern for all generated `claude-<name>()` functions.
2. `chezmoi apply` to regenerate `.zshrc`/`.bashrc` with the new function bodies.
3. Manually create `~/.config/claude-env/bedrock.env` with `export AWS_PROFILE=...` and `export AWS_CREDENTIAL_PROCESS=...` (values copied from the current `settings.json`).
4. Manually edit `~/.claude-bedrock/settings.json` to remove those two keys from `env`.
5. Verify: open a new shell, run `claude-bedrock`, confirm Bedrock auth still works and `AWS_PROFILE`/`AWS_CREDENTIAL_PROCESS` are not present in the parent shell's environment after the command exits (e.g. `echo $AWS_PROFILE` in the calling shell should be empty).

**Rollback:** re-add the two keys to `settings.json`'s `env` block and revert the template change (or simply leave the template change in place — it's a no-op once the env file is deleted, since sourcing a missing file is skipped).

## Open Questions

- None — scope is intentionally narrow (two values, one environment) per the proposal's Non-Goals.
