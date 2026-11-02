# Tasks

- [x] 1.1 `record_script_failure` writes `<name>.pending` alongside `<name>.last-failure`.
- [x] 1.2 Add `run_after_darwin-99-report-script-failures.sh.tmpl` (bash 3.2-safe: nullglob, no empty-array expansion under `set -u`).
- [x] 1.3 Render via `chezmoi execute-template`, `bash -n`, and run under `/bin/bash` with an isolated `HOME`: no state dir, empty dir, two failures (listed, `.pending` removed, `.last-failure` kept), and a silent re-run.
- [x] 1.4 Run `openspec validate add-script-failure-summary --strict`.
