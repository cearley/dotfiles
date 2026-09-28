# Spec Delta

## ADDED Requirements

### Requirement: Template rendering SHALL NOT assume an unenforced script-ordering dependency
When a template's rendered content depends on a prerequisite that a `run_once_`/`run_onchange_` script normally installs (e.g. a decryption key), the template SHALL NOT rely solely on that script's numeric position to guarantee the prerequisite exists before the template renders. The template SHALL either (a) be skipped for that apply run when the prerequisite is absent, with the system remaining safe to re-run once the prerequisite exists, or (b) fail with an error that identifies the missing prerequisite and the script responsible for installing it — and in either case, the failure or skip SHALL NOT prevent unrelated files and scripts in the same `chezmoi apply` invocation from applying successfully.

#### Scenario: Prerequisite absent on a fresh machine
- **WHEN** `chezmoi apply` runs on a machine where a template's prerequisite (e.g. a decryption key installed by a script) has not yet been installed
- **THEN** the dependent template SHALL be skipped for that run, or SHALL fail with an actionable error naming the missing prerequisite and its installer script
- **AND** every other file and script in that same `chezmoi apply` invocation, including the script that installs the missing prerequisite, SHALL still apply/execute normally

#### Scenario: Re-running after the prerequisite is installed
- **WHEN** `chezmoi apply` is run again after the prerequisite script has executed
- **THEN** the previously skipped or failed template SHALL render successfully using the now-available prerequisite
