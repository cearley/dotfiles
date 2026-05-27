## 1. Scaffolding & Shared Helpers

- [x] 1.1 Add `yq` to `packages.darwin.core.brews` in `home/.chezmoidata/packages.yaml` (place alphabetically among existing core brews; verify with `chezmoi apply` that brew picks it up)
- [x] 1.2 Create `home/scripts/audit-packages.sh` as an executable bash script with shebang, `set -euo pipefail`, and `source` of `home/scripts/shared-utils.sh`
- [x] 1.3 Add a `--strict` flag parser (default off) and a `--help` flag that prints usage
- [x] 1.4 Add a `read_active_tags()` helper that runs `chezmoi data --format=json | jq -r '.tags[]'` and stores the result in a global array
- [x] 1.5 Add a `require_yq()` guard that emits an error via `print_message "error"` and exits non-zero when `yq` is not on PATH (defensive — `yq` is in core, but a user could invoke the audit on a fresh machine before `chezmoi apply` finishes)
- [x] 1.6 Add a `declared_for()` helper: takes a key name (`brews`, `casks`, `taps`, `uv`, `bun`, `cargo`, `sdkman`, `plugins`, `plugin_marketplaces`, `skills`) and prints the union of entries under that key across the active tags from `home/.chezmoidata/packages.yaml`
- [x] 1.7 Add a `report_orphans()` helper: takes a manager label, the installed list (stdin), and the declared list (file path); prints the header via `print_message "info"`, computes `installed - declared` with `comm`, and either prints `print_message "success" "No orphans"` or prints each orphan on its own stdout line
- [x] 1.8 Track total-orphan count and managers-with-orphans count in globals; print a final `print_message "info"` summary line

## 2. Homebrew Sections

- [x] 2.1 Add a `brews` section: list installed-on-request formulae (`brew leaves -r` with fallback to `brew list --installed-on-request`) and diff against `declared_for brews`
- [x] 2.2 Add a `casks` section: list installed casks (`brew list --cask -1`) and diff against `declared_for casks`
- [x] 2.3 Add a `taps` section: list active taps (`brew tap`) and diff against the union of top-level `packages.darwin.taps` plus `declared_for taps`
- [x] 2.4 Guard all three sections behind `command_exists brew`; emit `print_message "skip"` if brew is missing

## 3. Language-Ecosystem Sections

- [x] 3.1 Add a `uv` section: parse `uv tool list` to extract tool names; normalize declared entries by stripping `git+...`, `==X.Y.Z`, `@latest`, and `-p X.Y` prefixes; diff
- [x] 3.2 Add a `bun` section: parse `bun pm ls -g` tree output to extract package names; diff against `declared_for bun`
- [x] 3.3 Add a `cargo` section: parse `cargo install --list` to extract crate names; normalize declared `--git URL` entries to derived crate names; diff
- [x] 3.4 Add a `sdkman` section: enumerate installed candidates from `~/.sdkman/candidates/<candidate>/<version>/` directories (filter to entries that match the "name version" format); diff against `declared_for sdkman`; only run when `dev` is in the active tag set
- [x] 3.5 Guard each section behind its CLI check (`command_exists uv`, `command_exists bun`, `command_exists cargo`, `command_exists sdk`); skip otherwise

## 4. Claude Code Sections

- [x] 4.1 Add a `plugins` section: probe for `claude plugins list --json`; fall back to text parse if `--json` is unsupported; diff against `declared_for plugins`
- [x] 4.2 Add a `plugin_marketplaces` section: probe for `claude plugins marketplace list --json`; fall back to text parse; diff against `declared_for plugin_marketplaces`
- [x] 4.3 Add a `skills` section: list installed skills from the appropriate Claude config directory (resolve exact location during implementation); diff against `declared_for skills`
- [x] 4.4 Guard all three sections behind `command_exists claude` AND `ai` ∈ active tags; skip otherwise

## 5. Exit-Code & Output Polish

- [x] 5.1 Implement default exit `0` regardless of orphan count
- [x] 5.2 Implement `--strict` mode: exit non-zero if total orphan count > 0
- [x] 5.3 Implement hard-error exit (non-zero, independent of `--strict`) when `chezmoi data` fails, when `packages.yaml` cannot be read, or when `yq` is missing
- [x] 5.4 Verify all section headers, status messages, and summary use `print_message` (stderr); verify all orphan listings are plain `echo` to stdout
- [x] 5.5 Run `shellcheck home/scripts/audit-packages.sh` and resolve all warnings (or document each suppression inline)

## 6. Verification

- [x] 6.1 Run the script on the current `dev,ai,personal,datascience` machine; confirm all sections execute, no errors
- [x] 6.2 Temporarily remove a known declared package from `packages.yaml` (in-memory test only — do not commit), re-run the script, confirm the removed package appears as an orphan in the expected section, restore `packages.yaml`
- [x] 6.3 Run the script with `PATH` munged to hide `cargo`; confirm the cargo section emits a skip and the rest of the audit completes normally
- [x] 6.4 Run the script with `--strict` against a known-clean state; confirm exit code `0`
- [x] 6.5 Run the script with `--strict` against a state with at least one orphan; confirm non-zero exit
- [x] 6.6 Pipe orphan output through `grep` to confirm the plain-stdout lines are pipe-friendly (e.g., `audit-packages.sh 2>/dev/null | grep ^foo`)

## 7. Invocation Symlink

- [x] 7.1 Create `home/dot_local/bin/symlink_audit-packages.tmpl` with body `{{ .chezmoi.sourceDir }}/home/scripts/audit-packages.sh` (no trailing newline issues — match the format of `home/symlink_Brewfile.tmpl`)
- [x] 7.2 Run `chezmoi execute-template < home/dot_local/bin/symlink_audit-packages.tmpl` and confirm the rendered output is an absolute path that resolves to an existing executable
- [x] 7.3 Verify `~/.local/bin/` is on PATH on this machine (`echo $PATH | tr ':' '\n' | grep -F "$HOME/.local/bin"`); if not, document the gap in the change archive notes (no PATH change as part of this change — the rest of the repo already assumes `~/.local/bin/` is on PATH)
- [x] 7.4 Run `chezmoi apply` and confirm `~/.local/bin/audit-packages` exists as a symlink pointing into the source dir (`readlink ~/.local/bin/audit-packages`)
- [x] 7.5 Run `audit-packages --help` from a directory outside the source dir; confirm the help text prints

## 8. Documentation

- [x] 8.1 Add a one-line entry under the "Common Commands" section of `CLAUDE.md` describing the `audit-packages` command (no separate section, just the line)

## 9. OpenSpec Verification & Archive

- [x] 9.1 Run `openspec validate add-package-audit-script --strict` and resolve any reported issues
- [x] 9.2 Run `/opsx:verify add-package-audit-script` to confirm implementation matches artifacts
- [x] 9.3 Run `/opsx:archive add-package-audit-script` to move the change to `openspec/changes/archive/` and sync `package-audit` spec into `openspec/specs/`
