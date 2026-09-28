# Spec Delta

## ADDED Requirements

### Requirement: Private package-index configuration SHALL NOT enable dependency confusion
When a package-manager configuration (e.g. `pip.conf`'s `extra-index-url`) adds a private, credential-bearing package index alongside a public default index, the configuration SHALL prevent a public package from being silently resolved in place of a same-named private package. This MAY be satisfied by scoping the private index to a specific package-name prefix, by using an index-priority/pinning mechanism the package manager supports, or by another mechanism that achieves the same guarantee.

#### Scenario: Private and public package names cannot collide
- **WHEN** a private package index is configured alongside the public default index
- **AND** a public package exists with the same name as a private package
- **THEN** the package manager SHALL NOT silently resolve the public package when the private one is requested
