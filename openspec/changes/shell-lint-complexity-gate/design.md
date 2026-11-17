# Design

## Context

`tests/lint-shell` (see `openspec/specs/shell-lint/spec.md`) discovers every `*.sh`, `*.sh.tmpl`, and shebang-bearing `*.tmpl` under `home/` not listed in `tests/lint-shell-exclude.txt`, renders templates through `tests/run-template`, and runs three layers in order (syntax → lint → format), skipping lint/format on a syntax failure. `tests/bin/` today holds only two mock binaries (`sops`, `keepassxc-cli`) used by `tests/run-template` to fake secret lookups — neither is a real third-party tool.

A vendored `shellmetrics` (POSIX shell, `github.com/shellspec/shellmetrics`, `VERSION=0.5.0` per its own source) sits untracked at `bin/shellmetrics`. Run with `--csv`, it emits one row per function: `file,func,lineno,lloc,ccn,lines,comment,blank`, where `ccn` is McCabe cyclomatic complexity.

### Baseline (this machine, 2026-11-16)

Of the 61 files `--all`'s discovery logic matches under `home/`, 54 are already in `tests/lint-shell-exclude.txt` for shellcheck/shfmt reasons, leaving **7 currently passing** every existing layer. Running `bin/shellmetrics --csv` against the rendered bytes of those 7 (same rendering `tests/lint-shell` already does) found exactly one function over CCN 10:

| File | Function | CCN |
|---|---|---|
| `home/dot_local/bin/executable_claude-tooling-write-guard.tmpl` | `check_path` | 21 |

(For context only, not actionable: three functions among the 54 *already-excluded* files are also over threshold — `print_message` in `home/scripts/shared-utils.sh` and in the rendered `executable_check-drift.sh`, and `<main>` in two `run_onchange_*` package-install scripts, plus `<main>` in `executable_crash-recovery-hook.sh`. None of these need a new exclude-list entry; they're already skipped by `--all` for other reasons.)

`executable_claude-tooling-write-guard.tmpl` is the one file this baseline makes actionable, and per the proposal it's refactored (not excluded) — see Decisions below.

## Goals / Non-Goals

**Goals:**
- A fourth, CCN-based layer in `tests/lint-shell`, consistent with how the existing three are structured and reported.
- `shellmetrics` vendored and invoked from a tracked repo path, not fetched at lint time.
- `check_path()` brought under the new threshold without changing the `claude-tooling-write-guard` capability's observable behavior.

**Non-Goals:**
- A general vendoring convention for third-party scripts (see proposal's Non-goals).
- Any change to CI (`tests/lint-shell --all` isn't run there today).
- Fixing complexity in any file still on the exclude list for other reasons.

## Decisions

### D1: CCN > 10, enforced immediately, not report-only
10 is the common default McCabe threshold for shell/C-family complexity tools and needs no new calibration period — the baseline above shows it produces exactly one actionable finding today, which is small enough to fix outright (D4) rather than defer. Report-only was considered and rejected: a gate nobody can see fail teaches nothing, and the one real violation found is worth fixing now, not shelved indefinitely.

### D2: Complexity is an independent fourth layer, not gated on lint/format
`lint_file()` in `tests/lint-shell` already runs shellcheck and shfmt independently of each other (both execute and both report even if one already failed) — only a syntax failure short-circuits the rest. The complexity layer follows the same pattern: it runs whenever syntax passes, regardless of the lint/format outcome, so a file with multiple kinds of problems shows all of them in one run. Alternative considered: run it only after lint+format pass, to keep failure output focused on one problem at a time. Rejected — inconsistent with the existing independent-layer pattern and would hide a real complexity problem behind an unrelated shellcheck nit until that's fixed first.

### D3: Vendoring at `tests/bin/shellmetrics`, with a provenance header, license not yet independently verified
Per the user's decision, `tests/bin/shellmetrics` gets a short header comment (upstream URL, pinned version `0.5.0`, vendor date 2026-11-16) directly in the file, since no repo-wide vendoring convention exists to point to instead. Secondary sources (an Awesome-Lists metadata entry, the project's own README badge) both describe `shellspec/shellmetrics` as MIT-licensed, but this hasn't been confirmed by reading the upstream `LICENSE` file directly — task 1.1 does that check before the file is committed, and the header comment records whatever it finds. This is the first *real* vendored tool in `tests/bin/`, next to the `sops`/`keepassxc-cli` mocks; the directory's purpose is now "test-harness tooling" (mocks + real analysis tools used only by tests), not purely mocks, worth noting since there's no README in `tests/bin/` that states this.

### D4: Refactor `check_path()` instead of excluding the file
`check_path()` (CCN 21) is one large `case`/`if`/`elif` chain handling several independent concerns in sequence: an early scope filter, path resolution (`realpath` with a dirname fallback), profile-mismatch computation, a `Read`-tool early return, a `chezmoi`-availability check, then one of three mutually exclusive branches (chezmoi-managed file — itself containing nested `settings.json`-specific logic with its own old_string/new_string managed-key detection — `plugins/`, or `skills/`), falling back to a bare mismatch notice. Each of those is already a natural, nameable sub-operation with its own single responsibility, so splitting them into separate functions (e.g. `resolve_check_path`, `profile_mismatch_message`, `check_managed_settings_json` with its old_string/new_string detection pulled into its own helper, `check_plugins_dir`, `check_skills_dir`) brings each piece under CCN 10 without changing what any input produces. `claude-tooling-write-guard`'s spec (`Deny and Ask Tiers Unchanged`) requires exact behavior preservation; `tests/claude-tooling-write-guard_test.sh` (the existing bashunit suite) is the regression guard for that, run before and after.
Alternative considered: exclude the file like the 54 backlog files. Rejected per the user's explicit choice — this file's shellcheck/shfmt cleanup was finished earlier this session, and re-excluding it for an unrelated reason immediately after would discard that work's intent.

### D5: Exclude-list seeding is a one-time exception to "never add," not a standing practice
`.claude/rules/home-scripts.md` tells agents to "remove a file from the list once it is fixed; never add files to it." That rule governs day-to-day lint fixes. Introducing a *new* layer that didn't exist when the list was last seeded is the same situation the original `tests/lint-shell-exclude.txt` creation (archived change `2026-11-13-shell-template-lint`) was in — a backlog has to start somewhere. Per the baseline above, this particular change ends up needing **zero** new entries (the one actionable finding is fixed, not excluded), so there's nothing to add this time — but the principle (a new layer may seed the list once, future agents still may not) is worth stating explicitly so it isn't read as a precedent for casually adding files later.

## Risks / Trade-offs

- [`check_path()`'s refactor subtly changes a deny/ask decision for some input the test suite doesn't cover] → Mitigation: run `tests/claude-tooling-write-guard_test.sh` before touching the function (baseline) and after each extraction step, not just once at the end; keep each extraction behavior-preserving and mechanical (move a contiguous block into a function, pass what it reads as parameters, return what it produces) rather than restructuring logic while moving it.
- [`shellmetrics`'s CCN counting conventions differ from what a reader expects — e.g. it may count a `case` statement's branches differently from shellcheck's own complexity notion] → Not a correctness risk since the tool defines its own metric consistently; just means CCN 10 is a chosen threshold, not an objectively "correct" one. Documented as a plain McCabe default (D1).
- [Vendored script's license turns out, on reading the actual `LICENSE` file, not to be MIT or not to permit vendoring] → Mitigation: task 1.1 reads the upstream `LICENSE` file before the file is moved/committed and records the real result in the header comment; if it turns out to be incompatible, stop and flag it rather than commit.
- [A future contributor reads "never add files to the exclude list" and is confused why this change added a line to design.md discussing seeding, when in fact zero lines were added to the file itself] → Mitigated by D5 explicitly stating the baseline needed no new entries; nothing in `tests/lint-shell-exclude.txt` itself changes as part of implementing this.

## Migration Plan

1. Vendor `tests/bin/shellmetrics` (git mv from `bin/shellmetrics`, add header, verify license) in one commit step.
2. Add the complexity layer to `tests/lint-shell`, update its usage header.
3. Refactor `check_path()`, verified against the existing test suite, as its own reviewable step (can be its own commit, since it's behavior-preserving and independently verifiable).
4. Run `tests/lint-shell --all` and confirm it's green with zero new exclude-list entries (per the baseline, none are expected).
5. Update `.claude/rules/home-scripts.md` (and `AGENTS.md` if it separately enumerates the three layers) to mention the fourth.
6. Sync the delta spec into `openspec/specs/shell-lint/spec.md` on archive.

No rollback complexity: the new layer is additive to a command nothing else depends on programmatically, and the `check_path()` refactor is behavior-preserving and covered by its own test suite before being relied upon.
