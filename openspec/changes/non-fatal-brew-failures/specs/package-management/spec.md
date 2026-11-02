# Spec Delta

## MODIFIED Requirements

### Requirement: Brew Bundle Failure Propagation
When a `brew bundle` (or `brew update`) invocation fails, `run_onchange_before_darwin-23-install-packages.sh.tmpl` and `run_onchange_before_darwin-28-brew-bundle-install.sh.tmpl` SHALL record the failure with `record_script_failure <name>` and exit 0, so `chezmoi apply` continues updating files and running later scripts. Each script SHALL embed the `failure-stamp` template for the same name in a comment, so a recorded failure changes the rendered script and chezmoi runs it again on the next apply. A successful run SHALL NOT modify the stamp.

#### Scenario: brew bundle exits non-zero
- **WHEN** `brew bundle` fails due to an invalid or unavailable package
- **THEN** the script SHALL write the current UTC timestamp to `~/.local/state/chezmoi-scripts/<name>.last-failure`
- **AND** SHALL emit a warning via `print_message "warning"`
- **AND** SHALL exit 0 so the remaining `chezmoi apply` work (target file updates, `after` scripts) still runs

#### Scenario: Retry on next apply
- **WHEN** `chezmoi apply` runs after a recorded failure
- **THEN** the rendered script SHALL differ from the previously run content because the embedded stamp value changed
- **AND** chezmoi SHALL run the script again

#### Scenario: brew bundle succeeds
- **WHEN** every `brew bundle` invocation exits with code 0
- **THEN** the script SHALL leave the stamp file unchanged and exit 0
- **AND** the next render SHALL match the content chezmoi last ran, so the script SHALL NOT run again solely because of the stamp

#### Scenario: Required tool missing
- **WHEN** `brew` (or another tool checked by `require_tools`) is not installed
- **THEN** the script SHALL still exit non-zero, since no later step can succeed
