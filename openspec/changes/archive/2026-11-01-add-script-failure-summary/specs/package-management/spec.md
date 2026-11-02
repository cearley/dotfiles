# Spec Delta

## ADDED Requirements

### Requirement: End-of-Apply Script Failure Summary
`record_script_failure <name>` SHALL write, in addition to the `<name>.last-failure` retry stamp, a `<name>.pending` file containing the same UTC timestamp in `~/.local/state/chezmoi-scripts/`. A plain `run_after_darwin-99-report-script-failures.sh.tmpl` script SHALL run on every `chezmoi apply`, list each pending failure with its timestamp via `print_message "warning"`, and delete the `.pending` files it reported. It SHALL NOT modify `.last-failure` stamps, since those drive the retry trigger.

#### Scenario: Failures recorded during this apply
- **WHEN** one or more scripts call `record_script_failure` during a `chezmoi apply`
- **THEN** darwin-99 SHALL print one warning line per failed script, naming it and its failure time
- **AND** SHALL delete each reported `.pending` file
- **AND** SHALL exit 0

#### Scenario: No failures pending
- **WHEN** no `.pending` files exist, including when the state directory itself does not exist
- **THEN** darwin-99 SHALL print nothing and exit 0

#### Scenario: Each failure reported once
- **WHEN** a later apply runs without any new failures
- **THEN** darwin-99 SHALL NOT repeat previously reported failures
- **AND** the `.last-failure` stamps SHALL remain unchanged
