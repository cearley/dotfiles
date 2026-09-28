# External Dependency Pinning Specification

## Purpose

Ensures that chezmoi externals whose content executes or is sourced by a shell (as opposed to purely cosmetic/display assets) are pinned to a specific, deliberately-reviewed ref, so an upstream compromise or breaking change cannot silently reach this machine on the next `chezmoi apply`.

## Requirements

### Requirement: Executable externals SHALL be pinned to a reviewed ref
A `.chezmoiexternal.toml.tmpl` entry whose fetched content is executed, sourced by a shell, or otherwise runs as code on the target machine SHALL declare a specific ref (a commit SHA, or a tag/release the maintainer controls) rather than tracking a mutable branch name (e.g. `main`, `master`) by URL. An entry whose fetched content is purely cosmetic or declarative with no executable effect (e.g. a theme's static assets) is exempt from this requirement.

#### Scenario: Executable external declares a pinned ref
- **WHEN** a `.chezmoiexternal.toml.tmpl` entry fetches content that is sourced or executed (a shell plugin, a hook script, a mod definition file)
- **THEN** its `url` SHALL resolve to a specific commit or tag, not a branch HEAD

#### Scenario: Updating a pinned external is a deliberate action
- **WHEN** a maintainer wants to pick up upstream changes to a pinned executable external
- **THEN** doing so SHALL require an explicit edit to the pinned ref in `.chezmoiexternal.toml.tmpl`, not merely running `chezmoi apply`

#### Scenario: Cosmetic externals remain unpinned
- **WHEN** a `.chezmoiexternal.toml.tmpl` entry fetches content with no executable effect
- **THEN** this requirement does not apply, and tracking a mutable branch remains acceptable
