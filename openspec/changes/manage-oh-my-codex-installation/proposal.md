# Proposal

## Why

Chezmoi already provisions the OMC CLI and Claude Code plugin, but OMX installation is not declared, making the equivalent Codex workflow a machine-local setup. Declare the OMX executable through the existing package layer and document native plugin activation without letting an unattended dotfiles apply rewrite Codex guidance or configuration.

## What Changes

- Add the official `oh-my-codex` package, providing `omx`, to `packages.darwin.ai.bun` in `home/.chezmoidata/packages.yaml`.
- Keep the existing Homebrew `codex` cask as the owner of Codex itself; reuse the position-26 Bun installer and its existing tag selection and refresh behavior.
- Add an OMX setup guide covering explicit user-scoped native plugin setup, `CODEX_HOME`, generated-file ownership, a deliberate setup working directory, and verification.
- Document Bun/chezmoi as the package update owner and disable OMX's separate launch-time updater in the documented launch environment with `OMX_AUTO_UPDATE=0`.
- Verify package installation through Bun and native plugin setup in a disposable environment before treating this path as supported.

## Capabilities

### New Capabilities

- `codex-omx-provisioning`: Declarative OMX CLI provisioning for macOS AI machines, with an explicit handoff to user-owned native plugin/runtime setup and a documented update boundary.

### Modified Capabilities

None. This consumes existing `package-management` requirements for Bun package definitions, tag selection, and installation ordering without changing their contract.

## Impact

- Implementation files: `home/.chezmoidata/packages.yaml` and a new `docs/oh-my-codex.md` guide. Existing Bun installer and package-layer partial should need no behavior changes.
- Affected machines: macOS machines selecting `ai`, with or without `dev`; other tags gain no OMX dependency.
- Dependencies: existing Bun and Node.js provision, existing Homebrew-managed Codex, and the official upstream `oh-my-codex` package. Team workflows additionally need upstream runtime prerequisites such as tmux.
- Architecture follows `CLAUDE.md`, `openspec/specs/package-management/spec.md`, and the OMC ownership boundary described in `openspec/specs/claude-environments/spec.md`.
- Security: no new credentials, secret material, permission bypasses, SIP changes, or authentication automation. Explicit setup may change Codex configuration, hooks, native agents, plugin registrations, and guidance; the guide must make those destinations reviewable before activation.

## Non-goals

- Running OMX setup, installing packages, or changing live profiles while authoring this proposal.
- Running `omx setup` automatically during `chezmoi apply`, or enabling OMX for every repository.
- Building a generic Codex marketplace installer, activating the commented `agents.codex` namespace, or copying Claude marketplace identifiers into Codex.
- Taking ownership of Codex `config.toml`, hooks, plugin caches, generated agent files, `AGENTS.md`, credentials, or `.omx/` state.
- Introducing Codex persona management, changing OMC provisioning, replacing the existing hcom shell wrapper, or guaranteeing Codex App support.
