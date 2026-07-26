## ADDED Requirements

### Requirement: Periodic Re-run Cadence Policy
A script SHALL use `run_onchange_` with a `home/.chezmoitemplates/time-bucket`-based trigger comment, instead of `run_once_`, when periodic re-execution provides real value: self-healing credential/session state, catching version drift, or re-asserting configuration that can be reset by external events (e.g. an OS upgrade). A script SHALL remain `run_once_` when it is a genuinely one-shot bootstrap step whose outcome does not spontaneously drift, or whose internal logic only ever installs and never re-checks/upgrades on re-run (converting such a script would add re-execution overhead with no behavioral effect).

#### Scenario: Script re-verifies credential or session state
- **WHEN** a script's own logic already re-validates a session, token, or credential and can self-heal (re-login, re-key) if that state has gone stale
- **THEN** the script SHALL be `run_onchange_` with a cadence comment, so that re-validation logic actually gets a chance to run again after the first successful apply

#### Scenario: Script re-asserts OS-level configuration
- **WHEN** a script applies idempotent configuration (e.g. `defaults write`) that can be reset by external events such as a macOS upgrade
- **THEN** the script SHALL be `run_onchange_` with a cadence comment long enough to avoid nuisance re-runs of any visible side effect (e.g. 90 days for settings that only drift across OS upgrades)

#### Scenario: Script only ever installs, never upgrades, on re-run
- **WHEN** a script's own logic exits early (skip) once its target is detected as installed, with no code path that would act differently on a later re-run
- **THEN** the script SHALL remain `run_once_`, since converting it to `run_onchange_` would not change its behavior on subsequent applies

#### Scenario: Script is an interactive, one-shot bootstrap step
- **WHEN** a script requires manual user interaction (e.g. a browser-driven installer with `wait_for_app_installation`/`prompt_ready`) and the resource it installs does not spontaneously go missing after installation
- **THEN** the script SHALL remain `run_once_`, and MAY carry a one-line comment stating why periodic re-run was not chosen

#### Scenario: Cadence choice is documented in the trigger comment
- **WHEN** a script is converted to `run_onchange_` for this reason
- **THEN** its trigger comment SHALL state the chosen cadence in days and SHALL use the `time-bucket` partial (`{{ includeTemplate "time-bucket" (dict "days" N) }}`), not a hand-rolled date calculation

#### Scenario: run_once_ rationale is documented
- **WHEN** a script remains `run_once_` after this policy is applied
- **THEN** it SHALL carry a one-line comment near the top of the file explaining why periodic re-run was not chosen
