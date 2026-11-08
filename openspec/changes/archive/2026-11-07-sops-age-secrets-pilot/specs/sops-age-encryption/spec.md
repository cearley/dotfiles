## ADDED Requirements

### Requirement: Age Key Generation and Custody
The system SHALL generate an age keypair for repo-scoped secret encryption, storing the private key exclusively in KeePassXC and never in the chezmoi source tree or any git-tracked/synced path.

#### Scenario: Private key storage
- **WHEN** the age keypair is generated
- **THEN** the private key SHALL be stored as a KeePassXC entry
- **AND** SHALL NOT be written to any file tracked by git

#### Scenario: Private key materialization at bootstrap
- **WHEN** a machine bootstraps and SOPS-encrypted templates need to render
- **THEN** a bootstrap script SHALL retrieve the private key from KeePassXC via `keepassxcAttribute`
- **AND** SHALL write it to sops's default age key-file path for the platform, with restrictive permissions (0600), so sops auto-detects it without requiring `SOPS_AGE_KEY_FILE` to be set

### Requirement: SOPS Decryption via Template Partial
The system SHALL decrypt SOPS+age-encrypted source files at chezmoi template-execution time via a reusable `.chezmoitemplates` partial, rather than chezmoi's native `age` encryption support.

#### Scenario: Decrypting a whole-file secret
- **WHEN** a template needs the plaintext contents of a SOPS+age-encrypted source file
- **THEN** it SHALL invoke the shared decrypt partial via the `output` template function
- **AND** SHALL inject the decrypted contents into the rendered target file

#### Scenario: SOPS or age key unavailable
- **WHEN** the `sops` binary or the age private key is unavailable during template execution
- **THEN** template execution SHALL fail with an error identifying the missing dependency
- **OR** the containing script SHALL gracefully skip the secret-dependent operation, consistent with existing KeePassXC graceful-degradation behavior

### Requirement: Scoped `.sops.yaml` Creation Rules
The repository SHALL define `.sops.yaml` creation rules that grant decrypt access only to the specific files intended to use SOPS+age encryption, not a blanket path glob.

#### Scenario: New capability opts in
- **WHEN** a new capability wants to use SOPS+age-encrypted secrets
- **THEN** its files SHALL be added to `.sops.yaml` via an explicit, narrowly-scoped creation rule
- **AND** SHALL NOT be covered implicitly by an existing broad rule

### Requirement: Encrypted Source File Convention
SOPS+age-encrypted secrets SHALL be committed as plain source files using a `.sops` suffix appended to the original filename, distinct from chezmoi's native `encrypted_` attribute.

#### Scenario: Ciphertext file naming
- **WHEN** a secret is encrypted with SOPS+age for repo storage
- **THEN** its source file SHALL be named `<original-filename>.sops` (e.g. `cert.pem.sops`)
- **AND** SHALL NOT use the chezmoi `encrypted_` source-name prefix

### Requirement: Testability Without the Real Age Key
SOPS-encrypted templates SHALL remain renderable in the test harness without access to the real age private key.

#### Scenario: Mocked SOPS decryption
- **WHEN** `tests/run-template` renders a template that calls the SOPS decrypt partial
- **THEN** a mock `sops` command SHALL return deterministic fixture plaintext
- **AND** SHALL NOT require the real age private key or KeePassXC
