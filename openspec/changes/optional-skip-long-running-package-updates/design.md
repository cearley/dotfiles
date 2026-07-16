## Context

Eleven scripts across positions 20-28 and 37-39 each independently perform slow, network-bound package-update work (Homebrew `brew bundle`/`brew update`, SDKMAN SDK installs, UV tool installs, Bun global installs, Cargo installs, Claude skills/MCP/plugins). Several are wired with `time-bucket` triggers (e.g. every 7 or 30 days) so they re-run periodically even without a `packages.yaml` edit — this is precisely when a user is most likely to want a fast `chezmoi apply` and least likely to want to wait on six separate update checks.

Each of these eleven scripts is executed by chezmoi as its own **subprocess**, spawned directly by the running `chezmoi apply` process. There is no shared shell state between them — any "skip this run" decision made by one script is invisible to the next unless it's persisted somewhere both can read. Script 28 already establishes the pattern of an in-script `read -p ... (y/N)` confirmation prompt (for machine-specific Brewfile installs), proving prompts work fine when chezmoi is run interactively — but it does not attempt to coordinate a decision across scripts, since it only guards itself.

**Platform scope**: all eleven affected scripts are already filename-tagged `darwin` and wrapped in `{{ if eq .chezmoi.os "darwin" -}}`; there are no `linux` or `windows` equivalents anywhere in `.chezmoiscripts/`, and `packages.yaml` has only a `packages.darwin` root. This change is bash/macOS-scoped like the rest of the package-management system it modifies — it introduces no cross-platform support and isn't intended to. If Linux or Windows package layers are ever added, the resolution order (env var → cache → prompt → default) could carry over conceptually, but the implementation (`$PPID`, `[ -t 0 ]`, `read -p`, `${TMPDIR:-/tmp}`) is POSIX/bash-specific — Windows would need a separate PowerShell implementation (`Read-Host`, `$env:TEMP`, a different parent-PID lookup), not a port of this one.

## Goals / Non-Goals

**Goals:**
- Let a single environment variable (`CHEZMOI_SKIP_PACKAGE_UPDATES`) skip every long-running layer with zero prompts — the fast path for repeat interactive use, and the safe default for CI/scripted invocations.
- When that variable is unset and a TTY is attached, offer an interactive choice: skip everything this run, skip specific layers, or run everything (today's behavior).
- Make the decision once per `chezmoi apply` invocation and have all eleven scripts honor it consistently, without each one re-prompting.
- Preserve today's behavior exactly when the variable is unset and no TTY is attached (CI, `remote_install.sh` bootstrap, non-interactive contexts).

**Non-Goals:**
- Per-package skip control (only per-layer, matching the six layers already named in the proposal: Homebrew, SDKMAN, UV, Bun, Cargo, Claude skills/MCP/plugins).
- Changing the one-time `promptMultichoiceOnce` tag-selection prompts in `.chezmoi.toml.tmpl` — those govern *what* is ever installed, this feature governs whether *update checks* run on a given pass.
- Changing script 28's existing machine-Brewfile confirmation prompt semantics beyond gating it behind the new Homebrew-layer skip check.
- A persistent/config-file way to always skip a layer (e.g. "never run Cargo updates") — the env var already covers the "I never want to wait" case at the granularity of "everything," and finer persistent preferences can be a follow-up if requested.

## Decisions

### Decision: Three-tier resolution order — env var → cache file → prompt → default
`CHEZMOI_SKIP_PACKAGE_UPDATES` is checked first and, if set (non-empty), short-circuits every layer to "skip" without touching a cache file or prompting — this keeps the fast path a single env-var check with no filesystem I/O. If unset, scripts fall back to a per-invocation cache file (see below). If no cache file exists yet, the first script to run performs the interactive prompt (only if a TTY is attached) and writes the cache file for the rest of the run to consume. If no TTY is attached and the env var is unset, every layer defaults to "run" — identical to current behavior.
**Alternatives considered**: Making the prompt mandatory (no env var) was rejected — it would force an extra keystroke on every apply, including CI. Making the env var the *only* mechanism (no prompt) was rejected per the user's explicit request for interactive per-layer control when the env var isn't set.

### Decision: Two-step prompt — "skip everything?" then optionally "which layers?"
The interactive prompt first asks a single yes/no question: "Skip ALL long-running package-update checks this run? (y/N)". Answering yes skips every layer with one keystroke — the common case. Answering no (or default) leads to a second yes/no question: "Selectively skip specific layers instead? (y/N)". Only if that is also answered yes does the script walk through one y/N question per layer (Homebrew, SDKMAN, UV, Bun, Cargo, Claude). Declining both questions runs everything, matching today's behavior.
**Alternatives considered**: Jumping straight to six sequential per-layer questions on every run was rejected as too much friction for the common "just skip everything" or "just run everything" cases — most runs will answer the first question and be done in one keystroke.

### Decision: Cache the resolved decision in a file keyed by `$PPID`
Each script, when spawned by chezmoi, has `$PPID` equal to the PID of the `chezmoi apply` process that spawned it — stable across all scripts in one invocation, different across separate invocations. The cache file lives at `${TMPDIR:-/tmp}/chezmoi-package-update-skip.$PPID` and holds simple `SKIP_<LAYER>=0|1` lines, written by whichever script resolves the decision first and `source`d by every subsequent script. A file older than 1 hour is treated as stale and ignored (a single `chezmoi apply` run should never take that long, and this guards against PID reuse across separate days).
**Alternatives considered**: A lock/semaphore keyed by wall-clock time bucket (e.g. "same minute") was rejected as fragile — an apply run that takes longer than the bucket window would re-prompt partway through. Environment-variable propagation between scripts was rejected — chezmoi does not run scripts as children of each other, so there's no shared process environment to inherit.

### Decision: New shared helper in `shared-utils.sh`, called at the top of each layer script
A new function, e.g. `package_layer_should_skip "<layer>"`, encapsulates the whole resolution flow (env var check → cache read → prompt-and-cache → default) and returns 0 (skip) or 1 (run). Each of the eleven scripts adds one guard clause immediately after sourcing `shared-utils.sh` and before any `require_tools`/network calls:
```bash
if package_layer_should_skip "homebrew"; then
    print_message "skip" "Skipping Homebrew package updates for this run"
    exit 0
fi
```
Layer names map to scripts as: `homebrew` → 23, 28; `sdkman` → 20, 24; `uv` → 21, 25; `bun` → 26; `cargo` → 27; `claude` → 37, 38, 39.
**Alternatives considered**: A dedicated new numbered script (e.g. position 19) that only resolves the decision was rejected — it would need to run before every other layer every time regardless of `run_onchange` hashing, effectively becoming an unconditional 12th script and complicating the "did anything actually need to run" logic that `time-bucket` triggers rely on. A guard clause inside each existing script keeps the resolution lazy — it only happens when a layer script would have run anyway.

### Decision: Script 28's existing Brewfile confirmation prompt stays, gated behind the Homebrew-layer check
Script 28 already asks "Install additional packages from your brewfile? (y/N)". The new `homebrew` layer check is added before that existing prompt, so answering "skip Homebrew" in the new mechanism prevents script 28 from even reaching its own question.

## Risks / Trade-offs

- **[Risk]** A user could be prompted about a layer whose script wouldn't have run today anyway (e.g. `packages.yaml` unchanged and outside its `time-bucket` window) → **Mitigation**: harmless; the cached "skip" decision for that layer is simply never consulted since the script never executes. No incorrect behavior results, only an occasional unnecessary question.
- **[Risk]** Stale cache file from a crashed/interrupted `chezmoi apply` could theoretically be reused by a later run that happens to reuse the same PID → **Mitigation**: 1-hour staleness check on the cache file's mtime makes PID reuse within that window exceedingly unlikely on a single developer machine, and no incorrect *installs* result even in the worst case — only update-checks would be skipped once more than intended.
- **[Risk]** Adding a prompt to scripts that previously ran unattended could surprise users mid-`chezmoi update` → **Mitigation**: TTY detection (`[ -t 0 ]`) ensures the prompt only appears in interactive sessions; non-interactive contexts (cron, `remote_install.sh` bootstrap, CI) silently default to "run everything," identical to current behavior.
- **[Trade-off]** The env var is all-or-nothing (no per-layer env var granularity) → accepted per the proposal's explicit design: the env var is the *fast* path, per-layer control belongs to the *interactive* path.

## Migration Plan

- Additive change: no existing script behavior changes when `CHEZMOI_SKIP_PACKAGE_UPDATES` is unset and the user declines both prompt questions (or is non-interactive) — the guard clause is a no-op that falls through to existing logic.
- Roll out the shared-utils.sh helper first, then add the one-line guard clause to each of the eleven scripts.
- No rollback complexity: removing the guard clauses (or unsetting the env var) reverts to current behavior with no data migration.

## Open Questions

- Should the per-layer prompt persist a *preference* across runs (e.g. "always skip Cargo") rather than being asked fresh every time the cache is stale? Deferred as a possible follow-up — out of scope per Non-Goals.
