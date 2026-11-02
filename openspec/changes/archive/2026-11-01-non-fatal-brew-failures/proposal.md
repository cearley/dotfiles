# Proposal

## Why

On 2026-11-01 one unavailable App Store app made darwin-28 exit 1. Because it is a `before` script, `chezmoi update` stopped before writing any target files or running any `after` scripts. The non-zero exit existed only so chezmoi would retry the script next time; a failure stamp gets the same retry without blocking the rest of the apply.

## What Changes

- New `failure-stamp` template returns the contents of `~/.local/state/chezmoi-scripts/<name>.last-failure` (or `none`); scripts embed it in a comment.
- New `record_script_failure <name>` helper in `shared-utils.sh` writes a UTC timestamp to that file.
- darwin-23 and darwin-28 call `record_script_failure` and exit 0 instead of `exit 1` when a brew step fails. darwin-28 also stops letting `set -e` abort on a failed `brew update` or `brew bundle install`.
- Success leaves the stamp in place, so the rendered content equals what chezmoi last ran and no extra run is triggered.

## Impact

- **Affected specs**: `package-management` — "Brew Bundle Failure Propagation".
- **Affected files**: darwin-23, darwin-28, `home/scripts/shared-utils.sh`, `home/.chezmoitemplates/failure-stamp`.
- **Trade-off**: a failure no longer shows as a red chezmoi error; it appears as a warning in the script output.
