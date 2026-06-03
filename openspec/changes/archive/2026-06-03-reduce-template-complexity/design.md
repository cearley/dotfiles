## Context

Four complexity smells were identified during a Philosophy of Software Design review. All four are independent; they can be addressed in sequence without blocking each other. The changes touch two shared files (`shared-utils.sh`, `claude-environments`) and six scripts. No new external dependencies are introduced.

Current state:
1. **Scripts 37/38/39** each contain an identical 8-line block: template-expand the `claude_envs` list into a for-loop, tilde-expand each entry at runtime, skip missing directories with a warning. This block is diverging slowly as each script adds its own wrinkle to the skip message.
2. **Scripts 23/28** each duplicate a template-time iCloud guard: call `icloud-account-id`, check the result, emit a matching bash block that warns and exits if not signed in. The warning text and "run chezmoi apply again" advice must be kept in sync manually.
3. **`claude-environments`** partial derives a p10k segment color from the environment suffix via a hardcoded `case` statement. Adding `claude-client` or any new environment requires editing the partial itself, not just data.
4. **Script 40** calls `includeTemplate "machine-config"` twice with the same key — once in a comment (run_onchange trigger) and once in executable code — while all other scripts use `machine-settings` (which calls the lookup once).

## Goals / Non-Goals

**Goals:**
- Eliminate the 3-way Claude env loop duplication with a reusable bash function
- Eliminate the 2-way iCloud guard duplication with a reusable chezmoi partial
- Make the p10k color mapping data-driven from `config.yaml`
- Migrate script 40 to the `machine-settings` pattern for consistency

**Non-Goals:**
- Redesigning the `machine-config` / `machine-settings` API
- Changing the behavior of any script (all changes are semantically equivalent refactors)
- Addressing `set -euo pipefail` gaps or `echo` vs `print_message` inconsistencies
- Making `for_each_claude_env` available to scripts that don't already use the loop pattern

## Decisions

**D1: `for_each_claude_env` accepts a callback function name plus the env list as variadic args**

The three scripts have different loop bodies, so the function must take a callback. Bash supports this naturally via `"$callback" "$env_dir"`. The env list cannot be read from a shell variable because it originates from Go template expansion at render time — it must be passed in as arguments so the function is self-contained and testable. The template call site becomes:

```bash
do_work_for_env() { local env_dir="$1"; ...; }
for_each_claude_env do_work_for_env{{ range $claudeEnvs }} "{{ . }}"{{ end }}
```

Alternative considered: export a shell array from the template (`CLAUDE_ENVS=(...)`) and have the function read `${CLAUDE_ENVS[@]}`. Rejected — it pollutes the environment, creates implicit coupling, and makes the function non-reusable outside chezmoi scripts.

**D2: iCloud guard extracted as a chezmoi template partial (`icloud-install-guard`)**

The duplication is in Go template code (template-time evaluation), not bash runtime. A new partial at `home/.chezmoitemplates/icloud-install-guard` emits the conditional bash block — the `icloud-account-id` call, the null check, the `print_message` warning, and the `exit 0` — in one place. Scripts 23 and 28 replace their duplicated block with `{{ includeTemplate "icloud-install-guard" . }}`. This keeps the check at template-render time (same semantics as today) and centralizes the warning text.

Alternative considered: replace the template-time check with a `require_icloud_signed_in` bash runtime function. Rejected — changes the check timing from render-time to run-time, which is a behavioral change and harder to reason about in the context of idempotent `run_onchange` scripts.

**D3: `claude_env_colors` in `config.yaml` with hardcoded defaults in the partial**

The partial will look up colors using `index $colors $suffix` with a default of `244` (grey). A machine that doesn't declare `claude_env_colors` gets the same hardcoded defaults that exist today, implemented as a Go template `default` call rather than a case statement. This makes the partial fully backward-compatible: machines that don't set `claude_env_colors` behave identically to today.

`config.yaml` entry format (per-machine, optional):
```yaml
claude_env_colors:
  work: 33
  personal: 76
  bedrock: 208
```

Alternative considered: store colors in `.chezmoidata/` as a global default map. Rejected — `.chezmoidata/` files are static and cannot be templates, so a global default would be a new static YAML file. Using the partial's `default` map is simpler and keeps defaults co-located with the logic that uses them.

**D4: Script 40 migrated to `machine-settings` with inline `$claudeDefault` substitution**

Script 40 calls `machine-config "claude_default"` twice: once in the `run_onchange` trigger comment and once in the executable `$claudeDefault` variable. Migrating to `machine-settings` means one `fromJson` call at the top, then `index $settings "claude_default"` for both uses. The trigger comment gets the value from the same `$settings` map, so the hash changes at exactly the same time as today.

## Risks / Trade-offs

- **[Risk] `for_each_claude_env` callback pattern is unfamiliar**: Bash callbacks via function name are valid but uncommon in this codebase. → Mitigation: add a comment in shared-utils.sh explaining the pattern; the call sites in scripts 37/38/39 are self-documenting (`for_each_claude_env do_X{{ range ... }}`).
- **[Risk] `icloud-install-guard` partial output must match both scripts' context**: Scripts 23 and 28 have slightly different surrounding code; the partial must be generic enough to not assume which script it's embedded in. → Mitigation: the partial only emits the guard block (no surrounding function or variable setup); it exits 0 if iCloud is not available, which is safe in both scripts.
- **[Risk] `claude_env_colors` default map in the partial**: If the default map is wrong or incomplete, existing machines silently get grey for previously-colored environments. → Mitigation: the default map mirrors the current hardcoded case statement exactly, so no machine changes behavior unless it explicitly sets `claude_env_colors`.
- **[Risk] Script 40 trigger comment hash change**: Changing the run_onchange trigger line causes script 40 to re-run once on all machines after `chezmoi apply`. The script is idempotent (re-bootstrapping the LaunchAgent is harmless), so this is safe.
