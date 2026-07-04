# Cloudflare Tunnel Management

## Purpose
Chezmoi-managed setup, restoration, and teardown of Cloudflare Tunnels as root-level macOS LaunchDaemons, driven by per-machine config data and KeePassXC-backed secret files.

## Requirements

### Requirement: Machine-Scoped Tunnel Declaration
The system SHALL declare Cloudflare Tunnels per-machine as a `cloudflare_tunnels` list in `home/.chezmoidata/config.yaml`, following the existing per-machine list convention (e.g. `syncthing_folders`).

#### Scenario: Tunnel entry fields
- **WHEN** a machine declares an entry in `cloudflare_tunnels`
- **THEN** the entry SHALL include `name`, `id`, `hostname`, `service`, and `keepassxc_entry` fields

#### Scenario: No tunnels declared for a machine
- **WHEN** a machine's `config.yaml` entry has no `cloudflare_tunnels` key (or an empty list)
- **THEN** the setup script SHALL skip all tunnel setup for that machine
- **AND** SHALL exit successfully without error

### Requirement: Secret Restoration Before System Config
The system SHALL restore each tunnel's `cert.pem` and credentials JSON file to `~/.cloudflared/` (via chezmoi `private_` template files reading a KeePassXC attachment) before the setup script writes any system-level configuration.

#### Scenario: Secrets present
- **WHEN** `~/.cloudflared/cert.pem` and `~/.cloudflared/<tunnel-id>.json` both exist after chezmoi applies template files
- **THEN** the setup script SHALL proceed to write system configuration for that tunnel

#### Scenario: Secrets missing
- **WHEN** either `~/.cloudflared/cert.pem` or `~/.cloudflared/<tunnel-id>.json` is missing for a declared tunnel
- **THEN** the setup script SHALL print a message identifying the required KeePassXC entry name
- **AND** SHALL skip system configuration for that tunnel only
- **AND** SHALL continue processing any other declared tunnels
- **AND** SHALL NOT fail the overall `chezmoi apply`

### Requirement: Idempotent System Configuration
The system SHALL write `/usr/local/etc/cloudflared/config.yml` and `/Library/LaunchDaemons/com.cloudflare.cloudflared.plist` only when their rendered content differs from what is already on disk.

#### Scenario: No configuration change
- **WHEN** the rendered `config.yml` and plist content match the files already on disk
- **THEN** the setup script SHALL NOT invoke `sudo` to rewrite either file
- **AND** SHALL NOT reload the LaunchDaemon

#### Scenario: Configuration change detected
- **WHEN** the rendered `config.yml` or plist content differs from what is on disk (or either file does not yet exist)
- **THEN** the setup script SHALL write the changed file(s) via `sudo`
- **AND** SHALL reload the LaunchDaemon (`launchctl bootout` then `bootstrap`) to pick up the change

### Requirement: LaunchDaemon Lifecycle Management
The system SHALL manage the Cloudflare Tunnel as a `system`-domain macOS LaunchDaemon that runs at boot independent of any user session.

#### Scenario: Daemon installed
- **WHEN** the setup script writes a new or changed LaunchDaemon plist
- **THEN** the daemon SHALL be loaded via `launchctl bootstrap system <plist-path>`
- **AND** SHALL be configured to run at load (`RunAtLoad`) and restart on unexpected exit (`KeepAlive`)

#### Scenario: Reinstalling on a rebuilt machine
- **WHEN** `chezmoi apply` runs on this machine after the Homebrew package, secrets, and system files are all absent
- **THEN** the setup script SHALL install the package (via the existing package-management scripts), restore secrets, write system configuration, and load the LaunchDaemon
- **AND** the tunnel SHALL become reachable at its configured hostname without further manual steps beyond the one-time KeePassXC entry population
