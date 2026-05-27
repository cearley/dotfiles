## Context

The repo's install scripts (`home/.chezmoiscripts/run_onchange_before_darwin-23-install-packages.sh.tmpl`, `-24-install-sdks`, `-25-install-tools`, `-26-install-bun-packages`, `-27-install-cargo-packages`, plus the Claude Code skill/plugin/marketplace installers `-37`, `-38`) all *push* declared packages onto the machine but never *check* what is installed yet undeclared. Over time, removed-but-not-uninstalled packages accumulate. Today the only way to find them is per-manager manual inspection:

```
brew leaves | sort > installed.txt
yq '.packages.darwin.[].brews[]' home/.chezmoidata/packages.yaml | sort > declared.txt
comm -23 installed.txt declared.txt
```

…repeated for casks, taps, `uv tool list`, `bun pm ls -g`, `cargo install --list`, `sdk current`, `claude plugin list`, `claude plugins marketplace list`, and `npx skills list`. That's tedious and rarely done, so orphans persist.

The proposed script consolidates this into one command with consistent output. Read-only by design — the proposal explicitly defers any `--prune` capability to a follow-up.

## Goals / Non-Goals

**Goals:**
- Single command (`home/scripts/audit-packages.sh`) that prints per-manager lists of installed-but-not-declared packages.
- Respect active chezmoi tags when computing the declared set, so the audit's notion of "declared" matches what the install scripts would actually install on this machine.
- Skip cleanly (with a `print_message "skip"`) when a manager's CLI is not on PATH, so the script works on `core`-only machines (no `cargo`, `sdk`, `uv`, `bun`, `claude`).
- Match the existing install-script visual style via `print_message` from `shared-utils.sh`.

**Non-Goals:**
- Uninstalling, pruning, or modifying any package state.
- Maintaining a "chezmoi-installed" manifest to distinguish chezmoi-installed from manually-installed packages.
- Auditing machine-specific Brewfiles, MAS apps, or non-darwin platforms.
- Wiring into `chezmoi apply`.

## Decisions

### Plain shell script under `home/scripts/` plus a `~/.local/bin/` symlink

The audit is invoked on demand by the user, not driven by `chezmoi apply`. Placing the script under `home/.chezmoiscripts/` would either re-run it on every apply (unwanted noise) or require gating via `time-bucket`, which is the wrong tool — `time-bucket` is for periodic re-execution of *install* scripts, not for opt-in reporting. Putting it under `home/scripts/` (alongside `shared-utils.sh`) keeps it next to its dependency and makes it discoverable without changing apply behavior.

For invocation ergonomics, a chezmoi-managed symlink at `~/.local/bin/audit-packages` points at the script. After `chezmoi apply`, the user types `audit-packages` from any directory. This matches how the rest of the repo exposes user-facing utilities (e.g., the existing `symlink_Brewfile.tmpl` pattern).

The symlink file lives at `home/dot_local/bin/symlink_audit-packages.tmpl` and its template body is exactly `{{ .chezmoi.sourceDir }}/home/scripts/audit-packages.sh`, following the same template-resolves-to-source-path idiom as `home/symlink_Brewfile.tmpl`.

**Alternatives considered:**
- **`chezmoi audit-packages` subcommand.** Rejected — chezmoi has no extension mechanism (unlike `git`, which dispatches `git foo` to `git-foo` on PATH). The chezmoi binary's command set is fixed at compile time.
- **Shell function defined in `dot_zshrc.tmpl`.** Rejected — shell-only (bash users would need a duplicate definition), adds one more thing to the already-large rc file, and offers no advantage over the symlink. The symlink works for any login shell and is discoverable via `which audit-packages`.
- **Direct path invocation only** (`~/.local/share/chezmoi/home/scripts/audit-packages.sh`). Rejected — friction high enough that the script wouldn't get used in practice.

### Tag set comes from `~/.config/chezmoi/chezmoi.toml`, not `packages.yaml`

The "declared" set must match what *this machine* would install. `packages.yaml` lists packages under every tag; only tags listed in `data.tags` in the user's chezmoi config are actually active. The script reads:

```bash
chezmoi data --format=json | jq -r '.tags[]'
```

…and only unions packages under those tag keys.

**Alternative considered:** Union all tags, presenting a "complete declared set" view. Rejected because it would flag `dev`-only packages as orphans on a non-`dev` machine, which is wrong — those packages weren't installed by chezmoi on this machine in the first place, and the goal is to find truly orphaned items.

### Parse `packages.yaml` with `yq` (not Python or `grep`), and add `yq` to core brews

`yq` (Go binary) is the right tool for parsing `packages.yaml` — purpose-built, fast, no runtime dependency tree. It is **not** currently in `packages.yaml`, so this change adds it to `packages.darwin.core.brews` so the audit script's parsing prerequisite is always satisfied. The script still calls `require_tools yq` as a defensive guard (in case a user invokes the audit before `chezmoi apply` has run on a fresh machine), but in practice the dependency is now declared upfront.

**Alternatives considered:**
- **`python3 -c "import yaml; ..."`.** Rejected — adds Python startup cost and yet another dependency to vet (PyYAML version drift). `yq` is purpose-built for this.
- **Keep `yq` out of core and require ad-hoc `brew install yq`.** Rejected (this was the initial proposal). Forcing a `brew install` step on first run undermines the "just run `audit-packages`" ergonomic. `yq` is small (~5 MB), broadly useful for shell scripting against YAML, and a reasonable addition to the baseline toolset.

### Per-manager "list installed" commands

| Manager | List command | Notes |
|---|---|---|
| Homebrew brews | `brew leaves -r` | `-r` = "installed on request" (excludes dependencies). Matches `packages.yaml` semantics. |
| Homebrew casks | `brew list --cask -1` | One per line. |
| Homebrew taps | `brew tap` | One per line. |
| UV tools | `uv tool list \| awk '{print $1}'` | First column is tool name; skip blank/indented lines. |
| Bun globals | `bun pm ls -g \| sed -nE 's/^├── (.*)@.*/\1/p'` | Bun's `-g` listing isn't JSON-clean; parse the tree output. |
| Cargo crates | `cargo install --list \| sed -nE 's/^([^ ]+) v.*:$/\1/p'` | First line of each crate's block. |
| SDKMAN | `sdk current` and `ls ~/.sdkman/candidates/*/` | `sdk current` only shows active; directory listing gives all installed. |
| Claude plugins | `claude plugins list --json \| jq -r '.[].name'` | Assumes `--json`; fall back to text parse if not. |
| Claude marketplaces | `claude plugins marketplace list --json \| jq -r '.[].name'` | Same caveat. |
| Claude skills | `claude skills list` or `~/.claude/skills/` directory listing | Resolve at implementation. |

For each manager, the declared set comes from `yq '.packages.darwin.<tag>.<key>[]' packages.yaml` unioned across active tags, then normalized (strip `mas`-style `"App Name", id: 123` quoting, strip `--git URL.git` flags from cargo entries to extract crate names, strip version suffixes like `@latest` from uv/bun entries).

**Normalization is per-manager.** Each section in the script has a small normalizer because the YAML formats differ (uv has `git+...@latest`, cargo has `--git ...`, sdkman has `"name version"`, etc.).

### Tag-aware Claude items

Claude skills, plugins, and marketplaces are only relevant when the `ai` tag is active. The script checks `ai` ∈ active tags before running those sections; otherwise emits `skip`. This mirrors the existing install scripts at positions 37/38/(skills).

### `--strict` flag for CI

The default exit code is `0` regardless of orphan count — orphans are informational. A `--strict` flag exits non-zero if any orphans are found, useful for `bd preflight`-style gates or a future CI check.

### Output structure

Per manager, a header (`print_message "info" "=== <Manager> ==="`) followed by either:
- `print_message "success" "No orphans"` if installed ⊆ declared, or
- One line per orphan (no `print_message` wrapper — plain `echo` so the output is grep-pipeable).

A final summary line: `print_message "info" "Audit complete: N orphans across M managers"`.

## Risks / Trade-offs

- **`brew leaves` excludes optional dependencies that the user *did* request.** If a user runs `brew install foo` where `foo` was already a dependency of `bar`, `leaves` won't list `foo` even after `brew install foo`. Workaround: also check `brew list --installed-on-request`. → Mitigation: use `brew leaves -r` if it exists in the Homebrew version, else fall back to `brew list --installed-on-request`.
- **Bun's `pm ls -g` tree format is fragile.** The `sed` parse breaks if Bun changes its output format. → Mitigation: pin the parse to a comment naming the Bun version verified against; add a `--format=json` flag if/when Bun adds one.
- **SDKMAN's "installed candidates" require directory listing, which can include partial/broken installs.** → Mitigation: filter to directories that contain at least one valid version subdirectory.
- **Claude CLI's `--json` flag may not exist on all `claude` versions.** → Mitigation: probe with `claude plugins list --json 2>/dev/null`; fall back to text parse if it fails.
- **False positives from packages installed before `packages.yaml` existed.** Old fixtures may show up as orphans. → Mitigation: that's the *correct* behavior — those are genuinely orphans. The user reviews and either adds them to `packages.yaml` or `brew uninstall`s them.
- **Performance.** Worst-case ~8 manager queries, each spawning a CLI. On a `dev`+`ai` machine that's roughly 2-4s total. Acceptable for an on-demand tool.

## Migration Plan

No migration required — purely additive. The script can be added and used immediately. If reverted, no state cleanup is needed.

**Rollback:** delete `home/scripts/audit-packages.sh` and the spec file. No effect on other scripts or installed packages.

## Open Questions

- Should the script accept `--manager=brew,uv,...` to scope a single run? Lean: yes, but defer to a follow-up. Initial scope runs all available managers.
- Should the report be machine-readable (JSON)? Lean: not yet — the user's intent is to read the report and decide manually. Add `--format=json` only when there's a concrete downstream consumer.
- Should the `--strict` flag also wire into `bd preflight`? Out of scope for this change; tracked separately if/when wanted.
