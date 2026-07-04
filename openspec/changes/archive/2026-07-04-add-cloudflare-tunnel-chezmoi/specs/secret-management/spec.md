## MODIFIED Requirements

### Requirement: KeePassXC Integration
The system SHALL integrate with KeePassXC for secret storage and retrieval via chezmoi template functions.

#### Scenario: Secret retrieval during template execution
- **WHEN** a template uses `keepassxcAttribute "entry-name" "attribute-name"`
- **THEN** chezmoi SHALL query KeePassXC for the specified attribute
- **AND** SHALL inject the secret value into the template

#### Scenario: Attachment retrieval during template execution
- **WHEN** a template uses `keepassxcAttachment "entry-name" "attachment-name"`
- **THEN** chezmoi SHALL query KeePassXC for the specified file attachment on that entry
- **AND** SHALL inject the attachment's raw file contents into the template output
- **AND** the containing template file SHALL use the `private_` prefix so the resulting file receives restrictive permissions

#### Scenario: KeePassXC unavailable
- **WHEN** KeePassXC is not running or accessible during template execution
- **THEN** templates SHOULD fail with an error indicating KeePassXC is required
- **OR** scripts MAY gracefully skip secret-dependent operations
