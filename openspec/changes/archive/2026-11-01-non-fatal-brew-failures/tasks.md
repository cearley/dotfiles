# Tasks

- [x] 1.1 Add `failure-stamp` template and `record_script_failure` helper.
- [x] 1.2 Replace `exit 1` on brew failure in darwin-23 and darwin-28; embed the stamp in both.
- [x] 1.3 Render both scripts via `tests/run-template`, `bash -n` the output, and round-trip a stamp (none → timestamp after `record_script_failure`).
- [x] 1.4 Run `openspec validate non-fatal-brew-failures --strict`.
- [x] 1.5 Live check: a failing brew step lets `chezmoi apply` finish, and the next apply re-runs the script.
