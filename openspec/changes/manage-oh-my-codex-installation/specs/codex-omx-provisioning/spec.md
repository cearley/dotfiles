# Spec Delta

## Purpose

Provide a repeatable OMX CLI installation on macOS AI machines while keeping Codex plugin activation and runtime configuration under explicit user control.

## ADDED Requirements

### Requirement: OMX is available on AI machines

Chezmoi SHALL declare the official `oh-my-codex` package through the existing AI package layer so successful provisioning makes `omx` available on macOS machines selecting `ai`, independently of the `dev` tag.

#### Scenario: AI machine without development tag
- **WHEN** provisioning completes successfully on macOS with `ai` selected and `dev` absent
- **THEN** the declared OMX package SHALL provide a runnable `omx` command

#### Scenario: AI tag is absent
- **WHEN** packages are selected for a macOS machine without `ai`
- **THEN** the package selection SHALL NOT include `oh-my-codex`

#### Scenario: Repeated provisioning
- **WHEN** the existing package installer runs again with OMX already installed
- **THEN** it SHALL retain one declared package-manager owner for OMX and follow the existing package refresh behavior without invoking OMX setup

### Requirement: Codex retains its package owner

The OMX addition SHALL preserve the existing Homebrew `codex` declaration and SHALL NOT introduce a second Codex installation through the JavaScript package layer.

#### Scenario: Homebrew-managed Codex is already present
- **WHEN** the OMX addition is provisioned
- **THEN** it SHALL NOT add an `@openai/codex` installation command or replace the existing Codex package declaration

### Requirement: Plugin activation is an explicit setup step

The repository SHALL document an explicit user-scoped native plugin setup path using the installed OMX CLI. Chezmoi provisioning SHALL NOT invoke OMX setup or activate project-scoped OMX guidance automatically.

#### Scenario: Package installation alone
- **WHEN** chezmoi provisions the OMX package
- **THEN** no repo-authored provisioning step SHALL run OMX setup or modify a project's `AGENTS.md`
- **AND** the guide SHALL distinguish CLI availability from native plugin and runtime readiness

#### Scenario: User follows the activation guide
- **WHEN** a user prepares to activate OMX
- **THEN** the guide SHALL identify the effective `CODEX_HOME`, a deliberate setup working directory, user scope, and native plugin mode
- **AND** it SHALL explain that user-scoped setup can still create working-directory `.omx/` files

### Requirement: OMX runtime files remain tool-owned

Chezmoi SHALL NOT manage OMX-generated Codex guidance, runtime configuration, hook registrations, native agents, plugin caches, credentials, or `.omx/` state as deployed source files. The setup guide SHALL explain these ownership boundaries and how to preserve existing guidance before activation.

#### Scenario: Existing Codex guidance is present
- **WHEN** a user follows the guide with an existing Codex `AGENTS.md` or configuration
- **THEN** the guide SHALL require reviewing the intended changes and preserving existing content
- **AND** it SHALL NOT prescribe unattended force-overwrite setup

#### Scenario: Runtime state changes after setup
- **WHEN** OMX updates its generated runtime files and a later chezmoi apply runs
- **THEN** this integration SHALL NOT overwrite those files from chezmoi source templates or snapshots

### Requirement: Update and verification responsibilities are documented

The guide SHALL identify Bun through chezmoi as the OMX package update owner, disable launch-time OMX package updates in its documented launch environment, and distinguish package updates from explicit setup refreshes. It SHALL separate installation checks from authenticated runtime verification.

#### Scenario: Managed launch instructions
- **WHEN** a user follows the documented OMX launch path
- **THEN** the environment SHALL set `OMX_AUTO_UPDATE=0`
- **AND** the guide SHALL direct package updates through the existing Bun/chezmoi path rather than `omx update` or a duplicate npm installation

#### Scenario: Package version changes
- **WHEN** a user updates the managed OMX package
- **THEN** the guide SHALL describe explicitly reviewing and rerunning scoped plugin setup as needed
- **AND** it SHALL NOT imply that installing a newer executable refreshes every runtime artifact

#### Scenario: Readiness verification
- **WHEN** a user validates an activated installation
- **THEN** the guide SHALL include executable resolution/version checks and `omx doctor`
- **AND** it SHALL label authenticated execution as a separate user-run check that can make a model request
