## Context

`run_onchange_before_darwin-23-install-packages.sh.tmpl` installs all Homebrew packages by rendering a Brewfile from `packages.yaml` into a `brew bundle --file=/dev/stdin` heredoc. The Brewfile DSL has no mechanism to set environment variables for individual formulae; env vars must be present in the shell environment when `brew bundle` (and thus `brew install`) executes.

Some third-party packages check for specific env vars as a EULA-acceptance gate:
- `msodbcsql18` / `mssql-tools18` from `microsoft/mssql-release` require `HOMEBREW_ACCEPT_EULA=Y`

Without a way to declare these in `packages.yaml`, a fresh machine install fails silently or requires manual pre-export — breaking unattended `chezmoi apply`.

## Goals / Non-Goals

**Goals:**
- Allow any category in `packages.yaml` to declare install-time env vars via an optional `brew_env` key.
- Collect and export those vars automatically before `brew bundle` runs in the darwin-23 script.
- Keep existing `brews`, `casks`, and `taps` list formats as plain strings (no schema changes there).
- Be additive — categories without `brew_env` are unaffected.

**Non-Goals:**
- Per-package env var scoping (bundle runs atomically; per-entry env injection is not feasible).
- Persisting env vars beyond the script execution.
- Env var support for UV, Bun, SDKMAN, or Cargo installers.
- Conflict resolution beyond last-active-category-wins.

## Decisions

### Decision: Category-level `brew_env` map (not per-package or global)

**Chosen**: Optional `brew_env: { KEY: "value" }` at the same level as `brews`, `casks`, etc.

**Alternatives considered**:
- *Per-package (mixed string/object list)*: Ruled out — the existing spec explicitly requires all `brews`, `casks`, and `taps` entries to be plain strings. Changing that would require updating every template loop that iterates those lists.
- *Global `darwin.brew_env`*: Divorced from the category where the package lives; makes it easy to forget to remove an env entry when its package is deleted.
- *Pre-install individual packages with env, then let bundle skip them*: More moving parts; requires tracking which packages to exclude from the bundle separately.

Category-level keeps the declaration colocated with the packages it serves, requires no changes to existing list-iteration templates, and naturally scopes the env var to the category's install context.

### Decision: Export env vars before `brew bundle` (applies to entire bundle run)

**Chosen**: Collect all `brew_env` maps from active categories, merge them, export before the `brew bundle` heredoc.

**Rationale**: Install-time vars like `HOMEBREW_ACCEPT_EULA` are namespace-specific — only Microsoft's formulae check for that variable, so exporting it globally doesn't affect other packages. This is simpler than splitting the bundle run or wrapping individual installs.

**Merge strategy**: Iterate categories in the existing order (`core` first, then `tag_choices` order). For duplicate keys, last writer wins. Conflict detection is a non-goal; the names of these vars are generally unique to their vendor.

### Decision: `brew_env` values are always strings

All values in `brew_env` are treated as strings. YAML booleans (`true`/`false`) or integers could cause template rendering issues; callers should quote values in YAML if there's any ambiguity (e.g., `"Y"` not `Y`).

### Decision: No `unset` after bundle

Env vars are exported into the script's process environment. They disappear when the script exits. No explicit `unset` is needed and adding one would add noise without safety benefit.

## Risks / Trade-offs

| Risk | Mitigation |
|------|-----------|
| Env var exported to entire bundle run, not just the target package | Acceptable — install-time vars are vendor-namespaced and ignored by packages that don't check them |
| Two active categories define the same key with different values | Last-wins is deterministic given fixed category iteration order; document the behavior in the spec |
| `brew_env` value contains characters that break shell quoting | Template renders values with Go's `quote` filter, same pattern used for package names elsewhere |
| New contributor doesn't know to add `brew_env` alongside a problem package | Spec requirement documents the pattern; audit-packages is out of scope for env vars |

## Migration Plan

1. Add `brew_env` to `packages.darwin.work` in `packages.yaml` for the Microsoft SQL packages.
2. Update `darwin-23` template to collect and export env vars.
3. Test with `chezmoi execute-template` to verify the rendered script contains the correct `export` statements.
4. Apply on a work machine to confirm `msodbcsql18` installs without manual intervention.

**Rollback**: Remove `brew_env` from `packages.yaml` and revert the template change. No state is persisted — the env vars are ephemeral to the script run.

## Open Questions

None — design settled during exploration.
