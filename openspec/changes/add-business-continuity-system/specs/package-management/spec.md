# Package Management Capability Specification Delta

## MODIFIED Requirements

### Requirement: Machine-Specific Brewfile Package Installation
The system SHALL install machine-specific packages via Homebrew Brewfiles tailored to each machine's hardware and purpose.

**Note**: Existing scenarios for machine-specific Brewfile installation remain unchanged. The following scenarios are ADDED to support UPS management software.

#### Scenario: PowerPanel installation on Mac Studio
- **WHEN** studio-brewfile is processed via brew bundle
- **AND** user confirms package installation
- **THEN** the cask "powerpanel" SHALL be installed from Homebrew
- **AND** PowerPanel app SHALL be available at /Applications/PowerPanel.app
- **AND** PowerPanel SHALL be ready for UPS configuration

#### Scenario: PowerPanel already present on Mac mini
- **WHEN** mac-mini-brewfile is processed via brew bundle
- **THEN** the cask "powerpanel" SHALL already be present at line 100
- **AND** no changes SHALL be required
- **AND** brew bundle SHALL detect PowerPanel is already installed

#### Scenario: PowerPanel alphabetical ordering in studio-brewfile
- **WHEN** studio-brewfile is read
- **THEN** "powerpanel" entry SHALL be alphabetically sorted among casks
- **AND** it SHALL be positioned after casks starting with letters A-O
- **AND** it SHALL be positioned before casks starting with letters Q-Z
- **AND** it SHALL maintain existing Brewfile formatting conventions

#### Scenario: PowerPanel configuration prerequisites
- **WHEN** PowerPanel is installed
- **AND** Mac is connected to compatible CyberPower UPS via USB
- **THEN** PowerPanel SHALL detect the UPS automatically
- **AND** PowerPanel SHALL provide configuration UI for shutdown actions
- **AND** PowerPanel SHALL allow "Run Program" as Low Battery Action
- **AND** PowerPanel SHALL accept custom script path for callback

#### Scenario: PowerPanel installation on machine without UPS
- **WHEN** PowerPanel is installed on machine not connected to UPS
- **THEN** PowerPanel SHALL install successfully
- **AND** PowerPanel SHALL launch but show "No UPS detected"
- **AND** PowerPanel SHALL be ready to use when UPS is connected
- **AND** installation SHALL NOT fail or error
