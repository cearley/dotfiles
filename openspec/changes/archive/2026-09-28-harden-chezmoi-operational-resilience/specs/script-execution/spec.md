# Spec Delta

## MODIFIED Requirements

### Requirement: Error Handling
Scripts SHALL handle errors gracefully and provide meaningful exit codes. A `run_onchange_` script whose re-execution is gated on its own rendered-content hash SHALL exit non-zero if any individual operation it attempted did not complete successfully, even when it continues past that failure to attempt remaining operations — chezmoi only retries a `run_onchange_` script on the next apply when the prior run did not exit successfully, so a script that logs a warning and exits `0` after a partial failure will not be retried by advice to "run `chezmoi apply` again" unless its own content also happens to change.

#### Scenario: Non-critical error continuation
- **WHEN** a script encounters a non-critical error
- **THEN** the script SHALL log a warning and continue execution

#### Scenario: Critical error termination
- **WHEN** a script encounters a critical error (e.g., missing prerequisites)
- **THEN** the script SHALL exit with a non-zero status code
- **AND** SHALL display an error message indicating the failure

#### Scenario: Non-critical failure in a run_onchange script still yields a retryable exit
- **WHEN** a `run_onchange_` script logs a warning for one or more non-critical per-item failures (e.g. one package among several failed to install) and continues to attempt remaining items
- **THEN** the script's own final exit status SHALL be non-zero if any item failed
- **AND** any message advising the user to re-run `chezmoi apply` SHALL be truthful — that re-run SHALL actually re-attempt the script

## ADDED Requirements

### Requirement: Non-destructive resource replacement
When a script replaces an existing managed resource (e.g. a registered MCP server, a registered configuration entry) with a new or updated version, it SHALL NOT remove the existing resource until the replacement has been confirmed to succeed. If the replacement attempt fails, the script SHALL leave the prior resource in place (or explicitly restore it) rather than leaving the system in a state with neither the old nor the new resource present.

#### Scenario: Replacement succeeds
- **WHEN** a script replaces an existing managed resource and the new registration succeeds
- **THEN** the old resource SHALL be removed and the new one SHALL be present

#### Scenario: Replacement fails
- **WHEN** a script attempts to replace an existing managed resource and the new registration fails
- **THEN** the prior resource SHALL still be present (either never removed, or explicitly restored)
- **AND** the script SHALL report the failure and exit non-zero per the Error Handling requirement
