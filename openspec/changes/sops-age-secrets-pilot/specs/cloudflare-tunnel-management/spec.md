## MODIFIED Requirements

### Requirement: Secret Restoration Before System Config
The system SHALL restore each tunnel's `cert.pem` and credentials JSON file to `~/.cloudflared/` (via chezmoi `private_` template files that decrypt a SOPS+age-encrypted source file committed in the repository) before the setup script writes any system-level configuration.

#### Scenario: Secrets present
- **WHEN** `~/.cloudflared/cert.pem` and `~/.cloudflared/<tunnel-id>.json` both exist after chezmoi applies template files
- **THEN** the setup script SHALL proceed to write system configuration for that tunnel

#### Scenario: Secrets missing
- **WHEN** either `~/.cloudflared/cert.pem` or `~/.cloudflared/<tunnel-id>.json` is missing for a declared tunnel
- **THEN** the setup script SHALL print a message identifying that the age private key (sourced from KeePassXC) is required to decrypt the tunnel's SOPS-encrypted secret files
- **AND** SHALL skip system configuration for that tunnel only
- **AND** SHALL continue processing any other declared tunnels
- **AND** SHALL NOT fail the overall `chezmoi apply`
