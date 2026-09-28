# Spec Delta

## ADDED Requirements

### Requirement: SOPS+age decryption ordering for tunnel secret files
Rendering `cert.pem` and a tunnel's credentials JSON from their SOPS+age-encrypted source files SHALL NOT require the age private key to already be present on disk as an unstated precondition of the same `chezmoi apply` run. When the age private key is not yet present, these targets SHALL be skipped for that apply run rather than causing the run to fail or produce incorrect content, and applying again after the age key has been installed SHALL produce the correct decrypted content.

#### Scenario: Age key not yet installed
- **WHEN** `chezmoi apply` runs on a machine with `cloudflare_tunnels` configured but no age private key yet materialized on disk
- **THEN** `cert.pem` and the tunnel credentials JSON SHALL NOT be written for that run
- **AND** the run SHALL still install the age private key and apply every other unrelated file and script normally

#### Scenario: Age key present
- **WHEN** `chezmoi apply` runs and the age private key is present on disk
- **THEN** `cert.pem` and the tunnel credentials JSON SHALL be decrypted and written as before
