# Design

## Context

- `tests/run-template` already renders any template against the mock `keepassxc-cli` and `sops` binaries, using this machine's real chezmoi data (tags, machine settings). Each call builds a temporary chezmoi config, so it costs about one `chezmoi execute-template` per file.
- Baseline (2026-11-12, this machine), summarized in proposal.md. Findings that shape this design:
  - The 2 render failures (`83-login-atuin`, `46-setup-ssh-github`) come from the chezmoi `keepassxc` function, which issues `show` without `--attributes` and parses `Key: value` lines. The mock returns a single bare value for that request, so `.UserName`/`.Password` are missing. That's why the fix belongs in the mock, not in the fixtures.
  - `bash -n -` reads a script from stdin and exits 2 with `line N: syntax error ...` on a parse error. No rendered template currently fails it.
  - shfmt's diffs on rendered templates are mostly blank-line artifacts of template tags: doubled blank lines around `{{ if }}`/`{{ end }}` blocks and a trailing blank line. Capturing output through `$(...)` hides the trailing ones (13 of 35 fail that way, against 32 of 35 when the exact bytes are checked), so the linter has to check the exact rendered bytes.
  - Indentation is mixed. `shared-utils.sh` and most templates use 4 spaces with indented `case` items; most `setup-memory-workflow` scripts use 2 spaces.
  - `shfmt` (3.14) is installed via Homebrew on this machine but isn't declared in `packages.yaml`. `shellcheck` is declared under `dev` brews.
- The 12 plain `*.sh` files under `home/` and at least 8 extension-less shell templates (`executable_*.tmpl`, `modify_private_credentials.tmpl`) aren't caught by the `*.sh.tmpl` naming convention.
- `core.hooksPath` is set to `.beads/hooks`. Beads was removed from this repo in `829ed9a`, so the directory no longer exists and no hooks run. `.git/hooks/` holds only samples.
- CI (`.github/workflows/ci.yml`, job `shell_lint`, `ubuntu-latest`) runs `shellcheck home/dot_claude/skills/setup-memory-workflow/scripts/*.sh` from the repo root with no flags, plus a 100-line budget check (raised to 160 by this change; see Risks) and a shellmetrics complexity check on the same files.

## Goals / Non-Goals

**Goals:**
- One script holds all the logic; the Makefile, the hook and the agent guidance only call it.
- shellcheck and shfmt settings each live in one config file that editors and CI also read.
- Checking a single file is fast enough for an agent to run after every edit.

**Non-Goals:**
- Speeding up `--all` by batching renders into a single chezmoi call (possible later optimization).
- Running the syntax and format layers in CI.

## Decisions

### D1. Plain bash script + Makefile + tracked `.githooks/`
`tests/lint-shell` is a bash script that sits next to `tests/run-template` and follows its style: `set -euo pipefail` and a `usage()` built from its header comment. `make` only delegates to it, and `.githooks/pre-commit` is a two-line wrapper.
- *Alternatives:* the pre-commit framework or lefthook would add a dependency and a config format for a single hook. mise tasks would also work, but `make` ships with the system. The user chose Makefile + `.githooks`.
- It's a dev tool rather than a chezmoi-managed file, so it doesn't use `shared-utils.sh`; that file targets rendered setup scripts on target machines. Output is plain text in the tools' own styles.

### D2. Render to a temp file, then check the file
Each template is rendered with `tests/run-template "$f" > "$tmpdir/<source path minus .tmpl>"`, with no `$(...)` capture, so the exact bytes, trailing newlines included, reach every layer. Shellcheck runs on the temp path, and output paths are rewritten back to the source path with `sed`. shfmt reads the temp file on stdin with `--filename` (D12). The temp dir comes from `mktemp -d` and is removed by a `trap` on exit unless `--keep` is passed, so line numbers can be checked against the rendered file.

### D3. Discovery by suffix first, shebang second
`*.sh` → check directly. `*.sh.tmpl` → render and check. Other `*.tmpl` under `home/` → render and check if any source line matches `^#!.*\b(ba)?sh\b`. Any line, not line 1, because many templates start with `{{- if eq .chezmoi.os "darwin" -}}` before the shebang. Accepted limit: a non-shell template that embeds a sh/bash shebang (e.g. in a heredoc) would be checked as shell; none exists today, and the false failure would be visible and easy to fix. Files under `home/.chezmoitemplates/` are partials, not scripts. They're excluded from direct checking; their rendered content is checked as part of each template that includes them.

### D4. `.shellcheckrc` contents
`external-sources=true` and `source-path=SCRIPTDIR`, with no disables at first. `check-sourced` (the `-a` in the user's manual command) is deliberately left off: with it, every template that sources `shared-utils.sh` would re-report that file's findings, once per template. `shared-utils.sh` is checked on its own as a plain `*.sh`. Rendered sources use absolute paths (`{{ .chezmoi.sourceDir }}/scripts/shared-utils.sh`), so `-x` resolves them from the temp location.

### D5. Mock whole-entry `show`
In `handle_show_args`, when no `--attributes` was parsed, print `Title`/`UserName`/`Password`/`URL`/`Notes` lines through `lookup`. `Title` defaults to the entry name. Attribute mode is unchanged.

### D6. ~~Staged mode widens on shared inputs~~ (removed by D16)
The hook checks only staged files. A change to a partial, data file or mock is not followed by a full re-check; `make lint` is the full check.

### D7. Hook checks the working tree, not the index
Templates are rendered from the working-tree copy, because `chezmoi execute-template` resolves `includeTemplate` against the source dir. Partially staged files (`git add -p`) are checked as they are in the working tree. This is an accepted limit; the hook prints no extra warning (removed by D16).

### D8. Repoint `core.hooksPath`
`make hooks` runs `git config core.hooksPath .githooks`. The setup is documented in `README.md` under "Using This Repository" and in `.claude/rules/home-scripts.md`. Clones aren't set up automatically: a chezmoi `run_` script targets `$HOME`, not the source repo.

### D9. `make check` scope
`check` = `lint` + `test`, where `test` runs only the `tests/test-*.sh` suites confirmed to sandbox their environment (per the project's test-isolation rule). Excluded suites, and the Python tests until their runner is confirmed, are listed in a Makefile comment.

### D10. Layer order and short-circuit
For each file: syntax → lint → format. A syntax failure skips lint and format for that file, since both would only re-report the same parse error. Lint and format both run whenever syntax passes, so one run reports everything that needs fixing. Each failure line is prefixed `[syntax]`, `[lint]` or `[format]`. A file passes only if every layer passes.

### D11. Syntax layer interpreter
The shebang picks the interpreter: `#!/bin/sh` → `sh -n`, anything else → `bash -n`. `bash -n` doesn't follow `source`/`.` (nothing runs), so a broken sourced library isn't caught through the scripts that source it. Discovery covers that gap, because the library (`home/scripts/shared-utils.sh`) is itself a plain `*.sh` and gets its own syntax check.

### D12. shfmt configuration via `.editorconfig`
The repo-root `.editorconfig` has `root = true` and a `[*.{sh,sh.tmpl}]` section with `indent_style = space`, `indent_size = 4` and `switch_case_indent = true`. That's 4 spaces everywhere, so the `setup-memory-workflow` scripts get re-indented when touched. The format layer runs `shfmt -d --filename <source path> < <rendered file>` from the repo root and passes no `-i`/`-ci` flags, because any formatting flag makes shfmt ignore `.editorconfig`. A test on 2026-11-12 confirmed that `--filename` makes shfmt apply the `.editorconfig` section for that path to stdin input, including `.sh.tmpl` names. All files, plain `*.sh` included, are fed the same way (stdin with `--filename <source path>`), which gives the same result as `shfmt -d <file>`.
- *Alternatives:* hard-coded flags (rejected: editors wouldn't share the settings, and it would duplicate what `.editorconfig` already says).

### D13. No normalization; templates own their whitespace
The format layer sees the exact rendered bytes. Blank-line artifacts are fixed in the template with whitespace control (`{{- if ... }}`, `{{ end -}}`, etc.) until rendered output is shfmt-clean. Templates are never rewritten by shfmt, since it can't parse template syntax and would corrupt them. `make fmt` runs `shfmt -w` on plain `*.sh` files only.
- *Alternatives:* collapsing blank lines before shfmt was considered and rejected by the user, because it would hide real output problems and let templates drift from clean rendered output.

### D14. CI shares `.shellcheckrc`
shellcheck looks for `.shellcheckrc` in each checked file's directory and its parents, so CI's existing invocation from the checkout picks up the root file with no workflow edit. The task is to confirm that and add a comment in `ci.yml` pointing at `.shellcheckrc` as the single source of settings, so nobody adds flags there later. The same job's setup-memory-workflow line budget is raised from 100 to 160, because shfmt-clean versions of three scripts exceed 100 lines (see Risks). `ubuntu-latest` ships shellcheck ≥ 0.8, which supports `external-sources`; the task checks the version in the job log.

### D16. Simplification: no widening, no baseline (supersedes the removed D15)
Implementing D6 (re-check every file when a shared input is staged) made every `packages.yaml` commit fail on the 55-file backlog. Three rounds of fixes followed: a per-file-and-layer baseline, then a count ratchet, then prune and stale handling, and then fixes for edge cases in that machinery. `tests/lint-shell` grew to 511 lines for a script whose real job (render, `bash -n`, shellcheck, shfmt) is about 100. The user stopped it and chose this design:
- `tests/lint-shell` takes file paths, or `--all`. No `--staged`, `--keep`, baseline, prune, summary counters, missing-tool check or cwd path resolution. Target: under 150 lines, checked by a task.
- The hook selects staged `home/` files with `git diff --cached --name-only --diff-filter=ACMR -- home/` and passes them to the linter. The linter skips non-shell paths.
- `tests/lint-shell-exclude.txt` is a plain list of paths that only `--all` skips, seeded with today's 55 failing files so `make lint` passes. Edited by hand; only shrinks.
- Clean up when touched is enforced again: named and staged files are never excluded.
- Rejected: keeping the baseline (too much machinery for its value), and dropping `--all` (needed for `make lint`).

## Risks / Trade-offs


- [The format backlog is large: 32 of 35 rendered templates and all 12 plain scripts] → Listed in the exclude list and cleaned up when touched (the hook checks every staged file). Plain scripts can be batch-fixed with `make fmt` in a separate commit, then removed from the list.
- [Whitespace control can be fiddly and can shift indentation or merge lines] → Check with `tests/run-template <file>` and inspect the rendered output. The guidance tells agents to fix this in the template.
- [Re-indenting `setup-memory-workflow` scripts changes the canonical templates other projects copy, which shows up as drift in `check-drift` across projects] → Not done in this change. When it is done, it's done deliberately with that skill's version-bump/sweep process. shfmt can change line counts (it splits compact one-liners): `executable_check-drift.sh` goes from 99 to 157 lines. CI's line budget for these scripts is therefore raised from 100 to 160 in this change, so a touched file can be made shfmt-clean without failing CI.
- [Results depend on the machine: only this machine's tag branches are checked] → Documented in the guidance.
- [`--all` is slow (one chezmoi call per template, plus speculative renders for shebang detection)] → Source pre-filter in D3. The hook only checks staged files, except when D6 widens the run.
- [Line numbers refer to rendered output, not template source] → `tests/run-template <file>` shows the rendered output; documented in the guidance. Findings name the source path.
- [Hook isn't active on other clones until `make hooks` is run] → Documented. The stale `.beads/hooks` value means no hook coverage is lost by switching.
- [The mock change alters output for any existing caller of whole-entry `show`] → No existing caller works today (they fail to render).

## Migration Plan

1. Land the mock fix, configs and linter. Seed the exclude list from `tests/lint-shell --all` and check that `make lint` passes.
2. Run `make hooks` on this machine, then on Mac Studio and Mac mini when next used. `chezmoi apply` installs `shfmt` on `dev` machines.
3. Rollback: `git config --unset core.hooksPath`, or `git commit --no-verify` for one commit.

## Open Questions

- `AGENTS.md` still carries a stale beads integration block, even though beads was removed in `829ed9a`. Out of scope here, but the `AGENTS.md` edit in this change will sit next to it, so flag it for a separate cleanup.

## Baseline

`tests/lint-shell --all`, 2026-11-12, this machine (exit 1, about 11 s): 59 files discovered (12 plain `*.sh`, 38 `*.sh.tmpl`, 9 extension-less shell templates).

| Result | Files |
| --- | --- |
| Passed | 3 |
| Skipped | 1 (`darwin-48-setup-azure-auth-personal.sh.tmpl`, renders empty) |
| Failed (any layer) | 55 |
| Render failures | 0 |
| Syntax failures | 0 |
| Lint failures | 14 (11 `*.sh.tmpl`, 3 extension-less) |
| Format failures | 53 |

A file can fail both lint and format, so the layer counts add up to more than 55.

Passing: `run_onchange_after_darwin-42-build-freshbooks-mcp-server.sh.tmpl`, `dot_local/bin/executable_uninstall-claude-plugin-everywhere.tmpl`, and the Claude Desktop `modify_claude_desktop_config.json.tmpl` (renders a shell script despite its name).

Lint failures, `home/.chezmoiscripts/`: `run_once_after_darwin-83-login-atuin`, `run_once_after_darwin-85-configure-system-defaults`, `run_once_before_darwin-05-install-rosetta`, `run_onchange_after_darwin-36-3-install-claude-mcp-servers`, `run_onchange_after_darwin-36-4-install-claude-plugins`, `run_onchange_after_darwin-46-setup-ssh-github`, `run_onchange_after_darwin-90-update-hosts`, `run_onchange_after_darwin-91-setup-cloudflare-tunnel`, `run_onchange_after_darwin-95-restart-syncthing`, `run_onchange_before_darwin-20-install-sdkman` (all `.sh.tmpl`). Elsewhere: `dot_claude/skills/clean-claude-orphans/scripts/executable_list-claude-orphans.sh.tmpl`, and the extension-less `dot_local/bin/executable_apply-claude-pattern.tmpl`, `executable_audit-packages.tmpl`, `executable_mcp-env-wrapper.tmpl`. The `83` and `46` templates are the two that failed to render before the mock fix. The `audit-packages` and `list-claude-orphans` findings are SC1091 on the relative `source ./.local/lib/audit-claude-code.sh`; `mcp-env-wrapper` is SC1090 (non-constant source).

Format failures: 53 of the 59 files, including all 12 plain `*.sh` files and `home/scripts/shared-utils.sh`.
