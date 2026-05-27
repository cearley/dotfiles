## Why

The repo declares packages across six ecosystems in `home/.chezmoidata/packages.yaml` (Homebrew, UV, Bun, SDKMAN, Cargo) plus Claude Code skills/plugins/marketplaces. Packages can be installed but no longer declared — either because they were removed from `packages.yaml` (and the install scripts no longer touch them), or because they were installed ad-hoc outside of chezmoi. There is currently no way to see what's installed-but-not-declared without manually listing each manager's contents and grepping the YAML, which makes it easy for orphan packages to accumulate unnoticed.

## What Changes

- Add a new on-demand audit script at `home/scripts/audit-packages.sh` (plain shell, not a chezmoi-managed script) that lists, per package manager, items currently installed on the machine but not declared in `packages.yaml`.
- Add `yq` to `packages.darwin.core.brews` so the audit's YAML-parsing prerequisite is always satisfied on a chezmoi-managed machine, regardless of which optional tags are active.
- Add a chezmoi-managed symlink at `~/.local/bin/audit-packages` pointing at the source script, so the user can invoke it as just `audit-packages` from any directory. (chezmoi itself does not support custom subcommands, so `chezmoi audit-packages` is not a viable path; a PATH-resident symlink is the closest equivalent.)
- Audit covers: Homebrew (taps, formulae, casks), UV tools, Bun global packages, Cargo crates, SDKMAN candidates, Claude Code plugins, Claude Code plugin marketplaces, and Claude Code skills.
- Output uses the existing `print_message` conventions from `scripts/shared-utils.sh` so the report matches install-script styling.
- Audit is **read-only**: it never installs, uninstalls, or modifies state. It only reports.
- Tag selection is respected: the audit considers a package "declared" if it appears under any tag currently active on this machine (per `~/.config/chezmoi/chezmoi.toml`). Packages under inactive tags are *not* considered declared (their install scripts wouldn't install them either) and therefore show up as orphans if installed.
- Exit code: `0` if no orphans found, `0` (with non-empty report) if orphans found — orphans are informational, not a failure. A `--strict` flag MAY be supplied to exit non-zero when orphans are present (useful for CI/preflight).

## Capabilities

### New Capabilities
- `package-audit`: On-demand reporting of installed-but-not-declared packages across all six package management ecosystems plus Claude Code skills/plugins/marketplaces. Read-only audit script invoked manually; respects active chezmoi tags when computing the declared set.

### Modified Capabilities
<!-- None. Existing install scripts and packages.yaml structure are unchanged. -->

## Impact

- **Affected files**:
  - `home/scripts/audit-packages.sh` — **new** read-only audit script. Sources `shared-utils.sh`, reads tag list from chezmoi config, parses `packages.yaml` with `yq`, queries each package manager, prints per-manager orphan lists.
  - `home/.chezmoidata/packages.yaml` — add `yq` to `packages.darwin.core.brews`.
  - `home/dot_local/bin/symlink_audit-packages.tmpl` — **new** chezmoi-managed symlink whose content resolves to `{{ .chezmoi.sourceDir }}/home/scripts/audit-packages.sh`, creating `~/.local/bin/audit-packages` as a symlink to the source script.
  - `openspec/specs/package-audit/spec.md` — **new** capability spec.
  - `CLAUDE.md` — add a one-line entry under the existing "Common Commands" section pointing to the `audit-packages` command.
- **Tags affected**: none directly. The script reads tags but does not change tag behavior. Available regardless of which tags are active.
- **Machines affected**: usable on any machine, but most informative on `dev`-tag machines where more ecosystems are in play (SDKMAN, Cargo). On a `core`-only machine, only the Homebrew sections will have anything to report.
- **Dependencies**: `yq` is added to `packages.darwin.core.brews` in `packages.yaml` so every machine that runs the audit has it. Each package manager's CLI must be on PATH for its section to run; missing CLIs cause that section to be skipped with a `skip` message rather than an error.
- **Security implications**: none. The script only reads installed-package metadata and a local YAML file. No network calls, no secret access, no privilege escalation.

## Non-goals

- **Uninstalling orphans.** This proposal is strictly reporting. A future `--prune` flag (with explicit per-manager confirmation) is a deliberate follow-up once the audit output is trusted.
- **State-file tracking of "installed by chezmoi vs. installed manually".** The audit treats *all* installed-but-not-declared items as orphans, including ones the user installed ad-hoc. This is by design — the user reviews the report and decides what to keep. Maintaining a parallel manifest of chezmoi-installed packages adds complexity that is unnecessary for a read-only report.
- **Integration into `chezmoi apply`.** The script is invoked manually (e.g., `home/scripts/audit-packages.sh`). It is not wired into any `run_*` hook because most users do not want orphan-discovery noise on every apply.
- **Auditing packages outside `packages.yaml`**, such as packages in machine-specific Brewfiles (`brewfiles/*-brewfile`). The machine-Brewfile install path is interactive and already user-controlled; folding it into the audit would require following the symlink and is deferred to a follow-up.
- **Mac App Store (`mas`) auditing.** The `mas` CLI does not reliably enumerate installed apps in a machine-comparable form, and MAS apps can be installed via the App Store GUI independently of `mas`. Deferred.
- **Cross-platform support.** The script targets macOS only (matches the rest of `home/.chezmoiscripts/`); Linux/WSL out of scope.
