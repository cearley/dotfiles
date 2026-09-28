# Spec Delta

## MODIFIED Requirements

### Requirement: Pattern C requires evidence of container isolation
Before writing Pattern C's `permissions` block, the stamping mechanism SHALL check for evidence that the current process is running inside an isolated container (e.g. a container marker file, or an explicit override flag the caller supplies deliberately) AND that the target `.claude/` directory itself is isolated from the host filesystem (e.g. backed by a distinct mount, not merely a subdirectory of a host bind mount). When either check fails, the mechanism SHALL refuse to write the Pattern C block and SHALL print a warning explaining the specific gap — that `bypassPermissions` on a bare host is unsafe, or that a `.claude/` directory shared with the host via bind mount would let the stamped posture outlive the container — referencing the companion container template's isolated-mount configuration as the fix.

#### Scenario: Pattern C refused on a bare host
- **WHEN** the stamping mechanism is invoked with pattern `c` and no container-isolation evidence is present
- **THEN** it SHALL NOT write `.claude/settings.local.json` and SHALL exit with a non-zero status and an explanatory warning

#### Scenario: Pattern C refused when `.claude/` is not isolated from the host
- **WHEN** the stamping mechanism is invoked with pattern `c` inside a detected container, but the current `.claude/` directory is part of the same host bind mount as the rest of the working tree rather than its own isolated mount
- **THEN** it SHALL NOT write `.claude/settings.local.json` and SHALL exit with a non-zero status and a warning identifying that `.claude/` is not isolated

#### Scenario: Pattern C allowed inside a detected container
- **WHEN** the stamping mechanism is invoked with pattern `c`, container-isolation evidence is present, and `.claude/` is backed by a mount distinct from the host bind mount
- **THEN** it SHALL write Pattern C's `permissions` block as normal

### Requirement: Pattern C container template
Chezmoi SHALL provide a reusable container/devcontainer definition template for Pattern C, configured to run as a non-root user, bind-mount only the target repository's working tree, mount no host credential stores (e.g. `$HOME`, SSH keys, cloud credential directories) by default, and back the container's `.claude/` directory with a volume distinct from the working-tree bind mount so that files written under `.claude/` inside the container (including a Pattern C stamp) do not persist on the host checkout after the container's lifecycle ends.

#### Scenario: Container template excludes host credentials
- **WHEN** the Pattern C container template is rendered
- **THEN** its mount/volume configuration includes only the target repository's working tree and excludes `$HOME` and any credential-bearing path

#### Scenario: Container template isolates `.claude/` from the host checkout
- **WHEN** the Pattern C container template is rendered
- **THEN** its mount/volume configuration mounts `.claude/` inside the container from a volume distinct from the working-tree bind mount
- **AND** a file written under `.claude/` inside a running container built from this template SHALL NOT appear under `.claude/` in the host checkout
