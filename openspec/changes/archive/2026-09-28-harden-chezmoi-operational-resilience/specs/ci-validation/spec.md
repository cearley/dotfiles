# Spec Delta

## Purpose

Ensures this repository's CI actually exercises the checkout under test — its `packages.yaml`, machine configuration, and current template state — rather than a generic, disconnected bootstrap run that would pass even if the checkout's own configuration were broken.

## ADDED Requirements

### Requirement: CI SHALL exercise the checkout under test
The CI workflow's bootstrap-verification job SHALL render and apply this checkout's own chezmoi source state (the `home/` tree at the commit under test), not a bootstrap run disconnected from it. Any environment variable or argument the workflow sets to communicate the checkout's location to the install script SHALL actually be consumed by that script.

#### Scenario: CI targets the checked-out source tree
- **WHEN** the CI bootstrap-verification job runs
- **THEN** the chezmoi source directory used for the apply SHALL be the workflow's own checkout, not a freshly-cloned or otherwise disconnected copy

#### Scenario: Unused workflow inputs are a defect
- **WHEN** the CI workflow sets an environment variable or argument intended to influence the install script's behavior
- **THEN** the invoked script SHALL read and act on that value, or the workflow SHALL NOT set it
